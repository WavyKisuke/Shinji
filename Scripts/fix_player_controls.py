from pathlib import Path

# Repair player commands at build time so every IPA gets working MPV controls.
player = Path("Shinji/Views/PlayerView.swift")
text = player.read_text(encoding="utf-8")
text = text.replace('["cycle", "audio"]', '["cycle", "aid"]')
text = text.replace('["cycle", "sub"]', '["cycle", "sid"]')
text = text.replace('sendCommand(["cycle", "pause"])', 'sendCommand(["set", "pause", isPlaying ? "yes" : "no"])')
player.write_text(text, encoding="utf-8")

# Make command execution use a stable, null-terminated C argv buffer.
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

        let result = cargs.withUnsafeBufferPointer { buffer in
            mpv_command(handle, buffer.baseAddress)
        }
        if result < 0 {
            publishError("MPV command failed: \\(String(cString: mpv_error_string(result)))")
        }
    }
'''
if old in mpv_text:
    mpv_text = mpv_text.replace(old, new, 1)
mpv_text = mpv_text.replace('["cycle", "audio"]', '["cycle", "aid"]')
mpv_text = mpv_text.replace('["cycle", "sub"]', '["cycle", "sid"]')
mpv.write_text(mpv_text, encoding="utf-8")
