from pathlib import Path


def replace_once(text: str, old: str, new: str) -> str:
    if not old:
        return text
    if old not in text:
        return text
    return text.replace(old, new, 1)


def ensure_block(text: str, marker: str, block: str) -> str:
    if marker in text:
        return text
    return text + "\n\n" + block


# UnifiedLibraryView.swift
path = Path("Shinji/Views/UnifiedLibraryView.swift")
s = path.read_text(encoding="utf-8")

s = replace_once(s, 'import SwiftUI\n', 'import SwiftUI\nimport UIKit\nimport ImageIO\n')

if 'enum MediaLibraryKind: Equatable {' not in s and 'struct UnifiedLibraryView: View {' in s:
    s = replace_once(
        s,
        'struct UnifiedLibraryView: View {',
        '''enum MediaLibraryKind: Equatable {
    case movies
    case tvShows
}

struct UnifiedLibraryView: View {
    let kind: MediaLibraryKind
''',
    )

s = replace_once(
    s,
    'private let filters = ["For You", "Popular", "Recently Added", "Action", "Drama"]',
    'private let filters = ["For You", "Popular", "Recently Added"]',
)

# Keep this patch safe if the file is already processed or partially patched.
s = ensure_block(
    s,
    'private enum PosterImageCache',
    '''
private enum PosterImageCache {
    static let images: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 160
        return cache
    }()
}
''',
)

path.write_text(s, encoding="utf-8")

# PlayerView.swift
player_path = Path("Shinji/Views/PlayerView.swift")
p = player_path.read_text(encoding="utf-8")

if 'OrientationLockCoordinator.playerDidAppear()' not in p:
    p = replace_once(
        p,
        '            UIDevice.current.beginGeneratingDeviceOrientationNotifications()\n            hideParentTabBar(true)',
        '            UIDevice.current.beginGeneratingDeviceOrientationNotifications()\n            OrientationLockCoordinator.playerDidAppear()\n            hideParentTabBar(true)',
    )

player_path.write_text(p, encoding="utf-8")
