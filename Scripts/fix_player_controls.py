from pathlib import Path

# Repair player commands at build time so every IPA gets working MPV controls.
player = Path("Shinji/Views/PlayerView.swift")
text = player.read_text(encoding="utf-8")

# mpv's documented track-cycling commands are `cycle audio` and `cycle sub`.
# Do not convert these to `cycle aid`/`cycle sid`: aid/sid are track-selection
# properties, while audio/sub are the input commands that cycle available tracks.
text = text.replace('["cycle", "aid"]', '["cycle", "audio"]')
text = text.replace('["cycle", "sid"]', '["cycle", "sub"]')

# Use an explicit pause property update so the command is deterministic.
text = text.replace(
    'sendCommand(["cycle", "pause"])',
    'sendCommand(["set", "pause", isPlaying ? "yes" : "no"])'
)

player.write_text(text, encoding="utf-8")

# Keep the libmpv argv buffer mutable. MPVKit exposes mpv_command as taking
# UnsafeMutablePointer<UnsafePointer<CChar>?> on this toolchain.
mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
mpv_text = mpv.read_text(encoding="utf-8")
old = '''    private func execute(_ arguments: [String], on handle: OpaquePointer) {
        var owned: [UnsafeMutablePointer<CChar>] = arguments.map { strdup($0) }
        defer {
            for pointer in owned {
                free(pointer)
            }
        }

        var cargs: [UnsafePointer<CChar>?] = owned.map { UnsafePointer($0) }
        cargs.append(nil)

        let result = cargs.withUnsafeMutableBufferPointer { buffer in
            mpv_command(handle, buffer.baseAddress)
        }
        if result < 0 {
            publishError("MPV command failed: \\(String(cString: mpv_error_string(result)))")
        }
    }
'''
new = '''    private func execute(_ arguments: [String], on handle: OpaquePointer) {
        let owned: [UnsafeMutablePointer<CChar>] = arguments.compactMap { strdup($0) }
        defer {
            for pointer in owned { free(pointer) }
        }

        var cargs: [UnsafePointer<CChar>?] = owned.map { UnsafePointer($0) }
        cargs.append(nil)

        let result = cargs.withUnsafeMutableBufferPointer { buffer in
            mpv_command(handle, buffer.baseAddress)
        }
        if result < 0 {
            publishError("MPV command failed: \\(String(cString: mpv_error_string(result)))")
        }
    }
'''
if old in mpv_text:
    mpv_text = mpv_text.replace(old, new, 1)
mpv_text = mpv_text.replace('["cycle", "aid"]', '["cycle", "audio"]')
mpv_text = mpv_text.replace('["cycle", "sid"]', '["cycle", "sub"]')
mpv.write_text(mpv_text, encoding="utf-8")
