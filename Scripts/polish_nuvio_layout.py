from pathlib import Path

path = Path("Shinji/Views/PlayerView.swift")
p = path.read_text(encoding="utf-8")

# Nuvio-style breathing room: keep the center controls visually centered above
# the timeline instead of letting the lower action row pull them downward.
p = p.replace(
    "VStack(spacing: 0) {\n                topBar\n                Spacer(minLength: 0)\n                centerControls\n                Spacer(minLength: 0)\n                bottomControls\n            }",
    "VStack(spacing: 0) {\n                topBar\n                Spacer(minLength: 0)\n                centerControls\n                    .padding(.bottom, 28)\n                Spacer(minLength: 0)\n                bottomControls\n            }",
    1,
)

# Larger, cleaner center controls on phones and landscape screens.
p = p.replace("HStack(spacing: 28) {", "HStack(spacing: 34) {", 1)
p = p.replace(".frame(width: 72, height: 72)", ".frame(width: 80, height: 80)", 1)
p = p.replace(".font(.system(size: 30, weight: .bold))", ".font(.system(size: 32, weight: .bold))", 1)
p = p.replace(".frame(width: 58, height: 58)", ".frame(width: 62, height: 62)", 1)

# Give the timeline a more prominent touch target while retaining the compact visual bar.
p = p.replace(".contentShape(Rectangle())\n                    Text(formatTime(duration))", ".contentShape(Rectangle())\n                    .frame(minHeight: 30)\n                    Text(formatTime(duration))", 1)

# Keep the action row clear of the home tab area and device safe area.
p = p.replace(".padding(.bottom, 16)\n        }\n        .padding(.top, 8)", ".padding(.bottom, 22)\n        }\n        .padding(.top, 8)", 1)

# Nuvio's player uses a quiet metadata/status line rather than a large diagnostic block.
p = p.replace(
    ".font(.caption2)\n                        .foregroundStyle(.white.opacity(0.7))",
    ".font(.system(size: 11, weight: .medium, design: .rounded))\n                        .foregroundStyle(.white.opacity(0.58))",
    1,
)

# The visible branding pill is unnecessary UI chrome; use a neutral stream badge.
p = p.replace('Text("nuvio")', 'Text("STREAM")', 1)

path.write_text(p, encoding="utf-8")
