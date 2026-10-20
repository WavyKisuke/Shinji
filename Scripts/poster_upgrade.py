from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old in text:
        text = text.replace(old, new, 1)
        p.write_text(text, encoding="utf-8")

# Carry the poster URL from the catalog title into playback/resume storage.
player = "Shinji/Views/PlayerView.swift"
replace_once(
    player,
    '    var headers: [String: String] = [:]\n',
    '    var headers: [String: String] = [:]\n    var posterURL: URL? = nil\n',
)
replace_once(
    player,
    'headers: headers)\n',
    'headers: headers, posterURL: posterURL?.absoluteString)\n',
)

# The build repair script injects the Continue Watching state and record calls;
# update those injected calls as well so poster metadata is persisted.
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

# Pass the selected catalog poster into PlayerView. The selected item is cleared
# before playback, so retain the poster separately in state.
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
    '                                    selectedStreamURL = option.url; selectedItem = nil\n',
    '                                    selectedStreamURL = option.url; selectedPosterURL = item.posterURL; selectedItem = nil\n',
)
Path(unified).write_text(Path(unified).read_text(encoding="utf-8"), encoding="utf-8")

# Show the real poster in the Library Keep Watching cards and preserve it when
# reopening playback.
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
