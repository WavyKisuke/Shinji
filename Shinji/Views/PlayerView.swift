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
    @State private var showSpeedPicker = false
    @State private var playbackSpeed = 1.0

    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            ZStack {
                Color.black.ignoresSafeArea()

                if let posterURL {
                    AsyncImage(url: posterURL) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                                .blur(radius: landscape ? 24 : 18)
                                .opacity(0.24)
                        } else {
                            Color.clear
                        }
                    }
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .allowsHitTesting(false)
                }

                playerSurface()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleControls() }
                    .zIndex(1)

                if showControls && !controlsLocked {
                    controlsOverlay(isLandscape: landscape)
                        .zIndex(10)
                }

                if controlsLocked && showUnlockButton {
                    Button { unlockControls() } label: {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.58), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, landscape ? 18 : 52)
                    .padding(.trailing, landscape ? 22 : 18)
                    .zIndex(20)
                }

                if isPreparingPlayback && playbackError == nil {
                    VStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Preparing stream")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .zIndex(30)
                    .allowsHitTesting(false)
                }

                if let playbackError {
                    errorOverlay(playbackError).zIndex(40)
                }
            }
            .ignoresSafeArea()
            .onChange(of: proxy.size) { newSize in
                let nowLandscape = newSize.width > newSize.height
                if nowLandscape != isFullscreen {
                    isFullscreen = nowLandscape
                }
            }
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
            switch orientation {
            case .landscapeLeft, .landscapeRight:
                if !isFullscreen { isFullscreen = true }
            case .portrait, .portraitUpsideDown:
                if isFullscreen { isFullscreen = false }
            default:
                break
            }
        }
        .onChange(of: isFullscreen) { fullscreen in
            OrientationLockCoordinator.setPlayerFullscreen(fullscreen)
            hideParentTabBar(true)
            showControls = true
            if !controlsLocked { scheduleHide() }
        }
        .sheet(isPresented: $showSettings) {
            PlayerSettingsSheet(sendCommand: sendCommand)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSpeedPicker) {
            PlaybackSpeedSheet(speed: $playbackSpeed) { speed in
                playbackSpeed = speed
                sendCommand(["set", "speed", String(speed)])
                showSpeedPicker = false
                scheduleHide()
            }
            .presentationDetents([.fraction(0.42)])
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
                if status.localizedCaseInsensitiveContains("loaded") { isPreparingPlayback = false }
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
            onTracks: { tracks in availableTracks = tracks }
        )
        .background(.black)
        .allowsHitTesting(true)
    }

    private func controlsOverlay(isLandscape: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.84), .clear, .clear, .black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar(isLandscape: isLandscape)
                Spacer(minLength: 0)
                centerControls(isLandscape: isLandscape)
                Spacer(minLength: 0)
                bottomControls(isLandscape: isLandscape)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.18), value: showControls)
    }

    private func topBar(isLandscape: Bool) -> some View {
        HStack(spacing: 12) {
            playerCircleButton("chevron.down", size: isLandscape ? 38 : 42) { dismiss() }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: isLandscape ? 16 : 18, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(playbackDiagnostics)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("HD")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.white.opacity(0.09), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))

            playerCircleButton(
                isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                size: isLandscape ? 38 : 42
            ) { isFullscreen.toggle() }

            playerCircleButton("lock.fill", size: isLandscape ? 38 : 42) { lockControls() }
        }
        .padding(.horizontal, isLandscape ? 24 : 18)
        .padding(.top, isLandscape ? 16 : 12)
    }

    private func centerControls(isLandscape: Bool) -> some View {
        HStack(spacing: isLandscape ? 30 : 34) {
            seekButton(seconds: -10, size: isLandscape ? 54 : 62)

            Button {
                sendCommand(["set", "pause", isPlaying ? "yes" : "no"])
                scheduleHide()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: isLandscape ? 28 : 34, weight: .bold))
                    .frame(width: isLandscape ? 78 : 88, height: isLandscape ? 78 : 88)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.34), radius: 20, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            seekButton(seconds: 10, size: isLandscape ? 54 : 62)
        }
    }

    private func bottomControls(isLandscape: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text(formatTime(position))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.82))

                Slider(
                    value: Binding(
                        get: { duration > 0 ? min(position, duration) : 0 },
                        set: { position = max(0, $0) }
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

                Text(formatTime(duration))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(.horizontal, isLandscape ? 24 : 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    playerAction("waveform", "Audio") {
                        openTrackPicker(for: "audio")
                        scheduleHide()
                    }
                    playerAction("captions.bubble", "Subtitles") {
                        openTrackPicker(for: "sub")
                        scheduleHide()
                    }
                    playerAction("speedometer", String(format: "%.2gx", playbackSpeed)) {
                        showSpeedPicker = true
                        hideControlsTask?.cancel()
                    }
                    playerAction(isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", "Mute") {
                        let nextMuted = !isMuted
                        isMuted = nextMuted
                        sendCommand(["set", "mute", nextMuted ? "yes" : "no"])
                        scheduleHide()
                    }
                    playerAction("gearshape.fill", "Settings") {
                        showSettings = true
                        hideControlsTask?.cancel()
                    }
                    playerAction("lock.fill", "Lock") { lockControls() }
                }
                .padding(.horizontal, isLandscape ? 24 : 18)
                .padding(.bottom, isLandscape ? 12 : 18)
            }
        }
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.16), .black.opacity(0.38)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func playerCircleButton(_ icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: size, height: size)
                .background(.white.opacity(0.07), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func playerAction(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 14, weight: .medium))
                Text(label).font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 13)
            .frame(height: 40)
            .background(.white.opacity(0.075), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.11), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func seekButton(seconds: Int, size: CGFloat) -> some View {
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
                    .font(.system(size: 21, weight: .semibold))
                Text("10")
                    .font(.system(size: 8, weight: .bold))
                    .offset(y: 1)
            }
            .frame(width: size, height: size)
            .background(.white.opacity(0.07), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title)
            Text("Couldn't play this stream").font(.headline)
            Text(message).font(.footnote).foregroundStyle(.white.opacity(0.72)).multilineTextAlignment(.center)
            Button("Try Again") { startInternalPlayback(reloadStream: true) }
                .buttonStyle(.borderedProminent)
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

private struct PlaybackSpeedSheet: View {
    @Binding var speed: Double
    let onSelect: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    private let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            List(speeds, id: \.self) { value in
                Button {
                    speed = value
                    onSelect(value)
                } label: {
                    HStack {
                        Text(String(format: "%.2gx", value))
                        Spacer()
                        if abs(speed - value) < 0.001 { Image(systemName: "checkmark") }
                    }
                }
            }
            .navigationTitle("Playback Speed")
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
                    Text(type == "audio" ? "No audio tracks are available for this stream." : "No subtitle tracks are available for this stream.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tracks) { track in
                        Button {
                            onSelect(track)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title.isEmpty ? (track.language.isEmpty ? "Track \(track.id)" : track.language.uppercased()) : track.title)
                                    if !track.language.isEmpty {
                                        Text(track.language.uppercased()).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if track.isSelected { Image(systemName: "checkmark").foregroundStyle(.blue) }
                            }
                        }
                    }
                }
            }
            .navigationTitle(type == "audio" ? "Audio Tracks" : "Subtitle Tracks")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
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
