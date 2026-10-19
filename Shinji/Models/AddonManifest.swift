import Foundation

struct AddonManifest: Codable, Identifiable, Hashable {
    let schemaVersion: Int
    let id: String
    let name: String
    let version: String
    let publisher: String
    let capabilities: [String]
    let endpoints: [String: URL]

    func validate() throws {
        guard schemaVersion == 1 else {
            throw AddonError.unsupportedSchema(schemaVersion)
        }
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !version.isEmpty,
              !publisher.isEmpty else {
            throw AddonError.invalidManifest("Required metadata is missing.")
        }
        for url in endpoints.values {
            guard url.scheme?.lowercased() == "https", url.host != nil else {
                throw AddonError.invalidManifest("Every endpoint must use HTTPS.")
            }
        }
    }
}

enum AddonError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case unsupportedSchema(Int)
    case invalidManifest(String)
    case duplicate(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Enter a valid HTTPS manifest URL."
        case .httpStatus(let code): return "The server returned HTTP \(code)."
        case .unsupportedSchema(let version): return "Manifest schema \(version) is not supported."
        case .invalidManifest(let message): return message
        case .duplicate(let name): return "\(name) is already installed."
        }
    }
}
