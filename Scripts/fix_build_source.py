from pathlib import Path

unified = Path("Shinji/Views/UnifiedLibraryView.swift")
text = unified.read_text(encoding="utf-8")

text = text.replace(
    '        let text = "\\(item.name) \\(item.description ?? \\\"\\\")"',
    '        let text = item.name + " " + (item.description ?? "")',
)
text = text.replace(
    '    private let filters = ["For You", "Popular", "Recently Added", "Action", "Drama"]',
    '    private let filters = ["For You", "Popular", "Recently Added"]',
)
old_matches = '''    private func matches(_ item: AddonCatalogItem, genre: String) -> Bool {
        let text = "\\(item.name) \\(item.description ?? "")"
        return text.localizedCaseInsensitiveContains(genre)
    }
'''
new_matches = '''    private func matches(_ item: AddonCatalogItem, genre: String) -> Bool {
        let wanted = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        if item.genres.contains(where: { stored in
            let value = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.localizedCaseInsensitiveCompare(wanted) == .orderedSame
                || value.localizedCaseInsensitiveContains(wanted)
                || wanted.localizedCaseInsensitiveContains(value)
        }) { return true }
        let text = "\\(item.name) \\(item.description ?? "")"
        return text.localizedCaseInsensitiveContains(wanted)
    }
'''
text = text.replace(old_matches, new_matches, 1)

# Featured Picks opens a full catalog page.
old_featured_arrow = '''                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color(hex: accentHex))
'''
new_featured_arrow = '''                Spacer()
                NavigationLink {
                    CatalogGridPage(
                        title: selectedFilter == "For You" ? (kind == .movies ? "Featured Movies" : "Featured TV Shows") : selectedFilter,
                        items: filteredItems,
                        accentHex: accentHex,
                        glowHex: glowHex,
                        onSelect: { selectedItem = $0 }
                    )
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: accentHex))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(filteredItems.isEmpty)
'''
text = text.replace(old_featured_arrow, new_featured_arrow, 1)

# Every shelf chevron opens the complete shelf on its own page.
old_shelf_arrow = '''                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
'''
new_shelf_arrow = '''                    Spacer()
                    NavigationLink {
                        CatalogGridPage(
                            title: title,
                            items: items,
                            accentHex: accentHex,
                            glowHex: glowHex,
                            onSelect: { selectedItem = $0 }
                        )
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: accentHex))
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
'''
text = text.replace(old_shelf_arrow, new_shelf_arrow, 1)
unified.write_text(text, encoding="utf-8")

# Carry genre metadata from Stremio catalog responses into the model.
addon = Path("Shinji/Services/AddonStore.swift")
addon_text = addon.read_text(encoding="utf-8")
addon_text = addon_text.replace(
    '    let description: String?\n    let addonName: String\n',
    '    let description: String?\n    let genres: [String]\n    let addonName: String\n', 1)
addon_text = addon_text.replace(
    '            let poster = (meta["poster"] as? String).flatMap(URL.init(string:))\n            return AddonCatalogItem(\n',
    '''            let poster = (meta["poster"] as? String).flatMap(URL.init(string:))
            var genres: [String] = []
            if let values = meta["genres"] as? [String] { genres.append(contentsOf: values) }
            else if let value = meta["genres"] as? String { genres.append(contentsOf: value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }) }
            if let values = meta["genre"] as? [String] { genres.append(contentsOf: values) }
            else if let value = meta["genre"] as? String { genres.append(contentsOf: value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }) }
            genres = Array(Set(genres.filter { !$0.isEmpty }))
            return AddonCatalogItem(
''', 1)
addon_text = addon_text.replace(
    '                description: meta["description"] as? String,\n                addonName: addonName\n',
    '                description: meta["description"] as? String,\n                genres: genres,\n                addonName: addonName\n', 1)
addon.write_text(addon_text, encoding="utf-8")

# Keep MPV command fixes in every CI build.
mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
mpv_text = mpv.read_text(encoding="utf-8")
old_execute = '''    private func execute(_ arguments: [String], on handle: OpaquePointer) {
        var cargs: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
        cargs.append(nil)
        defer {
            for pointer in cargs where pointer != nil { free(pointer) }
        }
        let result = cargs.withUnsafeMutableBufferPointer { buffer in
            mpv_command(handle, buffer.baseAddress)
        }
        if result < 0 {
            publishError("MPV command failed: \\(String(cString: mpv_error_string(result)))")
        }
    }
'''
new_execute = '''    private func execute(_ arguments: [String], on handle: OpaquePointer) {
        var owned: [UnsafeMutablePointer<CChar>] = arguments.map { strdup($0) }
        defer { for pointer in owned { free(pointer) } }
        var cargs: [UnsafePointer<CChar>?] = owned.map { UnsafePointer($0) }
        cargs.append(nil)
        let result = cargs.withUnsafeBufferPointer { buffer in
            mpv_command(handle, buffer.baseAddress)
        }
        if result < 0 {
            publishError("MPV command failed: \\(String(cString: mpv_error_string(result)))")
        }
    }
'''
if old_execute in mpv_text: mpv_text = mpv_text.replace(old_execute, new_execute, 1)
mpv_text = mpv_text.replace('["cycle", "audio"]', '["cycle", "aid"]')
mpv_text = mpv_text.replace('["cycle", "sub"]', '["cycle", "sid"]')
mpv.write_text(mpv_text, encoding="utf-8")

# Automatically populate Keep Watching from playback sessions.
player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")
p = p.replace('    var headers: [String: String] = [:]\n', '    var headers: [String: String] = [:]\n    @StateObject private var continueStore = ContinueWatchingStore.shared\n', 1)
p = p.replace('    @State private var showSettings = false\n', '    @State private var showSettings = false\n    @State private var didResume = false\n    @State private var lastProgressSave = Date.distantPast\n', 1)
p = p.replace('''                if status.localizedCaseInsensitiveContains("loaded") {
                    isPreparingPlayback = false
                }''', '''                if status.localizedCaseInsensitiveContains("loaded") {
                    isPreparingPlayback = false
                    if !didResume, let saved = continueStore.item(for: url.absoluteString), saved.position > 5 {
                        didResume = true
                        position = saved.position
                        ignorePositionUpdatesUntil = Date().addingTimeInterval(1.0)
                        sendCommand(["seek", String(saved.position), "absolute"])
                    } else if !didResume { didResume = true }
                }''', 1)
p = p.replace('''                duration = total
                isPlaying = !paused
                if total > 0 { isPreparingPlayback = false }''', '''                duration = total
                isPlaying = !paused
                if total > 0 {
                    if Date().timeIntervalSince(lastProgressSave) >= 2 {
                        lastProgressSave = Date()
                        continueStore.record(id: url.absoluteString, title: title, url: url, position: time, duration: total, headers: headers)
                    }
                    isPreparingPlayback = false
                }''', 1)
p = p.replace('''        .onDisappear {
            hideControlsTask?.cancel()''', '''        .onDisappear {
            if duration > 0 { continueStore.record(id: url.absoluteString, title: title, url: url, position: position, duration: duration, headers: headers) }
            hideControlsTask?.cancel()''', 1)
p = p.replace('''        isScrubbing = false
        if reloadStream {''', '''        isScrubbing = false
        didResume = false
        lastProgressSave = Date.distantPast
        if reloadStream {''', 1)
player.write_text(p, encoding="utf-8")

# Persistent My List section.
home = Path("Shinji/Views/HomeLibraryView.swift")
h = home.read_text(encoding="utf-8")
h = h.replace('    @StateObject private var continueStore = ContinueWatchingStore.shared\n', '    @StateObject private var continueStore = ContinueWatchingStore.shared\n    @StateObject private var watchlistStore = WatchlistStore.shared\n', 1)
h = h.replace('                    keepWatchingSection\n', '                    keepWatchingSection\n                    myListSection\n', 1)
marker = '''    private func continueCard(_ entry: ContinueWatchingItem) -> some View {
'''
section = '''    @ViewBuilder
    private var myListSection: some View {
        if !watchlistStore.items.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("My List").font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text("Movies and shows you want to watch later").font(.caption).foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    Button("Clear") { watchlistStore.clearAll() }.font(.caption.weight(.semibold)).foregroundStyle(Color(hex: accentHex))
                }.padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 13) {
                        ForEach(watchlistStore.items) { item in
                            NavigationLink { UnifiedLibraryView(kind: item.type.lowercased() == "movie" ? .movies : .tvShows) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.08))
                                        if let raw = item.posterURL, let url = URL(string: raw) {
                                            AsyncImage(url: url) { phase in
                                                if case .success(let image) = phase { image.resizable().scaledToFill() }
                                                else { Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv").font(.system(size: 34)).foregroundStyle(.white.opacity(0.55)) }
                                            }
                                        } else { Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv").font(.system(size: 34)).foregroundStyle(.white.opacity(0.55)) }
                                        Button { watchlistStore.remove(item) } label: { Image(systemName: "bookmark.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).frame(width: 32, height: 32).background(.black.opacity(0.7), in: Circle()) }.buttonStyle(.plain).padding(8)
                                    }.frame(width: 145, height: 190).clipShape(RoundedRectangle(cornerRadius: 18))
                                    Text(item.title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1).frame(width: 145, alignment: .leading)
                                }
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20)
                }
            }
        }
    }

'''
h = h.replace(marker, section + marker, 1)
home.write_text(h, encoding="utf-8")

# Dedicated full-page catalog grid used by all shelf arrows.
grid = Path("Shinji/Views/CatalogGridPage.swift")
if not grid.exists():
    grid.write_text('''import SwiftUI

struct CatalogGridPage: View {
    let title: String
    let items: [AddonCatalogItem]
    let accentHex: String
    let glowHex: String
    let onSelect: (AddonCatalogItem) -> Void

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(items) { item in
                    Button { onSelect(item) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .bottomLeading) {
                                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.07))
                                if let url = item.posterURL {
                                    AsyncImage(url: url) { phase in
                                        if case .success(let image) = phase { image.resizable().scaledToFill() }
                                        else { placeholder(item) }
                                    }
                                } else { placeholder(item) }
                                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                                Text(item.type.lowercased() == "movie" ? "MOVIE" : "TV")
                                    .font(.system(size: 8, weight: .black)).tracking(1.2).foregroundStyle(.white.opacity(0.85)).padding(10)
                            }
                            .frame(maxWidth: .infinity).aspectRatio(0.69, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            Text(item.name).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(2)
                            Text(item.addonName).font(.system(size: 11)).foregroundStyle(.white.opacity(0.48)).lineLimit(1)
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 18).padding(.bottom, 28)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }

    private func placeholder(_ item: AddonCatalogItem) -> some View {
        LinearGradient(colors: [Color(hex: glowHex), Color(hex: accentHex).opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv").font(.system(size: 38, weight: .light)).foregroundStyle(.white.opacity(0.7)) }
    }
}
''', encoding="utf-8")

# Upgrade the older LibraryView too: its Featured/section arrows now open full pages.
legacy = Path("Shinji/Views/LibraryView.swift")
legacy_text = legacy.read_text(encoding="utf-8")
old_legacy_featured = '''                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: accentHex))
'''
new_legacy_featured = '''                Spacer()
                NavigationLink {
                    CatalogGridPage(
                        title: searchText.isEmpty ? sectionTitle : "Search results",
                        items: visibleItems.compactMap { item in addonStore.catalogItems.first(where: { $0.id == item.id && $0.addonName == item.subtitle }) },
                        accentHex: accentHex,
                        glowHex: glowHex,
                        onSelect: { selectedItem = $0 }
                    )
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: accentHex))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(visibleItems.isEmpty)
'''
legacy_text = legacy_text.replace(old_legacy_featured, new_legacy_featured, 1)
# Replace the legacy rotating shelf chevron with a full page for that shelf.
old_legacy_chevron = '''                Button {
                    let step = 3
                    let position = shelfPositions[title, default: 0]
                    let next = position + step >= items.count ? 0 : position + step
                    shelfPositions[title] = next
                } label {
'''
new_legacy_chevron = '''                NavigationLink {
                    CatalogGridPage(
                        title: title,
                        items: items,
                        accentHex: accentHex,
                        glowHex: glowHex,
                        onSelect: { selectedItem = $0 }
                    )
                } label: {
'''
legacy_text = legacy_text.replace(old_legacy_chevron, new_legacy_chevron, 1)
legacy_text = legacy_text.replace('''                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
''', '''                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
''', 1)
legacy.write_text(legacy_text, encoding="utf-8")

print("CI source repairs applied.")
