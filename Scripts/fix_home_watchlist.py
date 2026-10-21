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

# Add a confirmation alert so a long-press on Continue Watching can remove an item
# without accidentally affecting the user's Library/favorites.
if '@State private var entryToDelete: ContinueWatchingItem?' not in text:
    text = text.replace(
        '    @State private var showPlayer = false\n',
        '    @State private var showPlayer = false\n    @State private var entryToDelete: ContinueWatchingItem?\n    @State private var showDeleteConfirmation = false\n',
        1,
    )

alert_marker = '''            .navigationDestination(isPresented: $showPlayer) {
                if let entry = selectedEntry, let url = URL(string: entry.url) {
                    PlayerView(url: url, title: entry.title, headers: entry.headers, posterURL: entry.posterURL.flatMap(URL.init(string:)))
                }
            }
'''
if 'Remove from Continue Watching?' not in text and alert_marker in text:
    alert = '''            .alert("Remove from Continue Watching?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    entryToDelete = nil
                }
                Button("Remove", role: .destructive) {
                    if let entry = entryToDelete {
                        continueStore.remove(id: entry.id)
                    }
                    entryToDelete = nil
                }
            } message: {
                if let entry = entryToDelete {
                    Text("\\(entry.title) will be removed from Continue Watching. Your library/favorites will not be affected.")
                }
            }
'''
    text = text.replace(alert_marker, alert_marker + alert, 1)

# Long-press a Continue Watching card to get a native Remove action.
card_end = '''        }.buttonStyle(.plain)
    }

    private func remainingText'''
if 'Remove from Continue Watching", systemImage: "trash"' not in text and card_end in text:
    replacement = '''        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                entryToDelete = entry
                showDeleteConfirmation = true
            } label: {
                Label("Remove from Continue Watching", systemImage: "trash")
            }
        }
    }

    private func remainingText'''
    text = text.replace(card_end, replacement, 1)

path.write_text(text, encoding="utf-8")
