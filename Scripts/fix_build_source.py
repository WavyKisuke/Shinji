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
        }) {
            return true
        }
        let text = "\\(item.name) \\(item.description ?? "")"
        return text.localizedCaseInsensitiveContains(wanted)
    }
'''
text = text.replace(old_matches, new_matches, 1)

# Make the Featured picks arrow actually scroll the shelf to its last visible card.
if '@State private var featuredScrollID' not in text:
    text = text.replace(
        '    @State private var showAddStream = false\n',
        '    @State private var showAddStream = false\n    @State private var featuredScrollID: String?\n',
        1,
    )
old_featured_arrow = '''                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color(hex: accentHex))
'''
new_featured_arrow = '''                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        featuredScrollID = featuredItems.last?.id
                    }
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: accentHex))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(featuredItems.count < 2)
                .opacity(featuredItems.count < 2 ? 0.35 : 1)
'''
text = text.replace(old_featured_arrow, new_featured_arrow, 1)
old_featured_scroll = '''                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(featuredItems) { item in
                            posterCard(item, height: 190)
                        }
                    }
                    .padding(.horizontal, 20)
                }
'''
new_featured_scroll = '''                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 13) {
                            ForEach(featuredItems) { item in
                                posterCard(item, height: 190)
                                    .id(item.id)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .onChange(of: featuredScrollID) { _, target in
                        guard let target else { return }
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(target, anchor: .trailing)
                        }
                    }
                }
'''
text = text.replace(old_featured_scroll, new_featured_scroll, 1)

# Carry genre metadata from Stremio catalog responses into the model.
addon = Path("Shinji/Services/AddonStore.swift")
addon_text = addon.read_text(encoding="utf-8")
addon_text = addon_text.replace(
    '    let description: String?\n    let addonName: String\n',
    '    let description: String?\n    let genres: [String]\n    let addonName: String\n',
    1,
)
addon_text = addon_text.replace(
    '            let poster = (meta["poster"] as? String).flatMap(URL.init(string:))\n            return AddonCatalogItem(\n',
    '''            let poster = (meta["poster"] as? String).flatMap(URL.init(string:))
            var genres: [String] = []
            if let values = meta["genres"] as? [String] {
                genres.append(contentsOf: values)
            } else if let value = meta["genres"] as? String {
                genres.append(contentsOf: value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            }
            if let values = meta["genre"] as? [String] {
                genres.append(contentsOf: values)
            } else if let value = meta["genre"] as? String {
                genres.append(contentsOf: value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            }
            genres = Array(Set(genres.filter { !$0.isEmpty }))
            return AddonCatalogItem(
''',
    1,
)
addon_text = addon_text.replace(
    '                description: meta["description"] as? String,\n                addonName: addonName\n',
    '                description: meta["description"] as? String,\n                genres: genres,\n                addonName: addonName\n',
    1,
)
addon.write_text(addon_text, encoding="utf-8")

# Keep MPV command fixes in every CI build.
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
mpv_text = mpv_text.replace('["cycle", "audio"]', '["cycle", "aid"]')
mpv_text = mpv_text.replace('["cycle", "sub"]', '["cycle", "sid"]')
mpv.write_text(mpv_text, encoding="utf-8")

# Automatically populate Keep Watching from playback sessions.
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

# Persistent My List section.
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
                                        RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.08))
                                        if let raw = item.posterURL, let url = URL(string: raw) {
                                            AsyncImage(url: url) { phase in
                                                if case .success(let image) = phase { image.resizable().scaledToFill() }
                                                else { Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv").font(.system(size: 34)).foregroundStyle(.white.opacity(0.55)) }
                                            }
                                        } else {
                                            Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv").font(.system(size: 34)).foregroundStyle(.white.opacity(0.55))
                                        }
                                        Button { watchlistStore.remove(item) } label: {
                                            Image(systemName: "bookmark.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).frame(width: 32, height: 32).background(.black.opacity(0.7), in: Circle())
                                        }.buttonStyle(.plain).padding(8)
                                    }
                                    .frame(width: 145, height: 190).clipShape(RoundedRectangle(cornerRadius: 18))
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

print("CI source repairs applied.")
