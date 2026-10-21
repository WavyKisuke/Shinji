from pathlib import Path

path = Path("Shinji/Views/HomeLibraryView.swift")
text = path.read_text(encoding="utf-8")

# Home should not render the saved Library/watchlist. Saved items belong only
# in Library; Home should show catalog content and Continue Watching.
marker = "    @ViewBuilder\n    private var watchlistSection: some View {"
if marker in text:
    start = text.index(marker)
    next_marker = "    @ViewBuilder\n    private func catalogSection"
    end = text.index(next_marker, start)
    text = text[:start] + text[end:]

# Some previous versions used the same block without the exact declaration
# above. Remove any remaining direct watchlistStore references by deleting the
# enclosing computed section.
if "watchlistStore" in text:
    lines = text.splitlines(keepends=True)
    out = []
    i = 0
    while i < len(lines):
        if "watchlistStore" in lines[i] or "private var myListSection" in lines[i]:
            # Skip backward only when this starts a ViewBuilder section.
            i += 1
            depth = 0
            while i < len(lines):
                depth += lines[i].count("{") - lines[i].count("}")
                if depth <= 0 and lines[i].strip() == "}":
                    i += 1
                    break
                i += 1
            continue
        out.append(lines[i])
        i += 1
    text = "".join(out)

path.write_text(text, encoding="utf-8")
