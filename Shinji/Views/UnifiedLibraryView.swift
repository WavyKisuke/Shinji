import SwiftUI

enum MediaLibraryKind: Equatable {
    case all
    case movies
    case tvShows
}

struct UnifiedLibraryView: View {
    let kind: MediaLibraryKind
    @StateObject private var watchlistStore = WatchlistStore.shared
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"

    private var savedItems: [WatchlistItem] {
        watchlistStore.items.filter { item in
            let type = item.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch kind {
            case .all:
                return type == "movie" || ["series", "tv", "tvshow", "tv shows", "show"].contains(type)
            case .movies:
                return type == "movie"
            case .tvShows:
                return ["series", "tv", "tvshow", "tv shows", "show"].contains(type)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if savedItems.isEmpty { emptyState } else { itemGrid }
                }
                .padding(.top, 10)
                .padding(.horizontal, 18)
                .padding(.bottom, 120)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Library")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var subtitle: String {
        switch kind {
        case .all: return "Movies and shows you picked or favorited"
        case .movies: return "Movies you picked or favorited"
        case .tvShows: return "Shows you picked or favorited"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color(hex: accentHex).opacity(0.12)).frame(width: 74, height: 74)
                Image(systemName: kind == .tvShows ? "tv" : "film.stack")
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(Color(hex: accentHex))
            }
            VStack(spacing: 7) {
                Text(kind == .all ? "Your library is empty" : kind == .movies ? "No movies saved" : "No shows saved")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Open a movie or show and tap Add to Library. It will appear here immediately.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.52))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 54)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1) }
    }

    private var itemGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 18) {
            ForEach(savedItems) { item in savedItemCard(item) }
        }
    }

    private func savedItemCard(_ item: WatchlistItem) -> some View {
        NavigationLink {
            SavedLibraryItemView(item: item)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .aspectRatio(0.67, contentMode: .fit)
                    if let string = item.posterURL, let url = URL(string: string) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase { image.resizable().scaledToFill() } else { posterPlaceholder }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        posterPlaceholder.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .padding(8).background(.black.opacity(0.62), in: Circle()).padding(7)
                }
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { watchlistStore.remove(item) } label: {
                Label("Remove from Library", systemImage: "trash")
            }
        }
    }

    private var posterPlaceholder: some View {
        Rectangle().fill(Color.white.opacity(0.06)).overlay {
            Image(systemName: kind == .tvShows ? "tv" : "film")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

private struct SavedLibraryItemView: View {
    let item: WatchlistItem
    @StateObject private var watchlistStore = WatchlistStore.shared
    @EnvironmentObject private var addonStore: AddonStore
    @State private var selectedStream: AddonStreamOption?
    @State private var showPlayer = false
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let raw = item.posterURL, let url = URL(string: raw) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase { image.resizable().scaledToFill() } else { Color.white.opacity(0.08) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 430).clipShape(RoundedRectangle(cornerRadius: 22))
                }
                Text(item.title).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
                if let description = item.description, !description.isEmpty { Text(description).foregroundStyle(.white.opacity(0.72)) }
                HStack(spacing: 12) {
                    Button { watchlistStore.remove(item) } label: {
                        Label("Remove", systemImage: "bookmark.slash").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered)
                    Button { Task { await play() } } label: {
                        Label(loading ? "Finding…" : "Play", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).disabled(loading)
                }
            }.padding(20)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showPlayer) {
            if let stream = selectedStream {
                PlayerView(url: stream.url, title: item.title, headers: stream.headers)
            }
        }
    }

    private func play() async {
        loading = true
        let catalog = AddonCatalogItem(id: item.catalogID, type: item.type, name: item.title, posterURL: item.posterURL.flatMap(URL.init(string:)), description: item.description, year: nil, genres: [], addonName: item.addonName)
        await addonStore.loadStreams(for: catalog)
        selectedStream = addonStore.streamOptions.first
        showPlayer = selectedStream != nil
        loading = false
    }
}
