import SwiftUI

struct UnifiedLibraryView: View {
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

    private let filters = ["For You", "Popular", "Recently Added", "Action", "Drama"]
    private let genres = ["Action", "Adventure", "Animation", "Comedy", "Crime", "Documentary", "Drama", "Fantasy", "Horror", "Romance", "Sci-Fi", "Thriller"]

    private var libraryItems: [AddonCatalogItem] {
        addonStore.catalogItems.filter { item in
            ["movie", "series"].contains(item.type.lowercased())
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

    private var movieItems: [AddonCatalogItem] {
        filteredItems.filter { $0.type.lowercased() == "movie" }
    }

    private var showItems: [AddonCatalogItem] {
        filteredItems.filter { $0.type.lowercased() == "series" }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    header
                    if isSearchPresented { searchBar }
                    filterBar
                    genreBar
                    featuredSection
                    shelfSection("Recently Added Movies", items: movieItems)
                    shelfSection("Recently Added Shows", items: showItems)
                    if selectedFilter == "For You" {
                        shelfSection("More Movies & Shows", items: filteredItems)
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
                Text("Movies & TV")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Movies and shows in one place")
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
            }
            .buttonStyle(.plain)
            Button { showAddStream = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color(hex: accentHex).opacity(0.22), in: Circle())
                    .overlay(Circle().stroke(Color(hex: accentHex).opacity(0.75), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hex: accentHex))
            TextField("Search movies and shows", text: $searchText)
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
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
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 6) {
                            if filter == "For You" { Image(systemName: "line.3.horizontal.decrease") }
                            Text(filter)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selectedFilter == filter ? .white : .white.opacity(0.62))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(selectedFilter == filter ? Color(hex: accentHex) : Color.white.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var genreBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { selectedGenres.removeAll() } label: {
                    Text("All Genres")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selectedGenres.isEmpty ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(selectedGenres.isEmpty ? Color(hex: accentHex).opacity(0.85) : Color.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)

                ForEach(genres, id: \.self) { genre in
                    let selected = selectedGenres.contains(genre)
                    Button {
                        if selected { selectedGenres.remove(genre) } else { selectedGenres.insert(genre) }
                    } label: {
                        HStack(spacing: 4) {
                            if selected { Image(systemName: "checkmark") }
                            Text(genre)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selected ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected ? Color(hex: accentHex).opacity(0.85) : Color.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedFilter == "For You" ? "Featured picks" : selectedFilter)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(filteredItems.isEmpty ? "No matching titles" : "From your installed add-ons")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color(hex: accentHex))
            }
            .padding(.horizontal, 20)

            if filteredItems.isEmpty {
                Text("No movies or shows match these filters yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(Array(filteredItems.prefix(12))) { item in
                            posterCard(item, height: 190)
                        }
                    }
                    .padding(.horizontal, 20)
                }
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(items) { item in
                            posterCard(item, height: 205)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func posterCard(_ item: AddonCatalogItem, height: CGFloat) -> some View {
        Button {
            selectedItem = item
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                    if let url = item.posterURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                placeholder(for: item)
                            }
                        }
                    } else {
                        placeholder(for: item)
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .center, endPoint: .bottom)
                    Text(item.type.lowercased() == "movie" ? "MOVIE" : "TV")
                        .font(.system(size: 8, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(10)
                }
                .frame(width: 145, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))

                Text(item.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 145, alignment: .leading)
                Text(item.addonName)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                    .frame(width: 145, alignment: .leading)
            }
            .frame(width: 145, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func placeholder(for item: AddonCatalogItem) -> some View {
        LinearGradient(
            colors: [Color(hex: glowHex), Color(hex: accentHex).opacity(0.25)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var addStreamSheet: some View {
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
                .disabled(!validStreamURL)
                .opacity(validStreamURL ? 1 : 0.5)
                Spacer()
            }
            .padding(20)
            .navigationTitle("Add stream")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private func streamSheet(_ item: AddonCatalogItem) -> some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(item.name)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let description = item.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(4)
                    }
                    if addonStore.isLoadingStreams {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Finding playable sources")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    } else if addonStore.streamOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("No playable sources found", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                            Text(addonStore.streamStatus ?? "Try again or install another stream add-on.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                Task { await addonStore.loadStreams(for: item) }
                            } label: {
                                Label("Search again", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: accentHex))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(addonStore.streamOptions.enumerated()), id: \.element.id) { index, option in
                                Button {
                                    selectedStreamURL = option.url
                                    selectedItem = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showPlayer = true
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(option.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(3)
                                            Text(option.url.host ?? "Direct stream")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                        Spacer()
                                        Image(systemName: "play.fill")
                                            .foregroundStyle(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color.green.opacity(0.85), in: Circle())
                                    }
                                    .padding(14)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Play source \(index + 1)")
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Color(red: 0.055, green: 0.055, blue: 0.07).ignoresSafeArea())
            .navigationTitle("Available streams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selectedItem = nil }
                        .tint(Color(hex: accentHex))
                }
            }
            .task { await addonStore.loadStreams(for: item) }
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let status = addonStore.catalogStatus {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                    Text(status)
                }
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
        guard let url = URL(string: streamURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return false }
        return true
    }
}
