import SwiftUI
import AVKit

struct PlayerView: View {
    let url: URL
    let title: String
    var headers: [String: String] = [:]
    @State private var player = AVPlayer()
    @State private var isMuted = false
    @State private var isFullscreen = false
    @State private var externalLaunchFailed = false
    @State private var playbackError: String?
    @State private var isPreparingPlayback = false
    @State private var itemStatusObservation: NSKeyValueObservation?
    @AppStorage("shinjiPreferredPlayer") private var preferredPlayer = "Shinji"

    var body: some View {
        VStack(spacing: 14) {
            if preferredPlayer == "Shinji" || externalLaunchFailed {
                VStack(spacing: 10) {
                    VideoPlayer(player: player)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .background(.black)
                        .overlay {
                            if isPreparingPlayback {
                                VStack(spacing: 10) {
                                    ProgressView().tint(.white)
                                    Text("Loading video…").font(.footnote.weight(.medium)).foregroundStyle(.white)
                                }
                                .padding(16).background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                            } else if let playbackError {
                                VStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill").font(.title2)
                                    Text("Couldn't play this stream").font(.headline)
                                    Text(playbackError).font(.footnote).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
                                    Button { startInternalPlayback() } label: { Label("Try again", systemImage: "arrow.clockwise") }
                                        .buttonStyle(.borderedProminent)
                                }
                                .foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.black.opacity(0.88))
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            Button { isFullscreen = true } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(.black.opacity(0.65), in: Circle())
                            }
                            .accessibilityLabel("Enter full screen")
                            .padding(10)
                        }
                    if isPreparingPlayback {
                        ProgressView("Loading stream…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
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
                if preferredPlayer == "Shinji" || externalLaunchFailed {
                    Menu {
                        Button { selectAudioTrack(nil) } label: {
                            Label("No audio", systemImage: "speaker.slash")
                        }
                        if let group = audibleGroup {
                            ForEach(group.options, id: \.self) { option in
                                Button(option.displayName) { selectAudioTrack(option) }
                            }
                        }
                    } label: {
                        Label("Audio", systemImage: "waveform")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Choose audio track")
                }
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
        .fullScreenCover(isPresented: $isFullscreen) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                VideoPlayer(player: player).ignoresSafeArea()
                Button { isFullscreen = false } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.7), in: Circle())
                }
                .accessibilityLabel("Exit full screen")
                .padding()
            }
            .preferredColorScheme(.dark)
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
            itemStatusObservation?.invalidate()
            itemStatusObservation = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled)) { notification in
            guard let item = notification.object as? AVPlayerItem, item === player.currentItem else { return }
            playbackError = "Playback stalled. The source may be slow, offline, or require additional access."
            isPreparingPlayback = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem, item === player.currentItem else { return }
            playbackError = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
                ?? item.error?.localizedDescription
                ?? "The stream stopped unexpectedly or uses a format iOS can't play."
            isPreparingPlayback = false
        }
    }
    private var audibleGroup: AVMediaSelectionGroup? {
        player.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
    }

    private func selectAudioTrack(_ option: AVMediaSelectionOption?) {
        guard let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
        item.select(option, in: group)
    }

    private func startInternalPlayback() {
        itemStatusObservation?.invalidate()
        playbackError = nil
        isPreparingPlayback = true
        PlaybackAudio.configureToMixWithOtherAudio()

        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { observedItem, _ in
            DispatchQueue.main.async {
                switch observedItem.status {
                case .readyToPlay:
                    playbackError = nil
                    isPreparingPlayback = false
                    player.play()
                case .failed:
                    isPreparingPlayback = false
                    playbackError = observedItem.error?.localizedDescription
                        ?? "This stream could not be played. It may require headers, authentication, or a different player."
                case .unknown:
                    isPreparingPlayback = true
                @unknown default:
                    isPreparingPlayback = false
                    playbackError = "The stream returned an unknown playback state."
                }
            }
        }
        player.replaceCurrentItem(with: item)
        // Wait for AVFoundation to confirm the item is ready before starting playback.
        player.pause()
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
