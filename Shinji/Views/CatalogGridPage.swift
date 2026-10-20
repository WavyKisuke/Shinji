import SwiftUI

struct CatalogGridPage: View {
    let title: String
    let items: [AddonCatalogItem]
    let accentHex: String
    let glowHex: String
    let onSelect: (AddonCatalogItem) -> Void

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(items) { item in
                    NavigationLink {
                        UnifiedLibraryView(kind: item.type.lowercased() == "movie" ? .movies : .tvShows)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.07))
                                if let url = item.posterURL {
                                    AsyncImage(url: url) { phase in
                                        if case .success(let image) = phase { image.resizable().scaledToFill() }
                                        else { placeholder(for: item) }
                                    }
                                } else { placeholder(for: item) }
                            }
                            .frame(maxWidth: .infinity)
                            .aspectRatio(0.69, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            Text(item.name).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(2)
                            Text(item.year ?? "").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }

    private func placeholder(for item: AddonCatalogItem) -> some View {
        LinearGradient(colors: [Color(hex: glowHex), Color(hex: accentHex).opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv").font(.system(size: 38, weight: .light)).foregroundStyle(.white.opacity(0.7)) }
    }
}
