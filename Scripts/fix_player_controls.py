from pathlib import Path
import re

player = Path("Shinji/Views/PlayerView.swift")
text = player.read_text(encoding="utf-8")

# Keep MPV's track-selection commands valid.
text = text.replace('["cycle", "audio"]', '["cycle", "aid"]')
text = text.replace('["cycle", "sub"]', '["cycle", "sid"]')
text = text.replace('sendCommand(["cycle", "pause"])', 'sendCommand(["set", "pause", isPlaying ? "yes" : "no"])')

# The current player owns a single PlaybackSpeedSheet. Older repair logic used
# to inject a second legacy sheet, which caused an invalid redeclaration and an
# initializer mismatch during CI. Remove any legacy injected declaration and
# leave the current binding-based implementation intact.
blocks = list(re.finditer(r'\nprivate struct PlaybackSpeedSheet: View \{', text))
if len(blocks) > 1:
    # Preserve the first declaration; remove later complete declarations.
    for match in reversed(blocks[1:]):
        start = match.start()
        next_marker = text.find('\nprivate struct ', start + 1)
        if next_marker == -1:
            text = text[:start].rstrip() + "\n"
        else:
            text = text[:start] + text[next_marker:]

# Remove the obsolete legacy state if an earlier source revision injected it.
text = re.sub(r'\n\s*@State private var showPlaybackSpeed = false\n', '\n', text)
text = re.sub(r'\n\s*@State private var temporaryDoubleSpeed = false\n', '\n', text)

# Do not add another playback-speed sheet/button here. The responsive Nuvio
# player already exposes exactly one speed control and its sheet.

mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
mpv_text = mpv.read_text(encoding="utf-8")
mpv_text = mpv_text.replace('["cycle", "audio"]', '["cycle", "aid"]')
mpv_text = mpv_text.replace('["cycle", "sub"]', '["cycle", "sid"]')
mpv.write_text(mpv_text, encoding="utf-8")
player.write_text(text, encoding="utf-8")
