from pathlib import Path

path = Path("Shinji/Views/UnifiedLibraryView.swift")
s = path.read_text(encoding="utf-8")

replacements = {
    'private let filters = ["For You", "Popular", "Recently Added", "Action", "Drama"]':
        'private let filters = ["For You", "Popular", "Recently Added"]',
    'import SwiftUI\n':
        'import SwiftUI\nimport UIKit\nimport ImageIO\n',
    'ForEach(items) { item in':
        'ForEach(Array(items.prefix(24))) { item in',
}

for old, new in replacements.items():
    if old not in s:
        raise SystemExit(f"Expected source text not found: {old}")
    s = s.replace(old, new, 1)

old_poster = '''                    if let url = item.posterURL {\n                        AsyncImage(url: url) { phase in\n                            switch phase {\n                            case .success(let image):\n                                image.resizable().scaledToFill()\n                            default:\n                                placeholder(for: item)\n                            }\n                        }\n                    } else {\n                        placeholder(for: item)\n                    }'''
new_poster = '''                    if let url = item.posterURL {\n                        CachedPosterImage(url: url, targetSize: CGSize(width: 290, height: height * 2)) {\n                            placeholder(for: item)\n                        }\n                    } else {\n                        placeholder(for: item)\n                    }'''

if old_poster not in s:
    raise SystemExit("Expected AsyncImage poster block not found")
s = s.replace(old_poster, new_poster, 1)

if "private struct CachedPosterImage" not in s:
    s += '''\n\nprivate struct CachedPosterImage<Placeholder: View>: View {\n    let url: URL\n    let targetSize: CGSize\n    @ViewBuilder let placeholder: () -> Placeholder\n    @State private var image: UIImage?\n\n    private static let cache = NSCache<NSURL, UIImage>()\n\n    var body: some View {\n        Group {\n            if let image {\n                Image(uiImage: image)\n                    .resizable()\n                    .scaledToFill()\n            } else {\n                placeholder()\n            }\n        }\n        .task(id: url) {\n            await load()\n        }\n    }\n\n    private func load() async {\n        if let cached = Self.cache.object(forKey: url as NSURL) {\n            image = cached\n            return\n        }\n\n        do {\n            let (data, _) = try await URLSession.shared.data(from: url)\n            guard !Task.isCancelled else { return }\n            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }\n\n            let options: [CFString: Any] = [\n                kCGImageSourceCreateThumbnailFromImageAlways: true,\n                kCGImageSourceCreateThumbnailWithTransform: true,\n                kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height)\n            ]\n            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }\n\n            let decoded = UIImage(cgImage: cgImage)\n            Self.cache.setObject(decoded, forKey: url as NSURL)\n            guard !Task.isCancelled else { return }\n            image = decoded\n        } catch {\n            // Keep the lightweight placeholder when a poster fails.\n        }\n    }\n}\n'''

path.write_text(s, encoding="utf-8")
