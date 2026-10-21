from pathlib import Path
import re

path = Path("Shinji/Services/AddonStore.swift")
text = path.read_text(encoding="utf-8")

if "struct AddonExternalTrack: Identifiable, Hashable" not in text:
    anchor = "struct AddonStreamOption: Identifiable, Hashable {"
    if anchor not in text:
        raise SystemExit("AddonStreamOption model not found")
    text = text.replace(anchor, '''struct AddonExternalTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let language: String
    let url: URL
    let headers: [String: String]
}

struct AddonStreamOption: Identifiable, Hashable {''', 1)

if "let audioTracks: [AddonExternalTrack]" not in text:
    marker = "    let headers: [String: String]\n}"
    if marker not in text:
        raise SystemExit("AddonStreamOption fields not found")
    text = text.replace(marker, "    let headers: [String: String]\n    let audioTracks: [AddonExternalTrack]\n    let subtitles: [AddonExternalTrack]\n}", 1)

if "audioTracks: parseExternalTracks" not in text:
    pattern = r'''(?P<indent>\s*)found\.append\(AddonStreamOption\(\s*id: optionID,\s*title: "\\\(streamTitle\) · \\\(addon\.name\)",\s*url: parsedURL,\s*headers: suppliedHeaders\s*\)\)'''
    match = re.search(pattern, text)
    if not match:
        raise SystemExit("stream construction block not found")
    indent = match.group("indent")
    replacement = f'''{indent}found.append(AddonStreamOption(
{indent}    id: optionID,
{indent}    title: "\\(streamTitle) · \\(addon.name)",
{indent}    url: parsedURL,
{indent}    headers: suppliedHeaders,
{indent}    audioTracks: parseExternalTracks(stream["audioTracks"], fallbackHeaders: suppliedHeaders, prefix: "audio"),
{indent}    subtitles: parseExternalTracks(stream["subtitles"], fallbackHeaders: suppliedHeaders, prefix: "sub")
{indent}))'''
    text = text[:match.start()] + replacement + text[match.end():]

if "private func parseExternalTracks" not in text:
    marker = "    private func stringDictionary(_ value: Any?) -> [String: String]? {"
    if marker not in text:
        raise SystemExit("stringDictionary marker not found")
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
    text = text.replace(marker, method + marker, 1)

path.write_text(text, encoding="utf-8")
print("Patched AddonStore stream metadata")