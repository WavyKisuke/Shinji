import SwiftUI

enum LibraryKind: String {
    case movies = "Movies"
    case shows = "Shows"
    case live = "Live TV"

    var subtitle: String {
        switch self {
        case .movies: return "Discover your next favorite"
        case .shows: return "Stories worth staying in for"
        case .live: return "Live channels, all in one place"
        }
    }

    var symbol: String {
        switch self {
        case .movies: return "film"
        case .shows: return "tv"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }

    var featuredTitle: String {
        switch self {
        case .movies: return "A universe of stories"
        case .shows: return "Your next obsession"
        case .live: return "Happening right now"
        }
    }

    var featuredDescription: String {
        switch self {
        case .movies: return "Bring your movie sources together in one cinematic library."
        case .shows: return "Pick up where you left off and find your next series."
        case .live: return "Your live TV sources, ready when you are."
        }
    }
}

private struct ShowcaseItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [Color]
    var posterURL: URL? = nil
}

struct LibraryView: View {
    let kind: LibraryKind
    @EnvironmentObject private var addonStore: AddonStore
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var streamURL = ""
    @State private var showPlayer = false
    @State private var showAddStream = false
    @State private var selectedItem: AddonCatalogItem?
    @State private var selectedStreamURL: URL?
    @State private var selectedFilter = "For You"
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"
    @AppStorage("shinjiGlowHex") private var glowHex = "4936FF"

    private let filters = ["For You", "Popular", "Recently Added", "Action", "Drama"]

    private var items: [ShowcaseItem] {
        let realItems = addonStore.catalogItems.filter { item in
            switch kind {
            case .movies: return item.type == "movie"
            case .shows: return item.type == "series"
            case .live: return ["channel", "tv", "live"].contains(item.type.lowercased())
            }
        }.map { item in
            ShowcaseItem(
                id: item.id,
                title: item.name,
                subtitle: item.addonName,
                symbol: kind.symbol,
                colors: [Color(hex: glowHex), Color(hex: accentHex).opacity(0.55)],
                posterURL: item.posterURL
            )
        }
        if !realItems.isEmpty { return realItems }
        switch kind {
        case .movies:
            return [
                ShowcaseItem(id: "night", title: "After the Dark", subtitle: "Sci-Fi • 2h 08m", symbol: "moon.stars.fill", colors: [Color(red: 0.27, green: 0.08, blue: 0.52), .black]),
                ShowcaseItem(id: "orbit", title: "Beyond Orbit", subtitle: "Adventure • 1h 54m", symbol: "sparkles", colors: [Color(red: 0.04, green: 0.38, blue: 0.55), Color(red: 0.15, green: 0.05, blue: 0.35)]),
                ShowcaseItem(id: "ember", title: "Ember City", subtitle: "Thriller • 1h 47m", symbol: "flame.fill", colors: [Color(red: 0.7, green: 0.16, blue: 0.22), Color(red: 0.17, green: 0.03, blue: 0.13)])
            ]
        case .shows:
            return [
                ShowcaseItem(id: "signal", title: "The Signal", subtitle: "Season 1 • 8 episodes", symbol: "waveform.path", colors: [Color(red: 0.12, green: 0.22, blue: 0.55), Color(red: 0.24, green: 0.04, blue: 0.34)]),
                ShowcaseItem(id: "echo", title: "Echoes", subtitle: "Season 2 • 10 episodes", symbol: "sparkles", colors: [Color(red: 0.48, green: 0.12, blue: 0.42), Color(red: 0.08, green: 0.04, blue: 0.23)]),
                ShowcaseItem(id: "wild", title: "Wild Frontier", subtitle: "Season 1 • 6 episodes", symbol: "mountain.2.fill", colors: [Color(red: 0.08, green: 0.38, blue: 0.34), Color(red: 0.03, green: 0.08, blue: 0.18)])
            ]
        case .live:
            return [
                ShowcaseItem(id: "world", title: "World News", subtitle: "Live • News", symbol: "globe.americas.fill", colors: [Color(red: 0.05, green: 0.35, blue: 0.62), Color(red: 0.08, green: 0.06, blue: 0.22)]),
                ShowcaseItem(id: "arena", title: "The Arena", subtitle: "Live • Sports", symbol: "sportscourt.fill", colors: [Color(red: 0.62, green: 0.18, blue: 0.22), Color(red: 0.18, green: 0.03, blue: 0.18)]),
                ShowcaseItem(id: "chill", title: "Chill Radio", subtitle: "Live • Music", symbol: "headphones", colors: [Color(red: 0.37, green: 0.13, blue: 0.62), Color(red: 0.05, green: 0.09, blue: 0.26)])
            ]
        }
    }

    private var visibleItems: [ShowcaseItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.subtitle.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    if isSearchPresented {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color(hex: accentHex))
                            TextField("Search movies, shows, or channels", text: $searchText)
                                .font(.system(size: 15))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 13)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: accentHex).opacity(0.45), lineWidth: 1))
                        .padding(.horizontal, 18)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    filterBar
                    contentSection
                    catalogShelves
                    streamURLSection
                    footerNote
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddStream) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Add stream URL", systemImage: "play.rectangle.on.rectangle")
                            .font(.title2.bold())
                        Text("Paste a direct video stream URL from a source you’re authorized to access.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("https://example.org/video.m3u8", text: $streamURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        Button {
                            showAddStream = false
                            selectedStreamURL = nil
                            showPlayer = true
                        } label: {
                            Label("Open Player", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: accentHex), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        .disabled(!isValidStreamURL)
                        .opacity(isValidStreamURL ? 1 : 0.5)
                        Spacer()
                    }
                    .padding(20)
                    .navigationTitle("Add stream")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Cancel") { showAddStream = false }
                        }
                    }
                }
                .preferredColorScheme(.dark)
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedItem) { item in
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(item.name).font(.title2.bold())
                        if let description = item.description, !description.isEmpty {
                            Text(description).font(.subheadline).foregroundStyle(.secondary)
                        }
                        if addonStore.isLoadingStreams {
                            ProgressView("Checking source…")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if addonStore.streamOptions.isEmpty {
                            if let status = addonStore.streamStatus {
                                Text(status)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                Task { await addonStore.loadStreams(for: item) }
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            ForEach(addonStore.streamOptions) { option in
                                Button {
                                    selectedStreamURL = option.url
                                    selectedItem = nil
                                    showPlayer = true
                                } label: {
                                    Label(option.title, systemImage: "play.circle.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Available streams")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selectedItem = nil }
                        }
                    }
                    .task { await addonStore.loadStreams(for: item) }
                }
                .preferredColorScheme(.dark)
            }
            .navigationDestination(isPresented: $showPlayer) {
                if let url = selectedStreamURL ?? URL(string: streamURL),
                   ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                   url.host != nil {
                    PlayerView(url: url, title: selectedStreamURL == nil ? "Stream" : "Selected title")
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Invalid URL").font(.headline)
                        Text("Enter a valid HTTP or HTTPS stream URL and try again.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await addonStore.refreshCatalogs() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkle")
                        .foregroundStyle(Color.purple.opacity(0.95))
                    Text("SHINJI")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(3.5)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(kind.rawValue)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(kind.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchPresented.toggle()
                    if !isSearchPresented { searchText = "" }
                }
            } label: {
                Image(systemName: isSearchPresented ? "xmark" : "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSearchPresented ? "Close search" : "Search titles")
            Button {
                showAddStream = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color(hex: accentHex).opacity(0.22), in: Circle())
                    .overlay(Circle().stroke(Color(hex: accentHex).opacity(0.75), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add stream URL")
        }
        .padding(.horizontal, 20)
    }

    private var featuredBanner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: glowHex).opacity(0.95), Color(hex: accentHex).opacity(0.24), Color.black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(Color(hex: accentHex).opacity(0.32))
                .frame(width: 190, height: 190)
                .blur(radius: 45)
                .offset(x: 170, y: -70)
            Circle()
                .fill(Color(hex: glowHex).opacity(0.22))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .offset(x: 225, y: 20)
            Image(systemName: kind == .live ? "dot.radiowaves.left.and.right" : "sparkles.tv")
                .font(.system(size: 92, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.15))
                .rotationEffect(.degrees(-12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(26)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle().fill(Color.cyan).frame(width: 6, height: 6)
                    Text(kind == .live ? "YOUR LIVE HUB" : "YOUR NEXT WATCH")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text(kind.featuredTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(kind.featuredDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Label("Explore", systemImage: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 11)
                        .background(.white, in: Capsule())
                    Text("MIDNIGHT COLLECTION")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.top, 3)
            }
            .padding(22)
        }
        .frame(height: 255)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color(hex: accentHex).opacity(0.55), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedFilter = filter }
                    } label: {
                        Text(filter)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(selectedFilter == filter ? .white : .white.opacity(0.58))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background {
                                Capsule().fill(selectedFilter == filter
                                    ? LinearGradient(colors: [Color(hex: accentHex), Color(hex: glowHex)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
                            }
                            .overlay(Capsule().stroke(selectedFilter == filter ? Color(hex: accentHex).opacity(0.8) : Color.white.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(searchText.isEmpty ? sectionTitle : "Search results")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(searchText.isEmpty ? (addonStore.catalogItems.isEmpty ? "Hand-picked for your midnight mood" : "From your installed add-ons") : "Matching titles")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: accentHex))
            }
            .padding(.horizontal, 20)

            if visibleItems.isEmpty {
                Text("No matching titles yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(visibleItems) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomLeading) {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    if let posterURL = item.posterURL {
                                        AsyncImage(url: posterURL) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                                .overlay(Image(systemName: item.symbol).font(.system(size: 38, weight: .light)).foregroundStyle(.white.opacity(0.7)))
                                        }
                                        .frame(width: 145, height: 190)
                                        .clipped()
                                    } else {
                                        Circle()
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 95, height: 95)
                                            .blur(radius: 15)
                                            .offset(x: 45, y: -35)
                                        Image(systemName: item.symbol)
                                            .font(.system(size: 38, weight: .light))
                                            .foregroundStyle(.white.opacity(0.88))
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                    LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    Text("SHINJI SELECT")
                                        .font(.system(size: 8, weight: .black))
                                        .tracking(1.2)
                                        .foregroundStyle(.white.opacity(0.72))
                                        .padding(11)
                                }
                                .frame(width: 145, height: 190)
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(item.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .lineLimit(1)
                            }
                            .frame(width: 145, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard let catalogItem = addonStore.catalogItems.first(where: { $0.id == item.id && $0.addonName == item.subtitle }) else { return }
                                selectedItem = catalogItem
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    private func catalogCard(_ item: ShowcaseItem) -> some View {
        Button {
            guard let catalogItem = addonStore.catalogItems.first(where: {
                $0.id == item.id && $0.addonName == item.subtitle
            }) else { return }
            selectedItem = catalogItem
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    if let posterURL = item.posterURL {
                        AsyncImage(url: posterURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                        .frame(width: 145, height: 190)
                        .clipped()
                    } else {
                        Image(systemName: item.symbol)
                            .font(.system(size: 38, weight: .light))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Text("SHINJI SELECT")
                        .font(.system(size: 8, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(11)
                }
                .frame(width: 145, height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(width: 145, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var catalogShelves: some View {
        VStack(alignment: .leading, spacing: 26) {
            if kind == .movies {
                shelfSection("Recently Added Movies", items: Array(addonStore.catalogItems.filter { $0.type == "movie" }.reversed()))
                shelfSection("Recently Added Shows", items: Array(addonStore.catalogItems.filter { $0.type == "series" }.reversed()))
                shelfSection("More Movies", items: Array(addonStore.catalogItems.filter { $0.type == "movie" }.prefix(12)))
            } else if kind == .shows {
                shelfSection("Recently Added Shows", items: Array(addonStore.catalogItems.filter { $0.type == "series" }.reversed()))
                shelfSection("More Shows", items: Array(addonStore.catalogItems.filter { $0.type == "series" }.prefix(12)))
            } else {
                shelfSection("Live Channels", items: addonStore.catalogItems.filter { ["channel", "tv", "live"].contains($0.type.lowercased()) })
            }
        }
    }

    @ViewBuilder
    private func shelfSection(_ title: String, items: [AddonCatalogItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(Array(items.prefix(18).enumerated()), id: \.offset) { _, item in
                            Button {
                                selectedItem = item
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Group {
                                        if let posterURL = item.posterURL {
                                            AsyncImage(url: posterURL) { image in
                                                image.resizable().scaledToFill()
                                            } placeholder: {
                                                posterPlaceholder(for: item)
                                            }
                                        } else {
                                            posterPlaceholder(for: item)
                                        }
                                    }
                                    .frame(width: 132, height: 190)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))

                                    Text(item.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(item.addonName)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.48))
                                        .lineLimit(1)
                                }
                                .frame(width: 132, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    private func posterPlaceholder(for item: AddonCatalogItem) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: glowHex).opacity(0.8), Color(hex: accentHex).opacity(0.25), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: item.type == "series" ? "tv" : (item.type == "movie" ? "film" : "dot.radiowaves.left.and.right"))
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var streamURLSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.on.rectangle")
                    .foregroundStyle(Color(hex: accentHex))
                Text("Play from a URL")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Text("Open a direct stream from a source you’re authorized to access.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            TextField("https://example.org/video.m3u8", text: $streamURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(13)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color(hex: accentHex).opacity(0.25), lineWidth: 1))
            Button {
                showPlayer = true
            } label: {
                Label("Open Player", systemImage: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [Color(hex: accentHex), Color(hex: glowHex)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!isValidStreamURL)
            .opacity(isValidStreamURL ? 1 : 0.5)
        }
        .padding(17)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let status = addonStore.catalogStatus {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                    Text(status)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                Text("Preview artwork is illustrative when no compatible catalog titles are available.")
            }
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.38))
        .padding(.horizontal, 20)
    }

    private var sectionTitle: String {
        switch kind {
        case .movies: return "Featured picks"
        case .shows: return "Binge-worthy stories"
        case .live: return "Explore channels"
        }
    }

    private var isValidStreamURL: Bool {
        guard let url = URL(string: streamURL),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              url.host != nil else { return false }
        return true
    }
}
