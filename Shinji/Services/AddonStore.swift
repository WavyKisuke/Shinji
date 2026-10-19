import Foundation
import Combine

@MainActor
final class AddonStore: ObservableObject {
    private let storageKey = "shinji.installedAddons.v1"

    @Published private(set) var addons: [AddonManifest] = [] {
        didSet {
            saveAddons()
        }
    }
    @Published var statusMessage: String?

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            let savedAddons = try JSONDecoder().decode([AddonManifest].self, from: data)
            addons = savedAddons
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
            guard data.count <= 1_000_000 else {
                throw AddonError.invalidManifest("Manifest exceeds the 1 MB limit.")
            }

            let manifest: AddonManifest
            do {
                manifest = try JSONDecoder().decode(AddonManifest.self, from: data)
            } catch let decodingError as DecodingError {
                throw AddonError.invalidManifest(Self.explain(decodingError))
            }

            try manifest.validate()
            guard !addons.contains(where: { $0.id == manifest.id }) else {
                throw AddonError.duplicate(manifest.name)
            }
            addons.append(manifest)
            statusMessage = "Installed \(manifest.name)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func remove(_ addon: AddonManifest) {
        addons.removeAll { $0.id == addon.id }
    }

    private static func explain(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "This JSON is missing the required field '\(key.stringValue)'. This URL may be for a different add-on format. Shinji currently expects its own manifest format."
        case .typeMismatch(let type, let context):
            return "The field '\(context.codingPath.last?.stringValue ?? "unknown")' has the wrong type (expected \(type)). Check that this is a Shinji-compatible JSON manifest."
        case .valueNotFound(_, let context):
            return "The value for '\(context.codingPath.last?.stringValue ?? "unknown")' is missing. Check that this is a Shinji-compatible JSON manifest."
        case .dataCorrupted:
            return "The server response is not valid JSON. Make sure the URL points directly to a JSON manifest."
        @unknown default:
            return "The JSON format is not supported. Make sure the URL points to a Shinji-compatible manifest."
        }
    }

    private func saveAddons() {
        do {
            let data = try JSONEncoder().encode(addons)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            statusMessage = "Could not save the installed add-ons."
        }
    }
}
