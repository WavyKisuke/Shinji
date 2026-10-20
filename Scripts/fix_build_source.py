from pathlib import Path

path = Path("Shinji/Views/UnifiedLibraryView.swift")
text = path.read_text(encoding="utf-8")

# Repair the old malformed interpolation if it is still present.
bad = 'let text = "\\(item.name) \\(item.description ?? \\\"\\\")"'
good = 'let text = "\\(item.name) \\(item.description ?? "")"'
if bad in text:
    text = text.replace(bad, good)

# Keep the home screen from rendering the same catalog titles in every shelf.
old_body = '''                    featuredSection
                    if kind == .movies {
                        shelfSection("Recently Added Movies", items: movieItems)
                        shelfSection("Popular Movies", items: Array(movieItems.prefix(24)))
                    } else {
                        shelfSection("Recently Added TV Shows", items: showItems)
                        shelfSection("Popular TV Shows", items: Array(showItems.prefix(24)))
                    }
                    if selectedFilter == "For You" {
                        shelfSection(kind == .movies ? "More Movies" : "More TV Shows", items: filteredItems)
                    }
                    footer'''
new_body = '''                    featuredSection
                    shelfSection(
                        kind == .movies ? "Recently Added Movies" : "Recently Added TV Shows",
                        items: recentItems
                    )
                    shelfSection(
                        kind == .movies ? "More Movies" : "More TV Shows",
                        items: moreItems
                    )
                    footer'''
if old_body in text:
    text = text.replace(old_body, new_body, 1)

old_featured = '''                        ForEach(Array(filteredItems.prefix(12))) { item in
                            posterCard(item, height: 190)
                        }'''
new_featured = '''                        ForEach(featuredItems) { item in
                            posterCard(item, height: 190)
                        }'''
if old_featured in text:
    text = text.replace(old_featured, new_featured, 1)

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

# Deduplicate catalog results by the model's stable ID.
old_return = '''        return result
    }

    private var movieItems'''
new_return = '''        var seen = Set<String>()
        return result.filter { item in
            seen.insert(item.id).inserted
        }
    }

    private var movieItems'''
if old_return in text:
    text = text.replace(old_return, new_return, 1)

path.write_text(text, encoding="utf-8")
print("Applied library shelf de-duplication and section partitioning")
