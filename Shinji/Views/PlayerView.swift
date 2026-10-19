import SwiftUI
import AVKit

struct PlayerView: View {
    let url: URL
    let title: String
    @State private var player = AVPlayer()
    @State private var isMuted = false
    @State private var externalLaunchFailed = false
    @AppStorage("shinjiPreferredPlayer") private var preferredPlayer = "Shinji"

    var body: some View {
        VStack(spacing: 14) {
            if preferredPlayer == "Shinji" || externalLaunchFailed {
                VideoPlayer(player: player)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .background(.black)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.up.forward.app").font(.system(size: 42)).foregroundStyle(.secondary)
                    Text("Opening \(preferredPlayer)…").font(.headline)
                    Text("Shinji is handing this stream to your selected player.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Try again") { openExternalPlayer() }.buttonStyle(.bordered)
                    Button("Play in Shinji") {
                        preferredPlayer = "Shinji"
                        externalLaunchFailed = false
                        startInternalPlayback()
                    }.buttonStyle(.borderedProminent)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text("Playback").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isMuted.toggle()
                    player.isMuted = isMuted
                } label: {
                    Label(isMuted ? "Unmute" : "Mute",
                          systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            Spacer()
            Text("Playback depends on the source format and access permissions.")
                .font(.footnote).foregroundStyle(.secondary).padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if preferredPlayer == "Shinji" {
                startInternalPlayback()
            } else {
                openExternalPlayer()
            }
        }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }
    private func startInternalPlayback() {
        PlaybackAudio.configureToMixWithOtherAudio()
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
    }

    private func openExternalPlayer() {
        let target: URL?
        switch preferredPlayer {
        case "VLC":
            var components = URLComponents()
            components.scheme = "vlc-x-callback"
            components.host = "x-callback-url"
            components.path = "/stream"
            components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
            target = components.url
        case "Outplayer":
            target = URL(string: "outplayer://\(url.absoluteString)")
        default:
            target = nil
        }
        guard let target else { externalLaunchFailed = true; return }
        UIApplication.shared.open(target, options: [:]) { success in
            DispatchQueue.main.async { externalLaunchFailed = !success }
        }
    }
}
