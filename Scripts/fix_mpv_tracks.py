from pathlib import Path

path = Path("Shinji/Views/MPVPlayerSurface.swift")
m = path.read_text(encoding="utf-8")

if "var onTracks: ([MPVPlayerTrack]) -> Void = { _ in }" not in m:
    m = m.replace(
        "    var onPlaybackUpdate: (Double, Double, Bool) -> Void = { _, _, _ in }\n",
        "    var onPlaybackUpdate: (Double, Double, Bool) -> Void = { _, _, _ in }\n    var onTracks: ([MPVPlayerTrack]) -> Void = { _ in }\n    var addonAudioTracks: [AddonExternalTrack] = []\n    var addonSubtitleTracks: [AddonExternalTrack] = []\n",
        1,
    )
else:
    if "var addonAudioTracks: [AddonExternalTrack] = []" not in m:
        m = m.replace("    var onTracks: ([MPVPlayerTrack]) -> Void = { _ in }\n", "    var onTracks: ([MPVPlayerTrack]) -> Void = { _ in }\n    var addonAudioTracks: [AddonExternalTrack] = []\n    var addonSubtitleTracks: [AddonExternalTrack] = []\n", 1)

m = m.replace(
    "        player.onPlaybackUpdate = onPlaybackUpdate\n        player.onTracks = onTracks\n        context.coordinator.player = player",
    "        player.onPlaybackUpdate = onPlaybackUpdate\n        player.onTracks = onTracks\n        player.addonAudioTracks = addonAudioTracks\n        player.addonSubtitleTracks = addonSubtitleTracks\n        context.coordinator.player = player",
    1,
)
m = m.replace(
    "        player.onPlaybackUpdate = onPlaybackUpdate\n        player.onTracks = onTracks\n        player.setMuted(muted)",
    "        player.onPlaybackUpdate = onPlaybackUpdate\n        player.onTracks = onTracks\n        player.addonAudioTracks = addonAudioTracks\n        player.addonSubtitleTracks = addonSubtitleTracks\n        player.setMuted(muted)",
    1,
)

if "var addonAudioTracks: [AddonExternalTrack] = []" not in m.split("final class MPVMetalViewController", 1)[1]:
    m = m.replace(
        "    var onTracks: (([MPVPlayerTrack]) -> Void)?\n",
        "    var onTracks: (([MPVPlayerTrack]) -> Void)?\n    var addonAudioTracks: [AddonExternalTrack] = []\n    var addonSubtitleTracks: [AddonExternalTrack] = []\n",
        1,
    )

old_loaded = '''                case MPV_EVENT_FILE_LOADED:
                    self.publishStatus("Stream loaded")
                    self.publishTracks(handle)
                    self.publishPlaybackState(handle)
'''
new_loaded = '''                case MPV_EVENT_FILE_LOADED:
                    self.publishStatus("Stream loaded")
                    self.addAddonTracks(handle)
                    self.refreshTracksSoon(handle)
                    self.publishPlaybackState(handle)
'''
if old_loaded in m:
    m = m.replace(old_loaded, new_loaded, 1)

if "private func addAddonTracks(_ handle: OpaquePointer)" not in m:
    marker = "    private func publishPlaybackState(_ handle: OpaquePointer) {"
    method = '''    private func addAddonTracks(_ handle: OpaquePointer) {
        for track in addonAudioTracks {
            execute(["audio-add", track.url.absoluteString, "auto", track.title], on: handle)
        }
        for track in addonSubtitleTracks {
            execute(["sub-add", track.url.absoluteString, "auto", track.title], on: handle)
        }
    }

'''
    if marker in m:
        m = m.replace(marker, method + marker, 1)

m = m.replace(
    '        if arguments.first == "loadfile" || arguments.contains("aid") || arguments.contains("sid") {',
    '        if arguments.first == "loadfile" || arguments.contains("aid") || arguments.contains("sid") || arguments.first == "audio-add" || arguments.first == "sub-add" {',
    1,
)

path.write_text(m, encoding="utf-8")
print("Patched MPV addon track bridge")