import SwiftUI

enum MediaLibraryKind: Equatable {
    case movies
    case tvShows
}

struct UnifiedLibraryView: View {
    let kind: MediaLibraryKind
    @StateObject private var watchlistStore = WatchlistStore.shared
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"

    private var savedMovies: [WatchlistItem] {
        watchlistStore.items.filter { $0.type.lowercased() == "movie" }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if savedMovies.isEmpty {
                        emptyState
                    } else {
                        movieGrid
                    }
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
            Text("Movies you picked or favorited")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color(hex: accentHex).opacity(0.12))
                    .frame(width: 74, height: 74)
                Image(systemName: "film.stack")
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(Color(hex: accentHex))
            }

            VStack(spacing: 7) {
                Text("Your library is empty")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Movies you pick or favorite will appear here. Browse Home or Search and save a movie to build your library.")
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
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var movieGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 18) {
            ForEach(savedMovies) { item in
                savedMovieCard(item)
            }
        }
    }

    private func savedMovieCard(_ item: WatchlistItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .aspectRatio(0.67, contentMode: .fit)

                if let string = item.posterURL, let url = URL(string: string) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            posterPlaceholder
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    posterPlaceholder
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Image(systemName: "heart.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.62), in: Circle())
                    .padding(7)
            }

            Text(item.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 25, weight: .light))
                    .foregroundStyle(.white.opacity(0.35))
            }
    }
}
