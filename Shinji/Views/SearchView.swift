import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var addonStore: AddonStore
    @State private var query = ""
    @State private var selectedType = "All"
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"
    @AppStorage("shinjiGlowHex") private var glowHex = "4936FF"

    private let types = ["All", "Movies", "Shows"]

    private var results: [AddonCatalogItem] {
        var items = addonStore.catalogItems
        if selectedType == "Movies" { items = items.filter { $0.type.lowercased() == "movie" } }
        if selectedType == "Shows" { items = items.filter { $0.type.lowercased() == "series" } }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed) ||
                ($0.description ?? "").localizedCaseInsensitiveContains(trimmed) ||
                ($0.year ?? "").contains(trimmed)
            }
        }
        var seen = Set<String>()
        return items.filter { seen.insert("\($0.type)|\($0.id)|\($0.name.lowercased())").inserted }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    searchField
                    typePicker

                    if results.isEmpty {
                        emptyState
                    } else {
                        Text(query.isEmpty ? "Browse" : "Search results")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 20) {
                            ForEach(results) { item in
                                NavigationLink {
                                    CatalogItemDetailView(item: item)
                                } label: {
                                    posterCard(item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 115)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task { await addonStore.refreshCatalogs() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Search")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Find movies and shows from your sources")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.52))
        }
        .padding(.horizontal, 18)
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hex: accentHex))
            TextField("Search movies and shows", text: $query)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 52)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 18)
    }

    private var typePicker: some View {
        HStack(spacing: 8) {
            ForEach(types, id: \.self) { type in
                Button { selectedType = type } label: {
                    Text(type)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedType == type ? .black : .white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(selectedType == type ? Color.white : Color.white.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
    }

    private func posterCard(_ item: AddonCatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                if let url = item.posterURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            placeholder(item)
                        }
                    }
                } else {
                    placeholder(item)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                Text(item.type.lowercased() == "movie" ? "MOVIE" : "TV")
                    .font(.system(size: 8, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(9)
            }
            .aspectRatio(0.69, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            Text(item.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(item.year ?? item.addonName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(1)
        }
    }

    private func placeholder(_ item: AddonCatalogItem) -> some View {
        LinearGradient(colors: [Color(hex: glowHex), Color(hex: accentHex).opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: query.isEmpty ? "rectangle.stack.badge.plus" : "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color(hex: accentHex))
            Text(query.isEmpty ? "Nothing to browse yet" : "No results")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(query.isEmpty ? "Install a source and your catalog titles will appear here." : "Try another title or switch the filter.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.vertical, 70)
    }
}
