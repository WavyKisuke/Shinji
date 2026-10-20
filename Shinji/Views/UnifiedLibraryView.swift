import SwiftUI

enum MediaLibraryKind: Equatable {
    case movies
    case tvShows
}

struct UnifiedLibraryView: View {
    let kind: MediaLibraryKind
    private let initialItem: AddonCatalogItem?

    @EnvironmentObject private var addonStore: AddonStore
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var selectedFilter = "For You"
    @State private var selectedGenres: Set<String> = []
    @State private var selectedItem: AddonCatalogItem?
    @State private var selectedStreamURL: URL?
    @State private var showPlayer = false
    @State private var streamURL = ""
    @State private var showAddStream = false
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"
    @AppStorage("shinjiGlowHex") private var glowHex = "4936FF"

    init(kind: MediaLibraryKind = .movies, initialItem: AddonCatalogItem? = nil) {
        self.kind = kind
        self.initialItem = initialItem
    }

    private let filters = ["For You", "Popular", "Recently Added", "Action", "Drama"]
    private let genres = ["Action", "Adventure", "Animation", "Comedy", "Crime", "Documentary", "Drama", "Fantasy", "Horror", "Romance", "Sci-Fi", "Thriller"]

    private var libraryItems: [AddonCatalogItem] {
        addonStore.catalogItems.filter { item in
            let type = item.type.lowercased()
            switch kind {
            case .movies:
                return type == "movie"
            case .tvShows:
                return type == "series"
            }
        }
    }

    private var filteredItems: [AddonCatalogItem] {
        var result = libraryItems
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        switch selectedFilter {
        case "Popular":
            result = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case "Recently Added":
            result = Array(result.reversed())
        case "Action", "Drama":
            result = result.filter { matches($0, genre: selectedFilter) }
        default:
            break
        }
        if !selectedGenres.isEmpty {
            result = result.filter { item in
                selectedGenres.contains { matches(item, genre: $0) }
            }
        }
        return result
    }

    private var movieItems: [AddonCatalogItem] { filteredItems.filter { $0.type.lowercased() == "movie" } }
    private var showItems: [AddonCatalogItem] { filteredItems.filter { $0.type.lowercased() == "series" } }
    private var featuredItems: [AddonCatalogItem] { Array(filteredItems.prefix(8)) }
    private var remainingItems: [AddonCatalogItem] { Array(filteredItems.dropFirst(featuredItems.count)) }
    private var recentItems: [AddonCatalogItem] { Array(remainingItems.prefix(12)) }
    private var moreItems: [AddonCatalogItem] { Array(remainingItems.dropFirst(recentItems.count).prefix(12)) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    header
                    if isSearchPresented { searchBar }
                    filterBar
                    genreBar
                    featuredSection
                    if kind == .movies {
                        shelfSection("Recently Added Movies", items: recentItems)
                        shelfSection("More Movies", items: moreItems)
                    } else {
                        shelfSection("Recently Added TV Shows", items: recentItems)
                        shelfSection("More TV Shows", items: moreItems)
                    }
                    if selectedFilter == "For You" {
                        shelfSection(kind == .movies ? "More Movies" : "More TV Shows", items: moreItems)
                    }
                    footer
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddStream) { addStreamSheet }
            .sheet(item: $selectedItem) { item in streamSheet(item) }
            .navigationDestination(isPresented: $showPlayer) {
                if let url = selectedStreamURL ?? URL(string: streamURL),
                    ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                    url.host != nil {
                    PlayerView(
                        url: url,
                        title: selectedStreamURL == nil ? "Stream" : "Selected title",
                        headers: addonStore.streamOptions.first(where: { $0.url == url })?.headers ?? [:]
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await addonStore.refreshCatalogs() }
        .onAppear {
            if selectedItem == nil, let initialItem { selectedItem = initialItem }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkle").foregroundStyle(Color.purple.opacity(0.95))
                    Text("SHINJI").font(.system(size: 13, weight: .black, design: .rounded)).tracking(3.5).foregroundStyle(.white.opacity(0.7))
                }
                Text(kind == .movies ? "Movies" : "TV Shows").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(kind == .movies ? "Movies, organized your way" : "TV shows, organized your way").font(.subheadline).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchPresented.toggle()
                    if !isSearchPresented { searchText = "" }
                }
            } label: {
                Image(systemName: isSearchPresented ? "xmark" : "magnifyingglass").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            Button { showAddStream = true } label: {
                Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white).frame(width: 46, height: 46).background(Color(hex: accentHex).opacity(0.22), in: Circle()).overlay(Circle().stroke(Color(hex: accentHex).opacity(0.75), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private var searchBar: some View {
        TextField("Search titles…", text: $searchText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .frame(height: 46)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(filters, id: \.self) { filter in
                    Button { selectedFilter = filter } label: {
                        Text(filter).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(selectedFilter == filter ? .black : .white.opacity(0.72)).padding(.horizontal, 14).frame(height: 36).background(selectedFilter == filter ? Color(hex: accentHex) : Color.white.opacity(0.08), in: Capsule())
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 20)
        }
    }

    private var genreBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(genres, id: \.self) { genre in
                    let selected = selectedGenres.contains(genre)
                    Button {
                        if selected { selectedGenres.remove(genre) } else { selectedGenres.insert(genre) }
                    } label: {
                        HStack(spacing: 5) { if selected { Image(systemName: "checkmark") }; Text(genre) }
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(selected ? .white : .white.opacity(0.65))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(selected ? Color(hex: accentHex).opacity(0.35) : Color.white.opacity(0.06), in: Capsule())
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var featuredSection: some View {
        if !featuredItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedFilter == "For You" ? "Featured Picks" : selectedFilter).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    NavigationLink {
                        CatalogGridPage(title: selectedFilter == "For You" ? (kind == .movies ? "Featured Movies" : "Featured TV Shows") : selectedFilter, items: filteredItems, accentHex: accentHex, glowHex: glowHex, onSelect: { selectedItem = $0 })
                    } label: {
                        Image(systemName: "arrow.right").font(.system(size: 17, weight: .bold)).foregroundStyle(Color(hex: accentHex)).frame(width: 40, height: 40).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 13) {
                        ForEach(featuredItems) { item in
                            NavigationLink { UnifiedLibraryView(kind: item.type.lowercased() == "movie" ? .movies : .tvShows, initialItem: item) } label: { posterCard(item) }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20)
                }
            }
        }
    }

    @ViewBuilder
    private func shelfSection(_ title: String, items: [AddonCatalogItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    NavigationLink { CatalogGridPage(title: title, items: items, accentHex: accentHex, glowHex: glowHex, onSelect: { selectedItem = $0 }) } label: {
                        Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: accentHex)).frame(width: 40, height: 40).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(items) { item in
                            NavigationLink { UnifiedLibraryView(kind: item.type.lowercased() == "movie" ? .movies : .tvShows, initialItem: item) } label: { posterCard(item) }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20)
                }
            }
        }
    }

    private func posterCard(_ item: AddonCatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Color.white.opacity(0.07))
                if let url = item.posterURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase { image.resizable().scaledToFill() } else { placeholder(for: item) }
                    }
                } else { placeholder(for: item) }
            }
            .frame(width: 145, height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            Text(item.name).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1).frame(width: 145, alignment: .leading)
            Text(item.year ?? "").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.5)).frame(width: 145, alignment: .leading)
        }.frame(width: 145, alignment: .leading)
    }

    private func placeholder(for item: AddonCatalogItem) -> some View {
        LinearGradient(colors: [Color(hex: glowHex), Color(hex: accentHex).opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv").font(.system(size: 36, weight: .light)).foregroundStyle(.white.opacity(0.7)) }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let status = addonStore.catalogStatus {
                HStack(alignment: .top, spacing: 8) { Image(systemName: "info.circle"); Text(status) }
            }
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.38))
        .padding(.horizontal, 20)
    }

    private func matches(_ item: AddonCatalogItem, genre: String) -> Bool {
        let text = "\(item.name) \(item.description ?? "")"
        return text.localizedCaseInsensitiveContains(genre)
    }

    private var validStreamURL: Bool {
        guard let url = URL(string: streamURL), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else { return false }
        return true
    }
}
