from pathlib import Path
import re

path = Path("Shinji/Views/PlayerView.swift")
p = path.read_text(encoding="utf-8")

# The player layout may already have the responsive landscape-aware implementation.
# Keep this CI repair idempotent and fix the portrait top-bar overflow that could
# push the fullscreen button off the right edge of the screen.
if "private func controlsOverlay(isLandscape: Bool) -> some View" in p:
    p = p.replace('Text("nuvio")', 'Text("STREAM")')

    new_top_bar = '''    private func topBar(isLandscape: Bool) -> some View {
        HStack(spacing: isLandscape ? 10 : 8) {
            playerCircleButton("chevron.down", size: isLandscape ? 38 : 42) { dismiss() }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: isLandscape ? 16 : 18, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(playbackDiagnostics)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minWidth: 0, alignment: .leading)
            .layoutPriority(-1)

            HStack(spacing: isLandscape ? 10 : 8) {
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
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, isLandscape ? 24 : 18)
        .padding(.top, isLandscape ? 16 : 12)
    }
'''

    p, count = re.subn(
        r'    private func topBar\(isLandscape: Bool\) -> some View \{.*?\n    \}\n\n    private func centerControls',
        new_top_bar + '\n    private func centerControls',
        p,
        count=1,
        flags=re.S,
    )
    if count != 1:
        raise SystemExit("topBar replacement target not found")

path.write_text(p, encoding="utf-8")
