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
print("iOS 16 compatibility repair applied.")
