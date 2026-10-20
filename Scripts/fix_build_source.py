from pathlib import Path


# CI source repair for known generated/escaped Swift fragments. Keep this
# idempotent so repeated builds always converge to compilable source.

unified = Path("Shinji/Views/UnifiedLibraryView.swift")
text = unified.read_text(encoding="utf-8")

text = text.replace(
    '        let text = "\\(item.name) \\(item.description ?? \\\"\\\")"',
    '        let text = item.name + " " + (item.description ?? "")',
)

# Keep the top filter row focused on content filters. Genre selection lives
# exclusively in the dedicated multi-select genre row below it.
text = text.replace(
    '    private let filters = ["For You", "Popular", "Recently Added", "Action", "Drama"]',
    '    private let filters = ["For You", "Popular", "Recently Added"]',
)

# The "For You" branch used to render the same More shelf a second time.
duplicate_more = '''                    if selectedFilter == "For You" {
                        shelfSection(kind == .movies ? "More Movies" : "More TV Shows", items: moreItems)
                    }
'''
text = text.replace(duplicate_more, "", 1)

# Add persistent My List bookmarks to catalog cards and title details.
if '@StateObject private var watchlistStore = WatchlistStore.shared' not in text:
    text = text.replace(
        '    @EnvironmentObject private var addonStore: AddonStore\n',
        '    @EnvironmentObject private var addonStore: AddonStore\n    @StateObject private var watchlistStore = WatchlistStore.shared\n',
        1,
    )

poster_anchor = '''                    LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .center, endPoint: .bottom)
                    Text(item.type.lowercased() == "movie" ? "MOVIE" : "TV")
'''
poster_replacement = '''                    LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .center, endPoint: .bottom)
                    Button {
                        watchlistStore.toggle(item)
                    } label: {
                        Image(systemName: watchlistStore.contains(catalogID: item.id, addonName: item.addonName) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.65), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    Text(item.type.lowercased() == "movie" ? "MOVIE" : "TV")
'''
text = text.replace(poster_anchor, poster_replacement, 1)

stream_title_anchor = '''                    Text(item.name)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let description = item.description, !description.isEmpty {
'''
stream_title_replacement = '''                    HStack(alignment: .top, spacing: 12) {
                        Text(item.name)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            watchlistStore.toggle(item)
                        } label: {
                            Image(systemName: watchlistStore.contains(catalogID: item.id, addonName: item.addonName) ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(Color(hex: accentHex).opacity(0.8), in: Circle())
                        }
                    }
                    Text(watchlistStore.contains(catalogID: item.id, addonName: item.addonName) ? "Saved to My List — watch it later." : "Save this title to My List so you can watch it later.")
                        .font(.caption)
                        .foregroundStyle(Color(hex: accentHex))
                    if let description = item.description, !description.isEmpty {
'''
text = text.replace(stream_title_anchor, stream_title_replacement, 1)
unified.write_text(text, encoding="utf-8")

# Keep the MPV command buffer ABI fix in every CI build.
mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
mpv_text = mpv.read_text(encoding="utf-8")
old_execute = '''    private func execute(_ arguments: [String], on handle: OpaquePointer) {
        var cargs: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
        cargs.append(nil)
        defer {
            for pointer in cargs where pointer != nil {
                free(pointer)
            }
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
        defer {
            for pointer in owned {
                free(pointer)
            }
        }

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
if old_execute in mpv_text:
    mpv_text = mpv_text.replace(old_execute, new_execute, 1)

# Use MPV's canonical track-selection properties.
mpv_text = mpv_text.replace('["cycle", "audio"]', '["cycle", "aid"]')
mpv_text = mpv_text.replace('["cycle", "sub"]', '["cycle", "sid"]')
mpv.write_text(mpv_text, encoding="utf-8")

# Automatically populate Keep Watching from every MPV playback session.
player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")
p = p.replace(
    '    var headers: [String: String] = [:]\n',
    '    var headers: [String: String] = [:]\n    @StateObject private var continueStore = ContinueWatchingStore.shared\n',
    1,
)
p = p.replace(
    '    @State private var showSettings = false\n',
    '    @State private var showSettings = false\n    @State private var didResume = false\n    @State private var lastProgressSave = Date.distantPast\n',
    1,
)
p = p.replace(
    '''                if status.localizedCaseInsensitiveContains("loaded") {
                    isPreparingPlayback = false
                }''',
    '''                if status.localizedCaseInsensitiveContains("loaded") {
                    isPreparingPlayback = false
                    if !didResume, let saved = continueStore.item(for: url.absoluteString), saved.position > 5 {
                        didResume = true
                        position = saved.position
                        ignorePositionUpdatesUntil = Date().addingTimeInterval(1.0)
                        sendCommand(["seek", String(saved.position), "absolute"])
                    } else if !didResume {
                        didResume = true
                    }
                }''',
    1,
)
p = p.replace(
    '''                duration = total
                isPlaying = !paused
                if total > 0 { isPreparingPlayback = false }''',
    '''                duration = total
                isPlaying = !paused
                if total > 0 {
                    if Date().timeIntervalSince(lastProgressSave) >= 2 {
                        lastProgressSave = Date()
                        continueStore.record(id: url.absoluteString, title: title, url: url, position: time, duration: total, headers: headers)
                    }
                    isPreparingPlayback = false
                }''',
    1,
)
p = p.replace(
    '''        .onDisappear {
            hideControlsTask?.cancel()''',
    '''        .onDisappear {
            if duration > 0 {
                continueStore.record(id: url.absoluteString, title: title, url: url, position: position, duration: duration, headers: headers)
            }
            hideControlsTask?.cancel()''',
    1,
)
p = p.replace(
    '''        isScrubbing = false
        if reloadStream {''',
    '''        isScrubbing = false
        didResume = false
        lastProgressSave = Date.distantPast
        if reloadStream {''',
    1,
)
player.write_text(p, encoding="utf-8")

# Add a persistent My List section to the Library home screen. Saved catalog
# titles can be opened in their matching movie/TV library and removed here.
home = Path("Shinji/Views/HomeLibraryView.swift")
h = home.read_text(encoding="utf-8")
h = h.replace(
    '    @StateObject private var continueStore = ContinueWatchingStore.shared\n',
    '    @StateObject private var continueStore = ContinueWatchingStore.shared\n    @StateObject private var watchlistStore = WatchlistStore.shared\n',
    1,
)
h = h.replace(
    '                    keepWatchingSection\n',
    '                    keepWatchingSection\n                    myListSection\n',
    1,
)
marker = '''    private func continueCard(_ entry: ContinueWatchingItem) -> some View {
'''
section = '''    @ViewBuilder
    private var myListSection: some View {
        if !watchlistStore.items.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("My List")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Movies and shows you want to watch later")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    Button("Clear") { watchlistStore.clearAll() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: accentHex))
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 13) {
                        ForEach(watchlistStore.items) { item in
                            NavigationLink {
                                UnifiedLibraryView(kind: item.type.lowercased() == "movie" ? .movies : .tvShows)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(Color.white.opacity(0.08))
                                        if let raw = item.posterURL, let url = URL(string: raw) {
                                            AsyncImage(url: url) { phase in
                                                if case .success(let image) = phase { image.resizable().scaledToFill() }
                                                else { Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv").font(.system(size: 34)).foregroundStyle(.white.opacity(0.55)) }
                                            }
                                        } else {
                                            Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv").font(.system(size: 34)).foregroundStyle(.white.opacity(0.55))
                                        }
                                        Button {
                                            watchlistStore.remove(item)
                                        } label: {
                                            Image(systemName: "bookmark.fill")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 32, height: 32)
                                                .background(.black.opacity(0.7), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .padding(8)
                                    }
                                    .frame(width: 145, height: 190)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .frame(width: 145, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

'''
h = h.replace(marker, section + marker, 1)
home.write_text(h, encoding="utf-8")

print("CI source repairs applied.")
