import SwiftUI
import AVKit

struct PlayerView: View {
    let url: URL
    let title: String
    var headers: [String: String] = [:]

    @Environment(\.dismiss) private var dismiss
    @State private var isMuted = false
    @State private var isPlaying = true
    @State private var showControls = true
    @State private var isFullscreen = false
    @State private var playbackError: String?
    @State private var playbackDiagnostics = "Opening stream…"
    @State private var isPreparingPlayback = true
    @State private var position: Double = 0
    @State private var duration: Double = 0
    @State private var commandID = 0
    @State private var command: String?
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var externalFallbackMessage: String?
    @AppStorage("shinjiPreferredPlayer") private var preferredPlayer = "Shinji"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if preferredPlayer == "Shinji" {
                playerSurface
                controlsOverlay
            } else {
                externalPlayerPlaceholder
            }

            if isPreparingPlayback && playbackError == nil && preferredPlayer == "Shinji" {
                ProgressView().tint(.white).scaleEffect(1.15).allowsHitTesting(false)
            }

            if let playbackError { errorOverlay(playbackError) }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { startInternalPlayback() }
        .onDisappear { hideControlsTask?.cancel() }
        .fullScreenCover(isPresented: $isFullscreen) {
            PlayerFullscreenView(url: url, title: title, headers: headers, muted: isMuted)
        }
        .navigationBarHidden(true)
    }

    private var playerSurface: some View {
        MPVPlayerSurface(
            url: url,
            headers: headers,
            muted: isMuted,
            commandID: commandID,
            command: command,
            onStatus: { status in
                playbackDiagnostics = status
                if status.contains("loaded") { isPreparingPlayback = false }
            },
            onError: { error in
                playbackError = error
                isPreparingPlayback = false
            },
            onPlaybackUpdate: { time, total, paused in
                position = time
                duration = total
                isPlaying = !paused
                if total > 0 { isPreparingPlayback = false }
            }
        )
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { toggleControls() }
    }

    private var controlsOverlay: some View {
        ZStack {
            if showControls {
                LinearGradient(
                    colors: [.black.opacity(0.72), .clear, .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    centerControls
                    Spacer()
                    bottomControls
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showControls)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.42), in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline.weight(.semibold)).lineLimit(1)
                Text(playbackDiagnostics)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }

            Spacer()
            playerButton("arrow.up.left.and.arrow.down.right", "Fullscreen") { isFullscreen = true }
            playerButton("ellipsis", "More") { }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var centerControls: some View {
        HStack(spacing: 34) {
            seekButton(seconds: -10)
            Button {
                sendCommand("cycle pause")
                isPlaying.toggle()
                scheduleHide()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .bold))
                    .frame(width: 72, height: 72)
                    .background(.white.opacity(0.94), in: Circle())
                    .foregroundStyle(.black)
            }
            seekButton(seconds: 10)
        }
        .foregroundStyle(.white)
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(formatTime(position)).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.88))
                Slider(value: Binding(
                    get: { duration > 0 ? min(position, duration) : 0 },
                    set: { newValue in
                        guard duration > 0 else { return }
                        sendCommand("seek \(newValue) absolute")
                        position = newValue
                    }
                ), in: 0...max(duration, 1)).tint(.white)
                Text(formatTime(duration)).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.88))
            }

            HStack(spacing: 10) {
                pill("waveform", "Audio") { }
                pill("captions.bubble", "Subtitles") { }
                pill(isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", isMuted ? "Unmute" : "Mute") {
                    isMuted.toggle()
                }
                Spacer()
                Text("Shinji").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.55))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private func playerButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(.black.opacity(0.42), in: Circle())
        }
        .accessibilityLabel(label)
    }

    private func pill(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 13)
                .frame(height: 36)
                .background(.black.opacity(0.52), in: Capsule())
        }
    }

    private func seekButton(seconds: Int) -> some View {
        Button {
            sendCommand("seek \(seconds) relative")
            position = max(0, min(duration, position + Double(seconds)))
            scheduleHide()
        } label: {
            ZStack {
                Image(systemName: "gobackward").font(.system(size: 25, weight: .semibold))
                Text("\(abs(seconds))").font(.system(size: 9, weight: .bold)).offset(y: 1)
            }
            .frame(width: 58, height: 58)
            .background(.black.opacity(0.42), in: Circle())
        }
    }

    private var externalPlayerPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.up.forward.app").font(.system(size: 44))
            Text("Opening \(preferredPlayer)…").font(.headline)
            Text("Shinji is handing this stream to your selected player.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(30)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title)
            Text("Couldn't play this stream").font(.headline)
            Text(message).font(.footnote).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            Button("Try Again") { startInternalPlayback() }.buttonStyle(.borderedProminent)
            Button("Open in VLC") { openInVLC() }.buttonStyle(.bordered)
            if let externalFallbackMessage {
                Text(externalFallbackMessage).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: 430)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 20))
        .padding(24)
    }

    private func startInternalPlayback() {
        playbackError = nil
        isPreparingPlayback = true
        playbackDiagnostics = "Opening stream…"
        position = 0
        duration = 0
        command = nil
        commandID += 1
        scheduleHide()
        PlaybackAudio.configureToMixWithOtherAudio()
    }

    private func sendCommand(_ value: String) {
        command = value
        commandID += 1
    }

    private func toggleControls() {
        withAnimation { showControls.toggle() }
        if showControls { scheduleHide() } else { hideControlsTask?.cancel() }
    }

    private func scheduleHide() {
        hideControlsTask?.cancel()
        showControls = true
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { showControls = false } }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func openInVLC() {
        var components = URLComponents()
        components.scheme = "vlc-x-callback"
        components.host = "x-callback-url"
        components.path = "/stream"
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        guard let target = components.url else { return }
        UIApplication.shared.open(target, options: [:]) { success in
            DispatchQueue.main.async {
                externalFallbackMessage = success ? "VLC was opened." : "VLC is not installed."
            }
        }
    }
}

private struct PlayerFullscreenView: View {
    let url: URL
    let title: String
    let headers: [String: String]
    let muted: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isMuted: Bool

    init(url: URL, title: String, headers: [String: String], muted: Bool) {
        self.url = url
        self.title = title
        self.headers = headers
        self.muted = muted
        _isMuted = State(initialValue: muted)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            MPVPlayerSurface(url: url, headers: headers, muted: isMuted, onStatus: { _ in }, onError: { _ in })
                .ignoresSafeArea()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .padding(16)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
    }
}
