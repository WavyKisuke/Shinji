from pathlib import Path

path = Path("Shinji/Services/AddonStore.swift")
text = path.read_text(encoding="utf-8")

start = text.index("    func loadStreams(for item: AddonCatalogItem) async {")
end = text.index("    func remove(_ addon: AddonManifest)", start)

replacement = r'''    func loadStreams(for item: AddonCatalogItem) async {
        streamOptions = []
        isLoadingStreams = true
        streamStatus = "Searching installed add-ons for streams…"
        defer { isLoadingStreams = false }

        let candidates = addons.filter { $0.format == "Stremio" && $0.manifestURL != nil }
        guard !candidates.isEmpty else {
            streamStatus = "No Stremio add-ons are installed. Install a stream add-on first."
            return
        }

        var found: [AddonStreamOption] = []
        var checkedAddons: [String] = []
        var returnedStreamCount = 0

        for addon in candidates {
            guard let manifestURL = addon.manifestURL else { continue }
            checkedAddons.append(addon.name)

            for url in streamURLs(base: manifestURL, item: item) {
                do {
                    let data = try await fetchJSON(from: url)
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    guard let streams = json["streams"] as? [[String: Any]] else { continue }
                    returnedStreamCount += streams.count

                    for stream in streams {
                        guard let rawURL = stream["url"] as? String,
                              let parsedURL = URL(string: rawURL),
                              let scheme = parsedURL.scheme?.lowercased(),
                              ["https", "http"].contains(scheme),
                              parsedURL.host != nil else { continue }

                        let streamTitle = (stream["title"] as? String)
                            ?? (stream["name"] as? String)
                            ?? "Stream"
                        let behaviorHints = stream["behaviorHints"] as? [String: Any]
                        let proxyHeaders = behaviorHints?["proxyHeaders"] as? [String: Any]
                        let requestInfo = proxyHeaders?["request"] as? [String: Any]
                        let suppliedHeaders = stringDictionary(requestInfo?["headers"])
                            ?? stringDictionary(stream["headers"])
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

                    break
                } catch {
                    // Try the next compatible endpoint shape.
                }
            }
        }

        streamOptions = found
        if !found.isEmpty {
            streamStatus = "Found \(found.count) playable stream(s) from installed add-ons."
        } else if returnedStreamCount > 0 {
            streamStatus = "Add-ons returned \(returnedStreamCount) stream entries, but none contained a directly playable URL."
        } else {
            let names = checkedAddons.joined(separator: ", ")
            streamStatus = names.isEmpty
                ? "No compatible Stremio stream add-ons were found."
                : "No streams were returned by: \(names)."
        }
    }

    private func streamURLs(base: URL, item: AddonCatalogItem) -> [URL] {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return [] }
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        let type = item.type.addingPercentEncoding(withAllowedCharacters: allowed) ?? item.type
        let id = item.id.addingPercentEncoding(withAllowedCharacters: allowed) ?? item.id
        let prefix = addonPathPrefix(components.path)

        var urls: [URL] = []
        for suffix in [".json", ""] {
            components.path = prefix + "stream/\(type)/\(id)\(suffix)"
            if let url = components.url, !urls.contains(url) {
                urls.append(url)
            }
        }
        return urls
    }

    private func stringDictionary(_ value: Any?) -> [String: String]? {
        guard let dictionary = value as? [String: Any] else { return nil }
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            if let string = value as? String {
                result[key] = string
            } else if let number = value as? NSNumber {
                result[key] = number.stringValue
            }
        }
        return result.isEmpty ? nil : result
    }

'''

text = text[:start] + replacement + text[end:]
path.write_text(text, encoding="utf-8")
print("Patched AddonStore stream source loading")
