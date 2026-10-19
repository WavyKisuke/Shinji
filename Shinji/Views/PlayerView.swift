import SwiftUI
import AVKit

struct PlayerView: View {
    let url: URL
    let title: String
    var headers: [String: String] = [:]
    @State private var player = AVPlayer()\n    @State private var mpvReloadID = UUID()
    @State private var isMuted = false
    @State private var isFullscreen = false
    @State private var externalLaunchFailed = false
    @State private var playbackError: String?
    @State private var isPreparingPlayback = false
    @State private var playbackDiagnostics = "Waiting for stream"
    @State private var externalFallbackMessage: String?
    @State private var itemStatusObservation: NSKeyValueObservation?
    @State private var presentationSizeObservation: NSKeyValueObservation?
    @State private var timeControlObservation: NSKeyValueObservation?
    @AppStorage("shinjiPreferredPlayer") private var preferredPlayer = "Shinji"

    var body: some View {
        VStack(spacing: 14) {
            if preferredPlayer == "Shinji" || externalLaunchFailed {
                VStack(spacing: 10) {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity)
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
                                    Button { openInVLC() } label: { Label("Try in VLC", systemImage: "arrow.up.forward.app") }
                                        .buttonStyle(.bordered)
                                    if let externalFallbackMessage {
                                        Text(externalFallbackMessage)
                                            .font(.caption2)
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(.white.opacity(0.75))
                                    }
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
                    } else if playbackError == nil {
                        Text(playbackDiagnostics)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                MPVPlayerSurface(url: url, headers: headers, muted: isMuted, onStatus: { status in\n                    playbackDiagnostics = status\n                    isPreparingPlayback = false\n                }, onError: { error in\n                    playbackError = error\n                    isPreparingPlayback = false\n                }).id(mpvReloadID).ignoresSafeArea()
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
            presentationSizeObservation?.invalidate()
            presentationSizeObservation = nil
            timeControlObservation?.invalidate()
            timeControlObservation = nil
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
            playbackError = playbackFailureMessage(for: item,
                fallback: (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
                    ?? "The stream stopped unexpectedly or uses a format iOS can't play.")
            isPreparingPlayback = false
        }
    }
    /// Combines AVFoundation's error with its HTTP/transport error log so the
    /// UI can distinguish common cases such as 401/403, 404, and media failures.
    private func playbackFailureMessage(for item: AVPlayerItem, fallback: String) -> String {
        var details: [String] = []
        if let error = item.error as NSError? {
            details.append("\(error.localizedDescription) (\(error.domain) \(error.code))")
            if let reason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String, !reason.isEmpty {
                details.append(reason)
            }
            if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                details.append("Underlying: \(underlying.domain) \(underlying.code) — \(underlying.localizedDescription)")
            }
        }

        var httpStatus: Int?
        if let event = item.errorLog()?.events.last {
            let status = event.errorStatusCode
            if status > 0 {
                httpStatus = status
                details.append("HTTP status \(status)")
            }
            let domain = event.errorDomain
            if !domain.isEmpty {
                details.append("Network error domain: \(domain)")
            }
            if let comment = event.errorComment, !comment.isEmpty {
                details.append(comment)
            }
        }

        if let httpStatus {
            switch httpStatus {
            case 401, 403:
                details.append("The source denied access. Its authorization, cookies, or required request headers may be missing or expired.")
            case 404, 410:
                details.append("The stream URL may have expired or the source no longer has this file. Try requesting a fresh source.")
            case 408, 429:
                details.append("The source timed out or rate-limited the request. Wait briefly and retry.")
            case 500...599:
                details.append("The source server reported a failure. Try another source or retry later.")
            default:
                break
            }
        }

        let uniqueDetails = Array(NSOrderedSet(array: details)) as? [String] ?? details
        return uniqueDetails.isEmpty ? fallback : uniqueDetails.joined(separator: "\n")
    }


    private func openInVLC() {
        var components = URLComponents()
        components.scheme = "vlc-x-callback"
        components.host = "x-callback-url"
        components.path = "/stream"
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        guard let target = components.url else {
            externalFallbackMessage = "Could not prepare the VLC link."
            return
        }
        UIApplication.shared.open(target, options: [:]) { success in
            DispatchQueue.main.async {
                externalFallbackMessage = success
                    ? "VLC was opened. Continue playback there."
                    : "VLC is not installed or could not open this stream."
            }
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
        // Recreate the libmpv surface to retry without falling back to AVPlayer.
        playbackError = nil
        playbackDiagnostics = "Starting MPV playback…"
        isPreparingPlayback = true
        externalLaunchFailed = false
        mpvReloadID = UUID()
        PlaybackAudio.configureToMixWithOtherAudio()
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
