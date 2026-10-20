import SwiftUI

struct HomeLibraryView: View {
    @EnvironmentObject private var addonStore: AddonStore
    @StateObject private var continueStore = ContinueWatchingStore.shared
    @State private var selectedEntry: ContinueWatchingItem?
    @State private var showPlayer = false
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"
    @AppStorage("shinjiGlowHex") private var glowHex = "4936FF"

    private var movies: [AddonCatalogItem] { addonStore.catalogItems.filter { $0.type.lowercased() == "movie" } }
    private var series: [AddonCatalogItem] { addonStore.catalogItems.filter { $0.type.lowercased() == "series" } }
    private var popularMovies: [AddonCatalogItem] { Array(movies.prefix(12)) }
    private var popularSeries: [AddonCatalogItem] { Array(series.prefix(12)) }
    private var featuredMovies: [AddonCatalogItem] { Array(movies.dropFirst(min(12, movies.count)).prefix(12)) }
    private var featuredSeries: [AddonCatalogItem] { Array(series.dropFirst(min(12, series.count)).prefix(12)) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    keepWatchingSection
                    catalogSection(title: "Popular - Movies", items: popularMovies)
                    catalogSection(title: "Popular - Series", items: popularSeries)
                    catalogSection(title: "Featured - Movies", items: featuredMovies.isEmpty ? popularMovies : featuredMovies)
                    catalogSection(title: "Featured - Series", items: featuredSeries.isEmpty ? popularSeries : featuredSeries)
                }
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showPlayer) {
                if let entry = selectedEntry, let url = URL(string: entry.url) {
                    PlayerView(url: url, title: entry.title, headers: entry.headers, posterURL: entry.posterURL.flatMap(URL.init(string:)))
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await addonStore.refreshCatalogs() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkle").foregroundStyle(Color(hex: accentHex))
                    Text("SHINJI").font(.system(size: 12, weight: .black, design: .rounded)).tracking(3.2).foregroundStyle(.white.opacity(0.72))
                }
                Text("Home").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08), in: Circle())
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var keepWatchingSection: some View {
        if !continueStore.items.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                sectionHeader("Keep Watching", subtitle: "Continue where you left off", items: continueStore.items.count)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 13) { ForEach(continueStore.items) { entry in continueCard(entry) } }
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    @ViewBuilder
    private func catalogSection(title: String, items: [AddonCatalogItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text(title).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    NavigationLink {
                        CatalogGridPage(title: title, items: items, accentHex: accentHex, glowHex: glowHex, onSelect: { _ in })
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.07), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(items) { item in
                            NavigationLink {
                                UnifiedLibraryView(kind: item.type.lowercased() == "movie" ? .movies : .tvShows, initialItem: item)
                            } label: { catalogCard(item) }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, subtitle: String, items: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.48))
            }
            Spacer()
            Text("\(items)").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 20)
    }

    private func catalogCard(_ item: AddonCatalogItem) -> some View {
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
        }
        .frame(width: 145, alignment: .leading)
    }

    private func placeholder(for item: AddonCatalogItem) -> some View {
        LinearGradient(colors: [Color(hex: glowHex), Color(hex: accentHex).opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv").font(.system(size: 36, weight: .light)).foregroundStyle(.white.opacity(0.7)) }
    }

    private func continueCard(_ entry: ContinueWatchingItem) -> some View {
        let progress = entry.duration > 0 ? min(max(entry.position / entry.duration, 0), 1) : 0
        return Button {
            selectedEntry = entry
            showPlayer = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 17).fill(Color.white.opacity(0.08))
                    if let rawPoster = entry.posterURL, let poster = URL(string: rawPoster) {
                        AsyncImage(url: poster) { phase in
                            if case .success(let image) = phase { image.resizable().scaledToFill() }
                            else { Image(systemName: "play.rectangle.fill").font(.system(size: 34)).foregroundStyle(.white.opacity(0.55)) }
                        }
                    } else { Image(systemName: "play.rectangle.fill").font(.system(size: 34)).foregroundStyle(.white.opacity(0.55)) }
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                    GeometryReader { geo in VStack { Spacer(); Color(hex: accentHex).frame(width: geo.size.width * progress, height: 3) } }
                }
                .frame(width: 145, height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 17))
                Text(entry.title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1).frame(width: 145, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}
