import SwiftUI

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
    @State private var playbackDiagnostics = "Loading…"
    @State private var isPreparingPlayback = true
    @State private var position: Double = 0
    @State private var duration: Double = 0
    @State private var commandID = 0
    @State private var command: String?
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var controlsLocked = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                playerSurface(in: proxy.size)
                    .zIndex(0)

                if showControls && !controlsLocked {
                    controlsOverlay(in: proxy.size)
                        .zIndex(10)
                }

                if isPreparingPlayback && playbackError == nil {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.15)
                        .zIndex(20)
                        .allowsHitTesting(false)
                }

                if let playbackError {
                    errorOverlay(playbackError)
                        .zIndex(30)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .navigationBarHidden(true)
        .onAppear { startInternalPlayback() }
        .onDisappear { hideControlsTask?.cancel() }
    }

    private func playerSurface(in size: CGSize) -> some View {
        MPVPlayerSurface(
            url: url,
            headers: headers,
            muted: isMuted,
            commandID: commandID,
            command: command,
            onStatus: { status in
                playbackDiagnostics = status
                if status.localizedCaseInsensitiveContains("loaded") {
                    isPreparingPlayback = false
                }
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
        .frame(
            width: isFullscreen ? size.height : size.width,
            height: isFullscreen ? size.width : size.height
        )
        .rotationEffect(.degrees(isFullscreen ? 90 : 0))
        .background(.black)
        .contentShape(Rectangle())
        // The Metal-backed UIView can otherwise win UIKit hit-testing even though
        // the SwiftUI overlay is visually above it. Let it receive taps only when
        // the controls are hidden; when controls are visible, buttons own the touch.
        .allowsHitTesting(!showControls || controlsLocked)
        .onTapGesture {
            guard playbackError == nil else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                showControls.toggle()
            }
            if showControls { scheduleHide() } else { hideControlsTask?.cancel() }
        }
    }

    private func controlsOverlay(in size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.52), .clear, .black.opacity(0.66)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                centerControls
                Spacer()
                bottomControls
            }
        }
        .frame(
            width: isFullscreen ? size.height : size.width,
            height: isFullscreen ? size.width : size.height
        )
        .rotationEffect(.degrees(isFullscreen ? 90 : 0))
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.18), value: showControls)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close player")

            if !isFullscreen {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text(playbackDiagnostics)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFullscreen.toggle()
                    showControls = true
                }
                scheduleHide()
            } label: {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFullscreen ? "Exit fullscreen" : "Enter fullscreen")

            Button {
                withAnimation { controlsLocked.toggle() }
            } label: {
                Image(systemName: controlsLocked ? "lock.fill" : "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(controlsLocked ? "Unlock controls" : "More options")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private var centerControls: some View {
        HStack(spacing: 46) {
            seekButton(seconds: -10)

            Button {
                sendCommand("cycle pause")
                isPlaying.toggle()
                scheduleHide()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .frame(width: 64, height: 64)
                    .background(.black.opacity(0.28), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            seekButton(seconds: 10)
        }
        .shadow(radius: 8)
    }

    private var bottomControls: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                Text(formatTime(position))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.86))
                Slider(
                    value: Binding(
                        get: { duration > 0 ? min(position, duration) : 0 },
                        set: { newValue in
                            guard duration > 0 else { return }
                            position = newValue
                            sendCommand("seek \(newValue) absolute")
                        }
                    ),
                    in: 0...max(duration, 1)
                )
                .tint(.white)
                Text(formatTime(duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.86))
            }

            HStack(spacing: 22) {
                bottomButton("waveform", "Audio") { }
                bottomButton("captions.bubble", "Subtitles") { }
                bottomButton(isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", isMuted ? "Unmute" : "Mute") {
                    isMuted.toggle()
                    sendCommand("set mute \(isMuted ? "yes" : "no")")
                    scheduleHide()
                }
                bottomButton("gearshape", "Settings") { }
                Spacer()
                Text("Shinji")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private func seekButton(seconds: Int) -> some View {
        Button {
            sendCommand("seek \(seconds) relative")
            if duration > 0 {
                position = max(0, min(duration, position + Double(seconds)))
            }
            scheduleHide()
        } label: {
            ZStack {
                Image(systemName: seconds < 0 ? "gobackward" : "goforward")
                    .font(.system(size: 24, weight: .semibold))
                Text("10")
                    .font(.system(size: 8, weight: .bold))
                    .offset(y: 1)
            }
            .frame(width: 54, height: 54)
            .background(.black.opacity(0.3), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func bottomButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title)
            Text("Couldn't play this stream").font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
            Button("Try Again") { startInternalPlayback() }
                .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: 430)
        .background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
        .padding(24)
    }

    private func startInternalPlayback() {
        playbackError = nil
        isPreparingPlayback = true
        playbackDiagnostics = "Loading…"
        position = 0
        duration = 0
        command = nil
        commandID += 1
        showControls = true
        scheduleHide()
        PlaybackAudio.configureToMixWithOtherAudio()
    }

    private func sendCommand(_ value: String) {
        command = value
        commandID += 1
    }

    private func scheduleHide() {
        hideControlsTask?.cancel()
        showControls = true
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showControls = false
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
