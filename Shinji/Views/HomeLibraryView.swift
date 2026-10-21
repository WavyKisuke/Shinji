import SwiftUI

struct HomeLibraryView: View {
    @EnvironmentObject private var addonStore: AddonStore
    @StateObject private var continueStore = ContinueWatchingStore.shared
    @State private var selectedEntry: ContinueWatchingItem?
    @State private var showPlayer = false
    @State private var heroIndex = 0
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"
    @AppStorage("shinjiGlowHex") private var glowHex = "4936FF"
    private let heroRotationInterval: TimeInterval = 300

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
                LazyVStack(alignment: .leading, spacing: 28) {
                    heroSection
                    keepWatchingSection
                    catalogSection(title: "Popular Movies", items: popularMovies)
                    catalogSection(title: "Popular Series", items: popularSeries)
                    catalogSection(title: "Featured Movies", items: featuredMovies)
                    catalogSection(title: "Featured Series", items: featuredSeries)
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
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.38), radius: 18, x: 0, y: 12)
            .overlay(alignment: .bottom) {
                HStack(spacing: 6) {
                    ForEach(0..<heroItems.count, id: \.self) { index in
                        Capsule()
                            .fill(index == heroIndex ? Color.white : Color.white.opacity(0.35))
                            .frame(width: index == heroIndex ? 28 : 6, height: 4)
                    }
                }
                .padding(.bottom, 13)
            }
            .padding(.horizontal, 14)
            .onReceive(Timer.publish(every: heroRotationInterval, on: .main, in: .common).autoconnect()) { _ in
                guard heroItems.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.55)) {
                    heroIndex = (heroIndex + 1) % heroItems.count
                }
            }
        }
    }

    private func heroCard(_ item: AddonCatalogItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
            if let url = item.posterURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().interpolation(.high).scaledToFill()
                    } else {
                        heroPlaceholder(item)
                    }
                }
            } else {
                heroPlaceholder(item)
            }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.18),
                    .init(color: .black.opacity(0.12), location: 0.40),
                    .init(color: .black.opacity(0.94), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(item.type.capitalized)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.78))
                    Spacer()
                    Text("TOP PICK")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.9), in: Capsule())
                }
                Text(item.name)
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Text(item.description ?? "Discover a new favorite tonight.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Text("View Details")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .frame(height: 38)
                        .background(.white, in: Capsule())
                    if let year = item.year, !year.isEmpty {
                        Text(year)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 27)
        }
        .clipped()
    }

    private func heroPlaceholder(_ item: AddonCatalogItem) -> some View {
        LinearGradient(colors: [Color(hex: glowHex), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Text(item.name)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding()
            }
    }

    @ViewBuilder
    private var keepWatchingSection: some View {
        if !continueStore.items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Continue Watching", showArrow: false)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(continueStore.items) { entry in
                            continueCard(entry)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    @ViewBuilder
    private func catalogSection(title: String, items: [AddonCatalogItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(title, showArrow: true, destinationItems: items)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(items) { item in
                            NavigationLink {
                                CatalogItemDetailView(item: item)
                            } label: {
                                catalogCard(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    private func sectionTitle(_ title: String, showArrow: Bool, destinationItems: [AddonCatalogItem] = []) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if showArrow {
                NavigationLink {
                    CatalogGridPage(title: title, items: destinationItems, accentHex: accentHex, glowHex: glowHex, onSelect: { _ in })
                } label: {
                    HStack(spacing: 6) {
                        Text("See all")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
    }

    private func catalogCard(_ item: AddonCatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.07))
                if let url = item.posterURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().interpolation(.high).scaledToFill()
                        } else {
                            placeholder(for: item)
                        }
                    }
                } else {
                    placeholder(for: item)
                }

                LinearGradient(colors: [.clear, .black.opacity(0.66)], startPoint: .center, endPoint: .bottom)
                Text(item.type.lowercased() == "movie" ? "MOVIE" : "SERIES")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.28), in: Capsule())
                    .padding(10)
            }
            .frame(width: 132, height: 192)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 10)

            Text(item.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 132, alignment: .leading)
            Text(item.year ?? "New")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
                .frame(width: 132, alignment: .leading)
        }
        .frame(width: 132, alignment: .leading)
    }

    private func placeholder(for item: AddonCatalogItem) -> some View {
        LinearGradient(colors: [Color(hex: glowHex), Color(hex: accentHex).opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
    }

    private func continueCard(_ entry: ContinueWatchingItem) -> some View {
        let progress = entry.duration > 0 ? min(max(entry.position / entry.duration, 0), 1) : 0
        return Button {
            selectedEntry = entry
            showPlayer = true
        } label: {
            HStack(spacing: 11) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08))
                    if let rawPoster = entry.posterURL, let poster = URL(string: rawPoster) {
                        AsyncImage(url: poster) { phase in
                            if case .success(let image) = phase {
                                image.resizable().interpolation(.high).scaledToFill()
                            } else {
                                Color.white.opacity(0.06)
                            }
                        }
                    }
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 3)
                        .padding(.horizontal, 7)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(.white)
                                .frame(width: max(0, 76 * progress), height: 3)
                                .padding(.leading, 7)
                        }
                }
                .frame(width: 86, height: 122)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text("NOW WATCHING")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.45))
                    Text(entry.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(remainingText(entry))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Resume")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .frame(height: 30)
                    .padding(.horizontal, 9)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }
                .frame(width: 145, alignment: .leading)
            }
            .frame(width: 255, height: 122, alignment: .leading)
            .padding(10)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
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
