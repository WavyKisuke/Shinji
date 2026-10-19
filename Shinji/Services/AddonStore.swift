import Foundation
import Combine

@MainActor
final class AddonStore: ObservableObject {
    @Published private(set) var addons: [AddonManifest] = []
    @Published var statusMessage: String?

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
            let manifest = try JSONDecoder().decode(AddonManifest.self, from: data)
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
}
