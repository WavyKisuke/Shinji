from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old in text:
        text = text.replace(old, new, 1)
        p.write_text(text, encoding="utf-8")

player = "Shinji/Views/PlayerView.swift"
replace_once(
    player,
    '    var headers: [String: String] = [:]\n',
    '    var headers: [String: String] = [:]\n    var posterURL: URL? = nil\n',
)
text = Path(player).read_text(encoding="utf-8")
text = text.replace(
    'continueStore.record(id: url.absoluteString, title: title, url: url, position: time, duration: total, headers: headers)',
    'continueStore.record(id: url.absoluteString, title: title, url: url, position: time, duration: total, headers: headers, posterURL: posterURL?.absoluteString)',
)
text = text.replace(
    'continueStore.record(id: url.absoluteString, title: title, url: url, position: position, duration: duration, headers: headers)',
    'continueStore.record(id: url.absoluteString, title: title, url: url, position: position, duration: duration, headers: headers, posterURL: posterURL?.absoluteString)',
)
Path(player).write_text(text, encoding="utf-8")

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
old_card = '''                    RoundedRectangle(cornerRadius: 18)\n                        .fill(Color.white.opacity(0.08))\n                        .overlay(Image(systemName: "play.rectangle.fill")\n                            .font(.system(size: 34))\n                            .foregroundStyle(.white.opacity(0.55)))\n'''
new_card = '''                    RoundedRectangle(cornerRadius: 18)\n                        .fill(Color.white.opacity(0.08))\n                    if let rawPoster = entry.posterURL, let poster = URL(string: rawPoster) {\n                        AsyncImage(url: poster) { phase in\n                            if case .success(let image) = phase {\n                                image.resizable().scaledToFill()\n                            } else {\n                                Image(systemName: "play.rectangle.fill")\n                                    .font(.system(size: 34))\n                                    .foregroundStyle(.white.opacity(0.55))\n                            }\n                        }\n                    } else {\n                        Image(systemName: "play.rectangle.fill")\n                            .font(.system(size: 34))\n                            .foregroundStyle(.white.opacity(0.55))\n                    }\n'''
replace_once(home, old_card, new_card)
Path(home).write_text(Path(home).read_text(encoding="utf-8"), encoding="utf-8")

print("Keep Watching poster upgrade applied.")
