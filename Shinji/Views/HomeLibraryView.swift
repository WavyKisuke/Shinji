import SwiftUI

struct HomeLibraryView: View {
    @EnvironmentObject private var addonStore: AddonStore
    @StateObject private var continueStore = ContinueWatchingStore.shared // keep Home focused on playback history
    @State private var selectedEntry: ContinueWatchingItem?
    @State private var showPlayer = false
    @State private var heroIndex = 0
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"
    @AppStorage("shinjiGlowHex") private var glowHex = "4936FF"

    private var movies: [AddonCatalogItem] { unique(addonStore.catalogItems.filter { $0.type.lowercased() == "movie" }) }
    private var series: [AddonCatalogItem] { unique(addonStore.catalogItems.filter { $0.type.lowercased() == "series" }) }
    private var popularMovies: [AddonCatalogItem] { Array(movies.prefix(12)) }
    private var popularSeries: [AddonCatalogItem] { Array(series.prefix(12)) }
    private var featuredMovies: [AddonCatalogItem] { Array(movies.dropFirst(min(12, movies.count)).prefix(12)) }
    private var featuredSeries: [AddonCatalogItem] { Array(series.dropFirst(min(12, series.count)).prefix(12)) }
    private var heroItems: [AddonCatalogItem] { Array((movies + series).prefix(6)) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 34) {
                    heroSection
                    keepWatchingSection // keep Home focused on playback history
                    catalogSection(title: "Popular - Movies", items: popularMovies)
                    catalogSection(title: "Popular - Series", items: popularSeries)
                    catalogSection(title: "Featured - Movies", items: featuredMovies)
                    catalogSection(title: "Featured - Series", items: featuredSeries)
                }
                .padding(.bottom, 105)
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

    @ViewBuilder
    private var heroSection: some View {
        if !heroItems.isEmpty {
            TabView(selection: $heroIndex) {
                ForEach(Array(heroItems.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        CatalogItemDetailView(item: item)
                    } label: {
                        heroCard(item)
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 365)
            .overlay(alignment: .bottom) {
                HStack(spacing: 7) {
                    ForEach(0..<heroItems.count, id: \.self) { index in
                        Capsule().fill(index == heroIndex ? Color.white : Color.white.opacity(0.72))
                            .frame(width: index == heroIndex ? 52 : 8, height: 6)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    private func heroCard(_ item: AddonCatalogItem) -> some View {
        ZStack(alignment: .bottom) {
            Color.black
            if let url = item.posterURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase { image.resizable().scaledToFill() }
                    else { heroPlaceholder(item) }
                }
            } else { heroPlaceholder(item) }
            LinearGradient(stops: [
                .init(color: .clear, location: 0.20),
                .init(color: .black.opacity(0.25), location: 0.48),
                .init(color: .black.opacity(0.94), location: 1)
            ], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.72)], startPoint: .leading, endPoint: .trailing)
            VStack(spacing: 12) {
                Text("\(item.type.capitalized)  •  \(item.year ?? "")")
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("View Details")
                    .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.black)
                    .padding(.horizontal, 35).frame(height: 48).background(.white, in: Capsule())
            }
            .padding(.bottom, 34)
        }
        .clipped()
    }

    private func heroPlaceholder(_ item: AddonCatalogItem) -> some View {
        LinearGradient(colors: [Color(hex: glowHex), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { Text(item.name).font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).padding() }
    }

    @ViewBuilder
    private var keepWatchingSection: some View {
        if !continueStore.items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Continue Watching", showArrow: false)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) { ForEach(continueStore.items) { entry in continueCard(entry) } }
                        .padding(.horizontal, 26)
                }
            }
        }
    }

    @ViewBuilder
    private func catalogSection(title: String, items: [AddonCatalogItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                sectionTitle(title, showArrow: true, destinationItems: items)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(items) { item in
                            NavigationLink {
                                CatalogItemDetailView(item: item)
                            } label: {
                                catalogCard(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 26)
                }
            }
        }
    }

    private func sectionTitle(_ title: String, showArrow: Bool, destinationItems: [AddonCatalogItem] = []) -> some View {
        HStack {
            Text(title).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Spacer()
            if showArrow {
                NavigationLink {
                    CatalogGridPage(title: title, items: destinationItems, accentHex: accentHex, glowHex: glowHex, onSelect: { _ in })
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.75))
                        .frame(width: 54, height: 54).background(Color.white.opacity(0.07), in: Circle())
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 26)
    }

    private func catalogCard(_ item: AddonCatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Color.white.opacity(0.07))
                if let url = item.posterURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase { image.resizable().scaledToFill() } else { placeholder(for: item) }
                    }
                } else { placeholder(for: item) }
            }
            .frame(width: 145, height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            Text(item.name).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1).frame(width: 145, alignment: .leading)
            Text(item.year ?? "").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.52)).frame(width: 145, alignment: .leading)
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
            selectedEntry = entry; showPlayer = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08))
                if let rawPoster = entry.posterURL, let poster = URL(string: rawPoster) {
                    AsyncImage(url: poster) { phase in
                        if case .success(let image) = phase { image.resizable().scaledToFill() } else { Color.white.opacity(0.06) }
                    }
                }
                LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                    Text(remainingText(entry)).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.72))
                    GeometryReader { geo in
                        Capsule().fill(Color.white.opacity(0.22)).overlay(alignment: .leading) { Capsule().fill(.white).frame(width: geo.size.width * progress) }
                    }.frame(height: 4)
                }.padding(16)
            }
            .frame(width: 310, height: 174).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func remainingText(_ entry: ContinueWatchingItem) -> String {
        guard entry.duration > entry.position else { return "Continue watching" }
        let minutes = Int(max(0, entry.duration - entry.position) / 60)
        return minutes > 0 ? "\(minutes)m left" : "Continue watching"
    }

    private func unique(_ items: [AddonCatalogItem]) -> [AddonCatalogItem] {
        var seen = Set<String>()
        return items.filter { seen.insert("\($0.type.lowercased())|\($0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\($0.year ?? "")").inserted }
    }
}
