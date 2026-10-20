from pathlib import Path

player = Path("Shinji/Views/PlayerView.swift")
text = player.read_text(encoding="utf-8")
text = text.replace('["cycle", "aid"]', '["cycle", "audio"]')
text = text.replace('["cycle", "sid"]', '["cycle", "sub"]')
text = text.replace('sendCommand(["cycle", "pause"])', 'sendCommand(["set", "pause", isPlaying ? "yes" : "no"])')

if 'showPlaybackSpeed' not in text:
    text = text.replace('    @State private var showSettings = false\n', '    @State private var showSettings = false\n    @State private var showPlaybackSpeed = false\n', 1)
    text = text.replace('        .sheet(isPresented: $showSettings) {\n', '''        .sheet(isPresented: $showPlaybackSpeed) {
            PlaybackSpeedSheet(sendCommand: sendCommand)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
''', 1)
    text = text.replace('                bottomButton("gearshape", "Settings") { showSettings = true }\n', '''                bottomButton("speedometer", "Playback Speed") {
                    showPlaybackSpeed = true
                }
                bottomButton("gearshape", "Settings") { showSettings = true }
''', 1)
    marker = '\nprivate struct PlayerSettingsSheet: View {'
    speed_sheet = '''

private struct PlaybackSpeedSheet: View {
    let sendCommand: ([String]) -> Void
    @Environment(\\.dismiss) private var dismiss
    private let speeds: [(String, String)] = [
        ("0.5×", "0.5"), ("0.75×", "0.75"), ("Normal", "1"),
        ("1.25×", "1.25"), ("1.5×", "1.5"), ("1.75×", "1.75"), ("2×", "2")
    ]
    var body: some View {
        NavigationStack {
            List {
                ForEach(speeds, id: \\.1) { speed in
                    Button(speed.0) {
                        sendCommand(["set", "speed", speed.1])
                        dismiss()
                    }
                }
            }
            .navigationTitle("Playback Speed")
        }
    }
}
'''
    if marker in text:
        text = text.replace(marker, speed_sheet + 'private struct PlayerSettingsSheet: View {', 1)
player.write_text(text, encoding="utf-8")

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
        defer { for pointer in owned { free(pointer) } }
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
