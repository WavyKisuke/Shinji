from pathlib import Path

path = Path("Shinji/Views/UnifiedLibraryView.swift")
s = path.read_text(encoding="utf-8")

replacements = {
    'import SwiftUI\n':
        'import SwiftUI\nimport UIKit\nimport ImageIO\n',
    'struct UnifiedLibraryView: View {':
        '''enum MediaLibraryKind {\n    case movies\n    case tvShows\n}\n\nstruct UnifiedLibraryView: View {\n    let kind: MediaLibraryKind''',
    'private let filters = ["For You", "Popular", "Recently Added", "Action", "Drama"]':
        'private let filters = ["For You", "Popular", "Recently Added"]',
    '''        addonStore.catalogItems.filter { item in\n            ["movie", "series"].contains(item.type.lowercased())\n        }''':
        '''        addonStore.catalogItems.filter { item in\n            let type = item.type.lowercased()\n            switch kind {\n            case .movies:\n                return type == "movie"\n            case .tvShows:\n                return type == "series"\n            }\n        }''',
    '''                    featuredSection\n                    shelfSection("Recently Added Movies", items: movieItems)\n                    shelfSection("Recently Added Shows", items: showItems)\n                    if selectedFilter == "For You" {\n                        shelfSection("More Movies & Shows", items: filteredItems)\n                    }''':
        '''                    if kind == .movies {\n                        shelfSection("Featured Movies", items: Array(movieItems.prefix(12)))\n                        shelfSection("Recently Added Movies", items: Array(movieItems.prefix(24)))\n                        shelfSection("Popular Movies", items: Array(movieItems.prefix(24)))\n                    } else {\n                        shelfSection("Featured TV Shows", items: Array(showItems.prefix(12)))\n                        shelfSection("Recently Added TV Shows", items: Array(showItems.prefix(24)))\n                        shelfSection("Popular TV Shows", items: Array(showItems.prefix(24)))\n                    }''',
    'Text("Movies & TV")':
        'Text(kind == .movies ? "Movies" : "TV Shows")',
    'Text("Movies and shows in one place")':
        'Text(kind == .movies ? "Movies, organized your way" : "TV shows, organized your way")',
    'TextField("Search movies and shows", text: $searchText)':
        'TextField(kind == .movies ? "Search movies" : "Search TV shows", text: $searchText)',
    'ForEach(items) { item in':
        'ForEach(Array(items.prefix(24))) { item in',
}

for old, new in replacements.items():
    if old not in s:
        raise SystemExit(f"Expected source text not found: {old[:100]}")
    s = s.replace(old, new, 1)

old_poster = '''                    if let url = item.posterURL {\n                        AsyncImage(url: url) { phase in\n                            switch phase {\n                            case .success(let image):\n                                image.resizable().scaledToFill()\n                            default:\n                                placeholder(for: item)\n                            }\n                        }\n                    } else {\n                        placeholder(for: item)\n                    }'''
new_poster = '''                    if let url = item.posterURL {\n                        CachedPosterImage(url: url, targetSize: CGSize(width: 290, height: height * 2)) {\n                            placeholder(for: item)\n                        }\n                    } else {\n                        placeholder(for: item)\n                    }'''

if old_poster not in s:
    raise SystemExit("Expected AsyncImage poster block not found")
s = s.replace(old_poster, new_poster, 1)

if "private struct CachedPosterImage" not in s:
    s += '''\n\nprivate enum PosterImageCache {\n    static let images: NSCache<NSURL, UIImage> = {\n        let cache = NSCache<NSURL, UIImage>()\n        cache.countLimit = 160\n        cache.totalCostLimit = 64 * 1024 * 1024\n        return cache\n    }()\n}\n\nprivate struct CachedPosterImage<Placeholder: View>: View {\n    let url: URL\n    let targetSize: CGSize\n    @ViewBuilder let placeholder: () -> Placeholder\n    @State private var image: UIImage?\n\n    var body: some View {\n        Group {\n            if let image {\n                Image(uiImage: image)\n                    .resizable()\n                    .scaledToFill()\n            } else {\n                placeholder()\n            }\n        }\n        .task(id: url) { await load() }\n    }\n\n    private func load() async {\n        if let cached = PosterImageCache.images.object(forKey: url as NSURL) {\n            image = cached\n            return\n        }\n        do {\n            let (data, _) = try await URLSession.shared.data(from: url)\n            guard !Task.isCancelled, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }\n            let options: [CFString: Any] = [\n                kCGImageSourceCreateThumbnailFromImageAlways: true,\n                kCGImageSourceCreateThumbnailWithTransform: true,\n                kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height)\n            ]\n            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }\n            let decoded = UIImage(cgImage: cgImage)\n            let cost = decoded.cgImage.map { $0.bytesPerRow * $0.height } ?? 0\n            PosterImageCache.images.setObject(decoded, forKey: url as NSURL, cost: cost)\n            guard !Task.isCancelled else { return }\n            image = decoded\n        } catch { }\n    }\n}\n'''

path.write_text(s, encoding="utf-8")

# The player should be driven by one native MPV surface, while SwiftUI owns
# the controls. Register the player with the orientation coordinator so a
# physical phone rotation can enter/exit landscape immediately.
player_path = Path("Shinji/Views/PlayerView.swift")
p = player_path.read_text(encoding="utf-8")
old_player_orientation_start = '            UIDevice.current.beginGeneratingDeviceOrientationNotifications()\n            hideParentTabBar(true)'
new_player_orientation_start = '            OrientationLockCoordinator.playerDidAppear()\n            hideParentTabBar(true)'
if old_player_orientation_start not in p:
    raise SystemExit("Expected player orientation setup not found")
p = p.replace(old_player_orientation_start, new_player_orientation_start, 1)
player_path.write_text(p, encoding="utf-8")
