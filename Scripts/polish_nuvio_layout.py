from pathlib import Path
import re

path = Path("Shinji/Views/PlayerView.swift")
p = path.read_text(encoding="utf-8")

# Replace the whole control surface instead of making fragile one-line tweaks.
# This keeps the Nuvio-inspired hierarchy consistent across portrait/landscape:
# compact top toolbar, centered seek/play controls, timeline, then action rail.
new_controls = r'''    private func controlsOverlay() -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    .black.opacity(0.82),
                    .black.opacity(0.18),
                    .clear,
                    .black.opacity(0.12),
                    .black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                centerControls
                    .padding(.bottom, 18)
                Spacer(minLength: 0)
                bottomControls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.18), value: showControls)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.28), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close player")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(playbackDiagnostics)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 7) {
                Text("MPV")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.09), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))

                Button { isFullscreen.toggle() } label: {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFullscreen ? "Exit fullscreen" : "Enter fullscreen")

                Button { lockControls() } label: {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lock controls")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var centerControls: some View {
        HStack(spacing: 30) {
            seekButton(seconds: -10)

            Button {
                sendCommand(["set", "pause", isPlaying ? "yes" : "no"])
                isPlaying.toggle()
                scheduleHide()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 29, weight: .bold))
                    .frame(width: 78, height: 78)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.13), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.38), radius: 22, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            seekButton(seconds: 10)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 9) {
                Text(formatTime(position))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(minWidth: 42, alignment: .leading)

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
                .frame(minHeight: 30)

                Text(formatTime(duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(minWidth: 42, alignment: .trailing)
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
                    bottomButton("gauge.with.dots.needle.33percent", "Speed") {
                        showSettings = true
                    }
                    bottomButton("gearshape.fill", "Settings") {
                        showSettings = true
                    }
                }
                .padding(.horizontal, 18)
            }
            .frame(height: 54)
        }
        .padding(.top, 7)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.18), .black.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
                    .font(.system(size: 21, weight: .semibold))
                Text("10")
                    .font(.system(size: 8, weight: .bold))
                    .offset(y: 1)
            }
            .frame(width: 62, height: 62)
            .background(.black.opacity(0.22), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func bottomButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.94))
            .frame(minWidth: 74, height: 42)
            .padding(.horizontal, 7)
            .background(.white.opacity(0.065), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

'''

start = p.index("    private func controlsOverlay() -> some View {")
end = p.index("    private func errorOverlay(_ message: String) -> some View {")
p = p[:start] + new_controls + p[end:]

# Never show Nuvio's name in Shinji; use the visual language, not the branding.
p = p.replace('Text("nuvio")', 'Text("STREAM")')

path.write_text(p, encoding="utf-8")
