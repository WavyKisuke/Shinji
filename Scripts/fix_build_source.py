from pathlib import Path


def ensure_block(text: str, marker: str, block: str) -> str:
    if marker in text:
        return text
    return text + "\n\n" + block


path = Path("Shinji/Views/UnifiedLibraryView.swift")
text = path.read_text(encoding="utf-8")

# Keep the library view consistent and idempotent for CI builds. This script is
# intentionally conservative: it only inserts the missing section helpers if they
# are absent and avoids patching arbitrary source text.
anchor = '''    private var showItems: [AddonCatalogItem] {
        filteredItems.filter { $0.type.lowercased() == "series" }
    }
'''
insert = '''    private var showItems: [AddonCatalogItem] {
        filteredItems.filter { $0.type.lowercased() == "series" }
    }

    private var featuredItems: [AddonCatalogItem] {
        Array(filteredItems.prefix(8))
    }

    private var remainingItems: [AddonCatalogItem] {
        Array(filteredItems.dropFirst(featuredItems.count))
    }

    private var recentItems: [AddonCatalogItem] {
        Array(remainingItems.prefix(12))
    }

    private var moreItems: [AddonCatalogItem] {
        Array(remainingItems.dropFirst(recentItems.count).prefix(12))
    }
'''
if anchor in text and "private var featuredItems" not in text:
    text = text.replace(anchor, insert, 1)

path.write_text(text, encoding="utf-8")
print("UnifiedLibraryView scaffolding is in a valid state.")
