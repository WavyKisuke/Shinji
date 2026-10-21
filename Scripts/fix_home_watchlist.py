from pathlib import Path

path = Path("Shinji/Views/HomeLibraryView.swift")
text = path.read_text(encoding="utf-8")

# Home must never render My List/watchlist. Saved items belong only in Library.
# Keep Continue Watching and catalog shelves on Home.
text = text.replace('    @StateObject private var watchlistStore = WatchlistStore.shared\n', '', 1)
text = text.replace('                    myListSection\n', '', 1)

# Remove the exact My List computed section that older repair scripts inserted.
start_marker = '    @ViewBuilder\n    private var myListSection: some View {'
end_marker = '    private func continueCard(_ entry: ContinueWatchingItem) -> some View {'
if start_marker in text and end_marker in text:
    start = text.index(start_marker)
    end = text.index(end_marker, start)
    text = text[:start] + text[end:]

# Remove a legacy watchlistSection, if present, without touching unrelated code.
legacy_marker = '    @ViewBuilder\n    private var watchlistSection: some View {'
if legacy_marker in text and end_marker in text:
    start = text.index(legacy_marker)
    end = text.index(end_marker, start)
    text = text[:start] + text[end:]

path.write_text(text, encoding="utf-8")
