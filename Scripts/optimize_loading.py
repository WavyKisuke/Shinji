from pathlib import Path

# Keep image requests cacheable so repeated Home/Search/Library artwork can be served
# from memory/disk instead of re-downloading on every view.
app = Path("Shinji/ShinjiApp.swift")
text = app.read_text(encoding="utf-8")
if "URLCache.shared = URLCache" not in text:
    text = text.replace("import SwiftUI\n", "import SwiftUI\nimport Foundation\n", 1)
    text = text.replace(
        "struct ShinjiApp: App {\n",
        '''struct ShinjiApp: App {
    init() {
        let cache = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024, diskPath: "shinji-artwork")
        URLCache.shared = cache
        URLSession.shared.configuration.requestCachePolicy = .returnCacheDataElseLoad
    }

''', 1)
    app.write_text(text, encoding="utf-8")

# Lazy horizontal shelves prevent every poster in a row from starting a request at once.
for name in [
    "HomeLibraryView.swift",
    "CatalogGridPage.swift",
    "SearchView.swift",
    "LibraryView.swift",
]:
    path = Path("Shinji/Views") / name
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    text = text.replace("HStack(alignment: .top, spacing: 14)", "LazyHStack(alignment: .top, spacing: 14)")
    text = text.replace("HStack(spacing: 14) {", "LazyHStack(spacing: 14) {")
    text = text.replace("HStack(spacing: 12) {", "LazyHStack(spacing: 12) {")
    path.write_text(text, encoding="utf-8")

# Avoid an oversized hero artwork request where the source supports image resizing.
# The existing AsyncImage pipeline remains the fallback for sources that do not expose
# resize parameters.
