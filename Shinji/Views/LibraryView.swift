import SwiftUI

enum LibraryKind: String {
    case movies = "Movies"
    case shows = "TV Shows"
    case live = "Live TV"

    var subtitle: String {
        switch self {
        case .movies: return "Your movie library"
        case .shows: return "Your series and episodes"
        case .live: return "Your live channels"
        }
    }
}

struct LibraryView: View {
    let kind: LibraryKind
    @State private var searchText = ""
    @State private var streamURL = ""
    @State private var showPlayer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(kind.rawValue).font(.largeTitle.bold())
                        Text(kind.subtitle).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        Image(systemName: kind == .live ? "antenna.radiowaves.left.and.right" : "play.rectangle")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("No sources yet").font(.headline)
                        Text("Install an add-on to connect a catalog, or try a stream URL below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Play a stream URL").font(.headline)
                        TextField("https://example.org/video.m3u8", text: $streamURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Button { showPlayer = true } label: {
                            Label("Open Player", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isValidStreamURL)
                    }
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "Search titles and channels")
            .navigationTitle("Shinji")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPlayer) {
                if let url = URL(string: streamURL),
                   ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                   url.host != nil {
                    PlayerView(url: url, title: "Stream")
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Invalid URL")
                            .font(.headline)
                        Text("Enter a valid HTTP or HTTPS stream URL and try again.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .navigationTitle("Unable to Play")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    private var isValidStreamURL: Bool {
        guard let url = URL(string: streamURL),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              url.host != nil else { return false }
        return true
    }
}
