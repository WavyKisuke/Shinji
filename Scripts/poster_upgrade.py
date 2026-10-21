from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old in text:
        text = text.replace(old, new, 1)
        p.write_text(text, encoding="utf-8")

player = "Shinji/Views/PlayerView.swift"
player_path = Path(player)
text = player_path.read_text(encoding="utf-8")
if "var posterURL: URL? = nil" not in text:
    text = text.replace(
        '    var headers: [String: String] = [:]\n',
        '    var headers: [String: String] = [:]\n    var posterURL: URL? = nil\n',
        1,
    )
text = text.replace(
    'continueStore.record(id: url.absoluteString, title: title, url: url, position: time, duration: total, headers: headers)',
    'continueStore.record(id: url.absoluteString, title: title, url: url, position: time, duration: total, headers: headers, posterURL: posterURL?.absoluteString)',
)
text = text.replace(
    'continueStore.record(id: url.absoluteString, title: title, url: url, position: position, duration: duration, headers: headers)',
    'continueStore.record(id: url.absoluteString, title: title, url: url, position: position, duration: duration, headers: headers, posterURL: posterURL?.absoluteString)',
)
player_path.write_text(text, encoding="utf-8")

unified = "Shinji/Views/UnifiedLibraryView.swift"
replace_once(
    unified,
    '    @State private var selectedStreamURL: URL?\n',
    '    @State private var selectedStreamURL: URL?\n    @State private var selectedPosterURL: URL?\n',
)
replace_once(
    unified,
    '                        headers: addonStore.streamOptions.first(where: { $0.url == url })?.headers ?? [:]\n',
    '                        headers: addonStore.streamOptions.first(where: { $0.url == url })?.headers ?? [:],\n                        posterURL: selectedPosterURL\n',
)
replace_once(
    unified,
    '                                    selectedStreamURL = option.url\n                                    selectedItem = nil\n',
    '                                    selectedStreamURL = option.url\n                                    selectedPosterURL = item.posterURL\n                                    selectedItem = nil\n',
)
Path(unified).write_text(Path(unified).read_text(encoding="utf-8"), encoding="utf-8")

home = "Shinji/Views/HomeLibraryView.swift"
replace_once(
    home,
    '                    PlayerView(url: url, title: entry.title, headers: entry.headers)\n',
    '                    PlayerView(url: url, title: entry.title, headers: entry.headers, posterURL: entry.posterURL.flatMap(URL.init(string:)))\n',
)
# Keep hero artwork separate from the first Popular Movies posters so the hero
# feels like a rotating featured area rather than a duplicate shelf.
replace_once(
    home,
    '    private var heroItems: [AddonCatalogItem] { Array((movies + series).prefix(6)) }',
    '    private var heroItems: [AddonCatalogItem] { Array((movies.dropFirst(min(6, movies.count)) + series).prefix(6)) }',
)
text = Path(home).read_text(encoding="utf-8")
text = text.replace(
    '.onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect())',
    '.onReceive(Timer.publish(every: 4, on: .main, in: .common).autoconnect())',
    1,
)
Path(home).write_text(text, encoding="utf-8")

print("Keep Watching poster upgrade and distinct rotating hero applied.")
