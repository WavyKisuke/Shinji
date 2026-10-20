from pathlib import Path

path = Path("Shinji/Views/UnifiedLibraryView.swift")
text = path.read_text(encoding="utf-8")
bad = 'let text = "\\(item.name) \\(item.description ?? \\\"\\\")"'
good = 'let text = "\\(item.name) \\(item.description ?? "")"'
if bad in text:
    text = text.replace(bad, good)
    path.write_text(text, encoding="utf-8")
    print("Fixed malformed string interpolation in UnifiedLibraryView.swift")
else:
    print("No malformed interpolation found; source is already correct")
