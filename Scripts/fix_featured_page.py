from pathlib import Path

unified = Path("Shinji/Views/UnifiedLibraryView.swift")
text = unified.read_text(encoding="utf-8")

old = '''                Spacer()\n                Image(systemName: "arrow.right")\n                    .foregroundStyle(Color(hex: accentHex))\n'''
new = '''                Spacer()\n                NavigationLink {\n                    CatalogGridPage(\n                        title: selectedFilter == "For You" ? (kind == .movies ? "Featured Movies" : "Featured TV Shows") : selectedFilter,\n                        items: filteredItems,\n                        accentHex: accentHex,\n                        glowHex: glowHex,\n                        onSelect: { selectedItem = $0 }\n                    )\n                } label: {\n                    Image(systemName: "arrow.right")\n                        .font(.system(size: 17, weight: .bold))\n                        .foregroundStyle(Color(hex: accentHex))\n                        .frame(width: 40, height: 40)\n                        .contentShape(Rectangle())\n                }\n                .buttonStyle(.plain)\n                .disabled(filteredItems.isEmpty)\n'''
text = text.replace(old, new, 1)

# The dedicated CatalogGridPage lives in its own source file. Do not append a second copy
# to UnifiedLibraryView; that caused an invalid redeclaration during CI builds.
marker = "\n\nstruct CatalogGridPage: View {"
if marker in text:
    text = text.split(marker, 1)[0].rstrip() + "\n"

unified.write_text(text, encoding="utf-8")
print("Featured page repair applied.")
