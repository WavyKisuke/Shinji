import SwiftUI
import UIKit

struct PlayerView: View {
    let url: URL
    let title: String
    var headers: [String: String] = [:]
    var posterURL: URL? = nil
    var addonAudioTracks: [AddonExternalTrack] = []
    var addonSubtitleTracks: [AddonExternalTrack] = []

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
    @State private var command: [String]?
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var controlsLocked = false
    @State private var showUnlockButton = false
    @State private var isScrubbing = false
    @State private var ignorePositionUpdatesUntil = Date.distantPast
    @State private var showSettings = false
    @State private var showTrackPicker = false
    @State private var trackPickerType = "audio"
    @State private var availableTracks: [MPVPlayerTrack] = []

    var body: some View {
        GeometryReader { _ in
            ZStack {
                playerSurface()
                    .zIndex(0)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleControls() }

                if showControls && !controlsLocked {
                    controlsOverlay()
                        .zIndex(10)
                        .allowsHitTesting(true)
                }

                if controlsLocked && showUnlockButton {
                    Button {
                        unlockControls()
                    } label: {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 16)
                    .padding(.trailing, 18)
                    .zIndex(20)
                }

                if isPreparingPlayback && playbackError == nil {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.15)
                        .zIndex(30)
                        .allowsHitTesting(false)
                }

                if let playbackError {
                    errorOverlay(playbackError)
                        .zIndex(40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            OrientationLockCoordinator.playerDidAppear()
            hideParentTabBar(true)
            startInternalPlayback()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation
            if orientation == .landscapeLeft || orientation == .landscapeRight {
                if !isFullscreen { isFullscreen = true }
            } else if orientation == .portrait || orientation == .portraitUpsideDown {
                if isFullscreen { isFullscreen = false }
            }
        }
        .onChange(of: isFullscreen) { fullscreen in
            OrientationLockCoordinator.setPlayerFullscreen(fullscreen)
            hideParentTabBar(true)
            if !controlsLocked {
                showControls = true
                scheduleHide()
            }
        }
        .sheet(isPresented: $showSettings) {
            PlayerSettingsSheet(sendCommand: sendCommand)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTrackPicker) {
            TrackPickerSheet(
                type: trackPickerType,
                tracks: trackOptionsForPicker,
                onSelect: { track in
                    guard !track.title.isEmpty || !track.language.isEmpty else { return }
                    let propertyName = trackPickerType == "audio" ? "aid" : "sid"
                    sendCommand(["set", propertyName, String(track.id)])
                    showTrackPicker = false
                }
            )
        }
        .onDisappear {
            hideControlsTask?.cancel()
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            OrientationLockCoordinator.setPlayerFullscreen(false)
            hideParentTabBar(false)
        }
    }

    private var trackOptionsForPicker: [MPVPlayerTrack] {
        availableTracks.filter { $0.type == trackPickerType }
    }

    private func toggleControls() {
        guard playbackError == nil else { return }
        if controlsLocked {
            // While locked, a tap only reveals/hides the unlock button; it never unlocks.
            withAnimation(.easeInOut(duration: 0.18)) { showUnlockButton.toggle() }
            if showUnlockButton { scheduleHide() } else { hideControlsTask?.cancel() }
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) { showControls.toggle() }
        if showControls { scheduleHide() } else { hideControlsTask?.cancel() }
    }

    private func lockControls() {
        hideControlsTask?.cancel()
        controlsLocked = true
        withAnimation(.easeInOut(duration: 0.18)) {
            showControls = false
            showUnlockButton = true
        }
        scheduleHide()
    }

    private func unlockControls() {
        controlsLocked = false
        showUnlockButton = false
        showControls = true
        scheduleHide()
    }

    private func openTrackPicker(for type: String) {
        trackPickerType = type
        showTrackPicker = true
    }

    private func playerSurface() -> some View {
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
                if !isScrubbing && Date() >= ignorePositionUpdatesUntil { position = time }
                duration = total
                isPlaying = !paused
                if total > 0 { isPreparingPlayback = false }
            },
            onTracks: { tracks in
                availableTracks = tracks
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .allowsHitTesting(true)
    }

    private func controlsOverlay() -> some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.18), value: showControls)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close player")

            if !isFullscreen {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline.weight(.semibold)).lineLimit(1)
                    Text(playbackDiagnostics)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button { isFullscreen.toggle() } label: {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFullscreen ? "Exit fullscreen" : "Enter fullscreen")

            Button {
                lockControls()
            } label: {
                Image(systemName: "lock.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lock controls")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private var centerControls: some View {
        HStack(spacing: 46) {
            seekButton(seconds: -10)
            Button {
                sendCommand(["cycle", "pause"])
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
                Text(formatTime(position)).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.86))
                Slider(
                    value: Binding(
                        get: { duration > 0 ? min(position, duration) : 0 },
                        set: { newValue in
                            guard duration > 0 else { return }
                            position = newValue
                        }
                    ),
                    in: 0...max(duration, 1),
                    onEditingChanged: { editing in
                        if editing {
                            isScrubbing = true
                            hideControlsTask?.cancel()
                        } else {
                            if duration > 0 {
                                ignorePositionUpdatesUntil = Date().addingTimeInterval(0.7)
                                sendCommand(["seek", String(position), "absolute"])
                            }
                            isScrubbing = false
                            scheduleHide()
                        }
                    }
                )
                .tint(.white)
                .contentShape(Rectangle())
                Text(formatTime(duration)).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.86))
            }

            HStack(spacing: 22) {
                bottomButton("waveform", "Audio") {
                    openTrackPicker(for: "audio")
                    scheduleHide()
                }
                bottomButton("captions.bubble", "Subtitles") {
                    openTrackPicker(for: "sub")
                    scheduleHide()
                }
                bottomButton(isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", isMuted ? "Unmute" : "Mute") {
                    let nextMuted = !isMuted
                    isMuted = nextMuted
                    sendCommand(["set", "mute", nextMuted ? "yes" : "no"])
                    scheduleHide()
                }
                bottomButton("gearshape", "Settings") { showSettings = true }
                Spacer()
                Text("Shinji").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private func seekButton(seconds: Int) -> some View {
        Button {
            sendCommand(["seek", String(seconds), "relative"])
            if duration > 0 {
                position = max(0, min(duration, position + Double(seconds)))
                ignorePositionUpdatesUntil = Date().addingTimeInterval(0.7)
            }
            scheduleHide()
        } label: {
            ZStack {
                Image(systemName: seconds < 0 ? "gobackward" : "goforward")
                    .font(.system(size: 24, weight: .semibold))
                Text("10").font(.system(size: 8, weight: .bold)).offset(y: 1)
            }
            .frame(width: 54, height: 54)
            .background(.black.opacity(0.3), in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func bottomButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title)
            Text("Couldn't play this stream").font(.headline)
            Text(message).font(.footnote).foregroundStyle(.white.opacity(0.72)).multilineTextAlignment(.center)
            Button("Try Again") { startInternalPlayback(reloadStream: true) }.buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: 430)
        .background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
        .padding(24)
    }

    private func startInternalPlayback(reloadStream: Bool = false) {
        playbackError = nil
        isPreparingPlayback = true
        playbackDiagnostics = "Loading…"
        position = 0
        duration = 0
        showControls = true
        controlsLocked = false
        showUnlockButton = false
        isScrubbing = false
        availableTracks = []
        if reloadStream {
            sendCommand(["loadfile", url.absoluteString, "replace"])
        } else {
            command = nil
            commandID += 1
        }
        scheduleHide()
        PlaybackAudio.configureToMixWithOtherAudio()
    }

    private func sendCommand(_ value: [String]) {
        command = value
        commandID += 1
    }

    private func scheduleHide() {
        hideControlsTask?.cancel()
        if controlsLocked { showUnlockButton = true } else { showControls = true }
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !isScrubbing else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    if controlsLocked { showUnlockButton = false } else { showControls = false }
                }
            }
        }
    }

    private func hideParentTabBar(_ hidden: Bool) {
        DispatchQueue.main.async {
            guard let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first,
                let tabBarController = root.firstTabBarController() else { return }
            tabBarController.tabBar.isHidden = hidden
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}

private struct PlayerSettingsSheet: View {
    let sendCommand: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Video") {
                    Button("Fit") { sendCommand(["set", "video-unscaled", "no"]); dismiss() }
                    Button("Original Size") { sendCommand(["set", "video-unscaled", "yes"]); dismiss() }
                    Button("Reset Video Zoom") { sendCommand(["set", "video-zoom", "0"]); dismiss() }
                }
                Section("Playback") {
                    Button("Normal Speed") { sendCommand(["set", "speed", "1"]); dismiss() }
                    Button("1.25×") { sendCommand(["set", "speed", "1.25"]); dismiss() }
                    Button("1.5×") { sendCommand(["set", "speed", "1.5"]); dismiss() }
                    Button("2×") { sendCommand(["set", "speed", "2"]); dismiss() }
                }
            }
            .navigationTitle("Player Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

private struct TrackPickerSheet: View {
    let type: String
    let tracks: [MPVPlayerTrack]
    let onSelect: (MPVPlayerTrack) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if tracks.isEmpty {
                    Section {
                        Text(type == "audio" ? "No audio tracks are available for this stream." : "No subtitle tracks are available for this stream.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(tracks) { track in
                        Button {
                            onSelect(track)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title.isEmpty ? (track.language.isEmpty ? "Track \(track.id)" : track.language.uppercased()) : track.title)
                                        .font(.body)
                                    if !track.language.isEmpty {
                                        Text(track.language.uppercased())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if track.isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(type == "audio" ? "Audio Tracks" : "Subtitle Tracks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private extension UIViewController {
    func firstTabBarController() -> UITabBarController? {
        if let tab = self as? UITabBarController { return tab }
        for child in children {
            if let tab = child.firstTabBarController() { return tab }
        }
        if let presented = presentedViewController, let tab = presented.firstTabBarController() { return tab }
        return nil
    }
}
