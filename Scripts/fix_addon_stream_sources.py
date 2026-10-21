from pathlib import Path

path = Path("Shinji/Services/AddonStore.swift")
text = path.read_text(encoding="utf-8")

# Keep the repair deterministic: patch the exact stream model instead of
# matching the first `headers` field (which belongs to AddonExternalTrack).
if "struct AddonExternalTrack: Identifiable, Hashable" not in text:
    anchor = "struct AddonStreamOption: Identifiable, Hashable {\n    let id: String\n    let title: String\n    let url: URL\n    let headers: [String: String]\n}"
    if anchor not in text:
        raise SystemExit("AddonStreamOption model not found")
    replacement = '''struct AddonExternalTrack: Identifiable, Hashable {
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
}'''
    text = text.replace(anchor, replacement, 1)
else:
    # Normalize older partially patched versions where the fields were placed
    # on the wrong struct.
    start = text.index("struct AddonExternalTrack: Identifiable, Hashable {")
    end = text.index("struct AddonCatalogItem: Identifiable, Hashable {", start)
    text = text[:start] + '''struct AddonExternalTrack: Identifiable, Hashable {
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
}

''' + text[end:]

old = '''                        found.append(AddonStreamOption(
                            id: optionID,
                            title: "\\(streamTitle) · \\(addon.name)",
                            url: parsedURL,
                            headers: suppliedHeaders
                        ))'''
new = '''                        found.append(AddonStreamOption(
                            id: optionID,
                            title: "\\(streamTitle) · \\(addon.name)",
                            url: parsedURL,
                            headers: suppliedHeaders,
                            audioTracks: parseExternalTracks(stream["audioTracks"], fallbackHeaders: suppliedHeaders, prefix: "audio"),
                            subtitles: parseExternalTracks(stream["subtitles"], fallbackHeaders: suppliedHeaders, prefix: "sub")
                        ))'''
if old in text:
    text = text.replace(old, new, 1)

if "private func parseExternalTracks" not in text:
    marker = "    private func streamURL(base: URL, item: AddonCatalogItem) -> URL? {"
    if marker not in text:
        raise SystemExit("streamURL marker not found")
    helper = '''    private func parseExternalTracks(_ value: Any?, fallbackHeaders: [String: String], prefix: String) -> [AddonExternalTrack] {
        guard let entries = value as? [[String: Any]] else { return [] }
        var result: [AddonExternalTrack] = []
        for entry in entries {
            guard let rawURL = (entry["url"] as? String) ?? (entry["src"] as? String),
                  let url = URL(string: rawURL),
                  ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil else { continue }
            let language = (entry["lang"] as? String) ?? (entry["language"] as? String) ?? ""
            let title = (entry["title"] as? String)
                ?? (entry["name"] as? String)
                ?? (language.isEmpty ? prefix.capitalized : language.uppercased())
            let id = (entry["id"] as? String)
                ?? (entry["id"] as? Int).map(String.init)
                ?? rawURL
            let headers = (entry["headers"] as? [String: String]) ?? fallbackHeaders
            result.append(AddonExternalTrack(id: id, title: title, language: language, url: url, headers: headers))
        }
        return result
    }

'''
    text = text.replace(marker, helper + marker, 1)

path.write_text(text, encoding="utf-8")
print("Patched AddonStore stream metadata")
