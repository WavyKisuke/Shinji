import SwiftUI

struct HomeLibraryView: View {
    @EnvironmentObject private var addonStore: AddonStore
    @StateObject private var continueStore = ContinueWatchingStore.shared
    @State private var selectedEntry: ContinueWatchingItem?
    @State private var showPlayer = false
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    keepWatchingSection
                }
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showPlayer) {
                if let entry = selectedEntry, let url = URL(string: entry.url) {
                    PlayerView(url: url, title: entry.title, headers: entry.headers)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await addonStore.refreshCatalogs() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("LIBRARY")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(3.2)
                .foregroundStyle(Color(hex: accentHex))
            Text("Your Library")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Everything you’re watching, in one place.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.52))
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var keepWatchingSection: some View {
        if continueStore.items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Keep Watching", systemImage: "play.circle")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Start a movie or show and your progress will appear here automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)
        } else {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Keep Watching")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Continue where you left off")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    Button("Clear") { continueStore.clearAll() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: accentHex))
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 13) {
                        ForEach(continueStore.items) { entry in
                            continueCard(entry)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func continueCard(_ entry: ContinueWatchingItem) -> some View {
        let progress = entry.duration > 0 ? min(max(entry.position / entry.duration, 0), 1) : 0
        return Button {
            selectedEntry = entry
            showPlayer = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.08))
                        .overlay(Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.55)))
                    LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                    VStack(spacing: 5) {
                        Spacer()
                        HStack {
                            Text(formatTime(entry.position))
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .padding(7)
                                .background(Color(hex: accentHex), in: Circle())
                        }
                        .foregroundStyle(.white)
                        .padding(9)
                    }
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            Color(hex: accentHex)
                                .frame(width: geo.size.width * progress, height: 3)
                        }
                    }
                }
                .frame(width: 145, height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))

                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 145, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}
