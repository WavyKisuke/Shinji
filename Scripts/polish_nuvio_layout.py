from pathlib import Path

path = Path("Shinji/Views/PlayerView.swift")
p = path.read_text(encoding="utf-8")

# The player layout may already have the responsive landscape-aware implementation.
# Keep this CI repair idempotent so it never replaces the current implementation
# with the older parameterless control surface.
if "private func controlsOverlay(isLandscape: Bool) -> some View" in p:
    p = p.replace('Text("nuvio")', 'Text("STREAM")')
    path.write_text(p, encoding="utf-8")
    raise SystemExit(0)

# Legacy source fallback: the dedicated player-repair step owns migration to the
# current control surface. Do not make a second, incompatible rewrite here.
path.write_text(p, encoding="utf-8")
