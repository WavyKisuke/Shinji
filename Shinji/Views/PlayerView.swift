import SwiftUI
import AVKit

struct PlayerView: View {
    let url: URL
    let title: String
    @State private var player = AVPlayer()
    @State private var isMuted = false

    var body: some View {
        VStack(spacing: 14) {
            VideoPlayer(player: player)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .background(.black)
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
            PlaybackAudio.configureToMixWithOtherAudio()
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            player.play()
        }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }
}
