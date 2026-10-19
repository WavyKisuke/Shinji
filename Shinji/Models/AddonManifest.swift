import Foundation

struct AddonManifest: Codable, Identifiable, Hashable {
    let schemaVersion: Int
    let id: String
    let name: String
    let version: String
    let publisher: String
    let capabilities: [String]
    let endpoints: [String: URL]
    let manifestURL: URL?
    let format: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, version, publisher, capabilities, endpoints, manifestURL, format
    }

    init(
        schemaVersion: Int,
        id: String,
        name: String,
        version: String,
        publisher: String,
        capabilities: [String],
        endpoints: [String: URL],
        manifestURL: URL? = nil,
        format: String = "Shinji"
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.version = version
        self.publisher = publisher
        self.capabilities = capabilities
        self.endpoints = endpoints
        self.manifestURL = manifestURL
        self.format = format
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        version = try c.decodeIfPresent(String.self, forKey: .version) ?? "unknown"
        publisher = try c.decodeIfPresent(String.self, forKey: .publisher) ?? "Unknown publisher"
        capabilities = try c.decodeIfPresent([String].self, forKey: .capabilities) ?? []
        endpoints = try c.decodeIfPresent([String: URL].self, forKey: .endpoints) ?? [:]
        manifestURL = try c.decodeIfPresent(URL.self, forKey: .manifestURL)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? "Shinji"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(version, forKey: .version)
        try c.encode(publisher, forKey: .publisher)
        try c.encode(capabilities, forKey: .capabilities)
        try c.encode(endpoints, forKey: .endpoints)
        try c.encodeIfPresent(manifestURL, forKey: .manifestURL)
        try c.encode(format, forKey: .format)
    }

    static func parse(data: Data, sourceURL: URL) throws -> AddonManifest {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            throw AddonError.invalidManifest("The manifest must be a JSON object.")
        }

        if json["schemaVersion"] != nil {
            let manifest = try JSONDecoder().decode(AddonManifest.self, from: data)
            return AddonManifest(
                schemaVersion: manifest.schemaVersion,
                id: manifest.id,
                name: manifest.name,
                version: manifest.version,
                publisher: manifest.publisher,
                capabilities: manifest.capabilities,
                endpoints: manifest.endpoints,
                manifestURL: sourceURL,
                format: "Shinji"
            )
        }

        // Stremio-style add-on manifests use id/name/version plus resources/types/catalogs.
        guard let id = json["id"] as? String, !id.isEmpty,
              let name = json["name"] as? String, !name.isEmpty,
              let version = json["version"] as? String, !version.isEmpty else {
            throw AddonError.invalidManifest("This JSON is not a recognized Shinji or Stremio-style add-on manifest. Required fields: id, name and version.")
        }

        var capabilities: [String] = []
        if let types = json["types"] as? [String] { capabilities.append(contentsOf: types) }
        if let resources = json["resources"] as? [String] {
            capabilities.append(contentsOf: resources)
        } else if let resources = json["resources"] as? [[String: Any]] {
            for resource in resources {
                if let name = resource["name"] as? String { capabilities.append(name) }
            }
        }
        if let catalogs = json["catalogs"] as? [[String: Any]], !catalogs.isEmpty {
            capabilities.append("catalogs")
        }

        let publisher = (json["contactEmail"] as? String)
            ?? (json["publisher"] as? String)
            ?? "Stremio add-on"

        return AddonManifest(
            schemaVersion: 1,
            id: id,
            name: name,
            version: version,
            publisher: publisher,
            capabilities: Array(Set(capabilities)).sorted(),
            endpoints: [:],
            manifestURL: sourceURL,
            format: "Stremio"
        )
    }

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
        case .httpStatus(let code): return "The server returned HTTP \\(code)."
        case .unsupportedSchema(let version): return "Manifest schema \\(version) is not supported."
        case .invalidManifest(let message): return message
        case .duplicate(let name): return "\\(name) is already installed."
        }
    }
}
