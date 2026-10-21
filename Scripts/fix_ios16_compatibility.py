from pathlib import Path

path = Path("Shinji/Views/SettingsView.swift")
text = path.read_text(encoding="utf-8")

old = '''                    ContentUnavailableView("No Add-ons", systemImage: "puzzlepiece.extension", description: Text("Add a manifest URL above to connect a catalog or stream source."))'''
new = '''                    VStack(spacing: 10) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("No Add-ons")
                            .font(.headline)
                        Text("Add a manifest URL above to connect a catalog or stream source.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)'''

if old in text:
    text = text.replace(old, new)
path.write_text(text, encoding="utf-8")

# Final CI normalization: MPV's language property is optional, while the
# player track model exposes a displayable String. Keep the generated bridge
# stable even if an earlier repair script regenerates this section.
mpv_path = Path("Shinji/Views/MPVPlayerSurface.swift")
mpv = mpv_path.read_text(encoding="utf-8")
mpv = mpv.replace(
    'let language = stringProperty(handle, "\\(prefix)/lang")\n',
    'let language = stringProperty(handle, "\\(prefix)/lang") ?? ""\n',
)
mpv = mpv.replace('let language: String?\n', 'let language: String\n')
mpv_path.write_text(mpv, encoding="utf-8")

print("iOS 16 compatibility and MPV track bridge normalization applied.")
