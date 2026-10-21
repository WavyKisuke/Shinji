import SwiftUI

struct CatalogItemDetailView: View {
    let item: AddonCatalogItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var addonStore: AddonStore
    @ObservedObject private var watchlistStore = WatchlistStore.shared
    @State private var isLoading = false
    @State private var selectedStream: AddonStreamOption?
    @State private var showPlayer = false
    @State private var libraryMessage: String?

    private var isSaved: Bool {
        watchlistStore.contains(catalogID: item.id, addonName: item.addonName)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    poster
                    Text(item.name)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(metadata)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                    if let description = item.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 12) {
                        Button {
                            toggleLibrary()
                        } label: {
                            Label(isSaved ? "Saved to Library" : "Add to Library", systemImage: isSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .contentShape(Rectangle())

                        Button {
                            Task { await loadStreams() }
                        } label: {
                            Label(isLoading ? "Finding…" : "Play", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }

                    if let libraryMessage {
                        Label(libraryMessage, systemImage: isSaved ? "checkmark.circle.fill" : "bookmark.slash")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .transition(.opacity)
                    }

                    if let status = addonStore.streamStatus {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    if !addonStore.streamOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sources")
                                .font(.headline)
                                .foregroundStyle(.white)
                            ForEach(addonStore.streamOptions) { stream in
                                Button(stream.title) {
                                    selectedStream = stream
                                    showPlayer = true
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaved ? "Saved" : "Save") {
                        toggleLibrary()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .fullScreenCover(isPresented: $showPlayer) {
                if let stream = selectedStream {
                    PlayerView(url: stream.url, title: item.name, headers: stream.headers, posterURL: item.posterURL)
                }
            }
        }
    }

    private func toggleLibrary() {
        withAnimation(.easeInOut(duration: 0.16)) {
            watchlistStore.toggle(item)
        }
        libraryMessage = isSaved ? "Added to your Library" : "Removed from your Library"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            libraryMessage = nil
        }
    }

    private var poster: some View {
        Group {
            if let url = item.posterURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 430)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay {
                Image(systemName: item.type.lowercased() == "movie" ? "film" : "tv")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.white.opacity(0.55))
            }
    }

    private var metadata: String {
        [item.type.capitalized, item.year, item.addonName]
            .compactMap { $0 }
            .joined(separator: "  •  ")
    }

    private func loadStreams() async {
        isLoading = true
        await addonStore.loadStreams(for: item)
        isLoading = false
        if let first = addonStore.streamOptions.first {
            selectedStream = first
            showPlayer = true
        }
    }
}
