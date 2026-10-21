import Foundation
import Combine

struct AddonStreamOption: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
    let headers: [String: String]
}

struct AddonCatalogItem: Identifiable, Hashable {
    let id: String
    let type: String
    let name: String
    let posterURL: URL?
    let description: String?
    let year: String?
    let addonName: String
}

private struct StremioCatalogDescriptor {
    let type: String
    let id: String
    let name: String
}

@MainActor
final class AddonStore: ObservableObject {
    private let storageKey = "shinji.installedAddons.v1"

    @Published private(set) var addons: [AddonManifest] = [] {
        didSet { saveAddons() }
    }
    @Published private(set) var catalogItems: [AddonCatalogItem] = []
    @Published private(set) var streamOptions: [AddonStreamOption] = []
    @Published var streamStatus: String?
    @Published private(set) var isLoadingStreams = false
    @Published var statusMessage: String?
    @Published var catalogStatus: String?

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            addons = try JSONDecoder().decode([AddonManifest].self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    func install(from rawURL: String) async {
        guard let url = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            statusMessage = AddonError.invalidURL.localizedDescription
            return
        }

        do {
            let data = try await fetchJSON(from: url)
            let manifest = try AddonManifest.parse(data: data, sourceURL: url)
            try manifest.validate()
            guard !addons.contains(where: { $0.id == manifest.id }) else {
                throw AddonError.duplicate(manifest.name)
            }
            addons.append(manifest)
            statusMessage = "Installed \(manifest.name) (\(manifest.format) manifest)."
            await refreshCatalogs()
        } catch {
            statusMessage = safeMessage(error)
        }
    }

    func refreshCatalogs() async {
        guard !addons.isEmpty else {
            catalogItems = []
            catalogStatus = nil
            return
        }

        var loaded: [AddonCatalogItem] = []
        var compatibleCatalogCount = 0
        for addon in addons {
            guard addon.format == "Stremio", let manifestURL = addon.manifestURL else { continue }
            do {
                let manifestData = try await fetchJSON(from: manifestURL)
                let descriptors = parseCatalogs(from: manifestData)
                compatibleCatalogCount += descriptors.count
                for descriptor in descriptors.prefix(30) {
                    guard let url = catalogURL(base: manifestURL, descriptor: descriptor) else { continue }
                    do {
                        let data = try await fetchJSON(from: url)
                        loaded.append(contentsOf: parseMetas(from: data, type: descriptor.type, addonName: addon.name))
                    } catch {
                        // One unavailable catalog should not block the other catalogs.
                    }
                }
            } catch {
                // Keep other installed add-ons usable if one source is offline.
            }
        }

        var seen = Set<String>()
        catalogItems = loaded.filter { seen.insert("\($0.type)|\($0.id)").inserted }
        if !catalogItems.isEmpty {
            catalogStatus = "Loaded \(catalogItems.count) titles from installed Stremio add-ons."
        } else if compatibleCatalogCount == 0 {
            catalogStatus = "Installed add-ons have no readable Stremio catalogs. This source may use a different manifest format."
        } else {
            catalogStatus = "Catalogs were found, but no titles could be loaded. The source may require authentication or use an unsupported response."
        }
    }

    func searchCatalogs(query: String, typeFilter: String = "All") async -> [AddonCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var loaded: [AddonCatalogItem] = []
        for addon in addons {
            guard addon.format == "Stremio", let manifestURL = addon.manifestURL else { continue }
            do {
                let manifestData = try await fetchJSON(from: manifestURL)
                for descriptor in parseCatalogs(from: manifestData) {
                    if typeFilter == "Movies" && descriptor.type.lowercased() != "movie" { continue }
                    if typeFilter == "Shows" && descriptor.type.lowercased() != "series" { continue }
                    guard let url = catalogURL(base: manifestURL, descriptor: descriptor, search: trimmed) else { continue }
                    do {
                        let data = try await fetchJSON(from: url)
                        loaded.append(contentsOf: parseMetas(from: data, type: descriptor.type, addonName: addon.name))
                    } catch {
                        // Keep searching other catalogs if one source does not support search.
                    }
                }
            } catch {
                // Keep other installed add-ons usable.
            }
        }

        var seen = Set<String>()
        return loaded.filter { seen.insert("\($0.type)|\($0.id)").inserted }
    }

    func loadStreams(for item: AddonCatalogItem) async {
        streamOptions = []
        isLoadingStreams = true
        streamStatus = "Searching installed add-ons for streams…"
        defer { isLoadingStreams = false }

        let candidates = addons.filter { $0.format == "Stremio" && $0.manifestURL != nil }
        guard !candidates.isEmpty else {
            streamStatus = "Install a Stremio add-on that provides stream sources to play this title."
            return
        }

        var found: [AddonStreamOption] = []
        var attempted = 0
        for addon in candidates {
            guard let manifestURL = addon.manifestURL,
                  let url = streamURL(base: manifestURL, item: item) else { continue }
            attempted += 1
            do {
                let data = try await fetchJSON(from: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let streams = json["streams"] as? [[String: Any]] else { continue }

                for stream in streams {
                    guard let rawURL = stream["url"] as? String,
                          let parsedURL = URL(string: rawURL),
                          ["https", "http"].contains(parsedURL.scheme?.lowercased() ?? ""),
                          parsedURL.host != nil else { continue }
                    let streamTitle = (stream["title"] as? String)
                        ?? (stream["name"] as? String)
                        ?? addon.name
                    let behaviorHints = stream["behaviorHints"] as? [String: Any]
                    let proxyHeaders = behaviorHints?["proxyHeaders"] as? [String: Any]
                    let requestInfo = proxyHeaders?["request"] as? [String: Any]
                    let suppliedHeaders = (requestInfo?["headers"] as? [String: String])
                        ?? (stream["headers"] as? [String: String])
                        ?? [:]
                    let optionID = "\(addon.id)|\(rawURL)"
                    if !found.contains(where: { $0.id == optionID }) {
                        found.append(AddonStreamOption(
                            id: optionID,
                            title: "\(streamTitle) · \(addon.name)",
                            url: parsedURL,
                            headers: suppliedHeaders
                        ))
                    }
                }
            } catch {
                // One add-on may be offline, private, or catalog-only. Keep trying others.
            }
        }

        streamOptions = found
        if !found.isEmpty {
            streamStatus = "Found \(found.count) playable stream(s) from installed add-ons."
        } else if attempted == 0 {
            streamStatus = "No installed add-ons expose a compatible stream endpoint."
        } else {
            streamStatus = "No direct playable streams were returned. The installed sources may be catalog-only, require authentication, or provide unsupported stream types."
        }
    }

    private func streamURL(base: URL, item: AddonCatalogItem) -> URL? {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        let type = item.type.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.type
        let id = item.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.id
        let prefix = addonPathPrefix(components.path)
        components.path = prefix + "stream/\(type)/\(id).json"
        return components.url
    }

    func remove(_ addon: AddonManifest) {
        addons.removeAll { $0.id == addon.id }
        catalogItems.removeAll { $0.addonName == addon.name }
    }

    private func fetchJSON(from url: URL) async throws -> Data {
        guard url.scheme?.lowercased() == "https", url.host != nil else {
            throw AddonError.invalidManifest("Add-on endpoints must use HTTPS.")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AddonError.invalidManifest("The server response was not HTTP.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AddonError.httpStatus(http.statusCode)
        }
        guard data.count <= 2_000_000 else {
            throw AddonError.invalidManifest("The response exceeds the 2 MB limit.")
        }
        return data
    }

    private func parseCatalogs(from data: Data) -> [StremioCatalogDescriptor] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let catalogs = json["catalogs"] as? [[String: Any]] else { return [] }
        return catalogs.compactMap { catalog in
            guard let type = catalog["type"] as? String,
                  let id = catalog["id"] as? String, !id.isEmpty else { return nil }
            let name = catalog["name"] as? String ?? id
            return StremioCatalogDescriptor(type: type, id: id, name: name)
        }
    }

    private func catalogURL(base: URL, descriptor: StremioCatalogDescriptor, search: String? = nil) -> URL? {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        let safeType = descriptor.type.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? descriptor.type
        let safeID = descriptor.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? descriptor.id
        let prefix = addonPathPrefix(components.path)
        var path = prefix + "catalog/\(safeType)/\(safeID)"
        if let search, !search.isEmpty {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
            let safeSearch = search.addingPercentEncoding(withAllowedCharacters: allowed) ?? search
            path += "/search=\(safeSearch)"
        }
        components.path = path + ".json"
        return components.url
    }

    private func addonPathPrefix(_ path: String) -> String {
        if let range = path.range(of: "/manifest.json", options: .caseInsensitive), range.upperBound == path.endIndex {
            return String(path[..<range.lowerBound]) + "/"
        }
        return "/"
    }

    private func parseMetas(from data: Data, type: String, addonName: String) -> [AddonCatalogItem] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let metas = json["metas"] as? [[String: Any]] else { return [] }
        return metas.compactMap { meta in
            guard let id = meta["id"] as? String,
                  let name = meta["name"] as? String else { return nil }
            let itemType = (meta["type"] as? String) ?? type
            let poster = (meta["poster"] as? String).flatMap(URL.init(string:))
            let year: String? = {
                if let value = meta["releaseInfo"] as? String, !value.isEmpty { return String(value.prefix(4)) }
                if let value = meta["year"] as? Int { return String(value) }
                if let value = meta["year"] as? String, !value.isEmpty { return String(value.prefix(4)) }
                return nil
            }()
            return AddonCatalogItem(
                id: id,
                type: itemType,
                name: name,
                posterURL: poster,
                description: meta["description"] as? String,
                year: year,
                addonName: addonName
            )
        }
    }

    private func saveAddons() {
        guard let data = try? JSONEncoder().encode(addons) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func safeMessage(_ error: Error) -> String {
        if let addonError = error as? AddonError { return addonError.localizedDescription }
        return "The add-on request failed. Please check the manifest URL and try again."
    }
}
