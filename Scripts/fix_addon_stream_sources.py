from pathlib import Path

path = Path("Shinji/Services/AddonStore.swift")
text = path.read_text(encoding="utf-8")

text = text.replace(
'''struct AddonStreamOption: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
    let headers: [String: String]
}''',
'''struct AddonExternalTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let language: String
    let url: URL
    let headers: [String: String]
}

struct AddonStreamOption: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
    let headers: [String: String]
    let audioTracks: [AddonExternalTrack]
    let subtitles: [AddonExternalTrack]
}''')

old = '''                        let suppliedHeaders = stringDictionary(requestInfo?["headers"])
                            ?? stringDictionary(stream["headers"])
                            ?? [:]
                        let optionID = "\\(addon.id)|\\(rawURL)"

                        if !found.contains(where: { $0.id == optionID }) {
                            found.append(AddonStreamOption(
                                id: optionID,
                                title: "\\(streamTitle) · \\(addon.name)",
                                url: parsedURL,
                                headers: suppliedHeaders
                            ))
                        }'''
new = '''                        let suppliedHeaders = stringDictionary(requestInfo?["headers"])
                            ?? stringDictionary(stream["headers"])
                            ?? [:]
                        let audioTracks = parseExternalTracks(stream["audioTracks"], fallbackHeaders: suppliedHeaders, prefix: "audio")
                        let subtitles = parseExternalTracks(stream["subtitles"], fallbackHeaders: suppliedHeaders, prefix: "sub")
                        let optionID = "\\(addon.id)|\\(rawURL)"

                        if !found.contains(where: { $0.id == optionID }) {
                            found.append(AddonStreamOption(
                                id: optionID,
                                title: "\\(streamTitle) · \\(addon.name)",
                                url: parsedURL,
                                headers: suppliedHeaders,
                                audioTracks: audioTracks,
                                subtitles: subtitles
                            ))
                        }'''
if old not in text:
    raise SystemExit("stream construction block not found")
text = text.replace(old, new, 1)

marker = '''    private func stringDictionary(_ value: Any?) -> [String: String]? {'''
method = '''    private func parseExternalTracks(_ value: Any?, fallbackHeaders: [String: String], prefix: String) -> [AddonExternalTrack] {
        guard let entries = value as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            guard let rawURL = (entry["url"] as? String) ?? (entry["src"] as? String),
                  let url = URL(string: rawURL),
                  ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil else { return nil }
            let language = (entry["lang"] as? String) ?? (entry["language"] as? String) ?? ""
            let title = (entry["title"] as? String)
                ?? (entry["name"] as? String)
                ?? (language.isEmpty ? prefix.capitalized : language.uppercased())
            let id = (entry["id"] as? String) ?? (entry["id"] as? Int).map(String.init) ?? rawURL
            let headers = stringDictionary(entry["headers"]) ?? fallbackHeaders
            return AddonExternalTrack(id: id, title: title, language: language, url: url, headers: headers)
        }
    }

'''
if marker not in text:
    raise SystemExit("stringDictionary marker not found")
text = text.replace(marker, method + marker, 1)
path.write_text(text, encoding="utf-8")
print("Patched AddonStore stream metadata")