from pathlib import Path


# CI source repair for known generated/escaped Swift fragments. Keep this
# idempotent so repeated builds always converge to compilable source.

unified = Path("Shinji/Views/UnifiedLibraryView.swift")
text = unified.read_text(encoding="utf-8")

text = text.replace(
    '        let text = "\\(item.name) \\(item.description ?? \\\"\\\")"',
    '        let text = item.name + " " + (item.description ?? "")',
)

# Keep the top filter row focused on content filters. Genre selection lives
# exclusively in the dedicated multi-select genre row below it.
text = text.replace(
    '    private let filters = ["For You", "Popular", "Recently Added", "Action", "Drama"]',
    '    private let filters = ["For You", "Popular", "Recently Added"]',
)

# The "For You" branch used to render the same More shelf a second time.
duplicate_more = '''                    if selectedFilter == "For You" {
                        shelfSection(kind == .movies ? "More Movies" : "More TV Shows", items: moreItems)
                    }
'''
text = text.replace(duplicate_more, "", 1)
unified.write_text(text, encoding="utf-8")

# Keep the MPV command buffer ABI fix in every CI build.
mpv = Path("Shinji/Views/MPVPlayerSurface.swift")
mpv_text = mpv.read_text(encoding="utf-8")
old_execute = '''    private func execute(_ arguments: [String], on handle: OpaquePointer) {
        var cargs: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
        cargs.append(nil)
        defer {
            for pointer in cargs where pointer != nil {
                free(pointer)
            }
        }

        let result = cargs.withUnsafeMutableBufferPointer { buffer in
            mpv_command(handle, buffer.baseAddress)
        }
        if result < 0 {
            publishError("MPV command failed: \\(String(cString: mpv_error_string(result)))")
        }
    }
'''
new_execute = '''    private func execute(_ arguments: [String], on handle: OpaquePointer) {
        var owned: [UnsafeMutablePointer<CChar>] = arguments.map { strdup($0) }
        defer {
            for pointer in owned {
                free(pointer)
            }
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
if old_execute in mpv_text:
    mpv_text = mpv_text.replace(old_execute, new_execute, 1)

# Use MPV's canonical track-selection properties. The old aliases can be
# unreliable with some Libmpv builds, especially for HLS alternate tracks.
mpv_text = mpv_text.replace('["cycle", "audio"]', '["cycle", "aid"]')
mpv_text = mpv_text.replace('["cycle", "sub"]', '["cycle", "sid"]')
mpv.write_text(mpv_text, encoding="utf-8")

# Automatically populate Keep Watching from every MPV playback session.
player = Path("Shinji/Views/PlayerView.swift")
p = player.read_text(encoding="utf-8")
p = p.replace(
    '    var headers: [String: String] = [:]\n',
    '    var headers: [String: String] = [:]\n    @StateObject private var continueStore = ContinueWatchingStore.shared\n',
    1,
)
p = p.replace(
    '    @State private var showSettings = false\n',
    '    @State private var showSettings = false\n    @State private var didResume = false\n    @State private var lastProgressSave = Date.distantPast\n',
    1,
)
p = p.replace(
    '''                if status.localizedCaseInsensitiveContains("loaded") {
                    isPreparingPlayback = false
                }''',
    '''                if status.localizedCaseInsensitiveContains("loaded") {
                    isPreparingPlayback = false
                    if !didResume, let saved = continueStore.item(for: url.absoluteString), saved.position > 5 {
                        didResume = true
                        position = saved.position
                        ignorePositionUpdatesUntil = Date().addingTimeInterval(1.0)
                        sendCommand(["seek", String(saved.position), "absolute"])
                    } else if !didResume {
                        didResume = true
                    }
                }''',
    1,
)
p = p.replace(
    '''                duration = total
                isPlaying = !paused
                if total > 0 { isPreparingPlayback = false }''',
    '''                duration = total
                isPlaying = !paused
                if total > 0 {
                    if Date().timeIntervalSince(lastProgressSave) >= 2 {
                        lastProgressSave = Date()
                        continueStore.record(id: url.absoluteString, title: title, url: url, position: time, duration: total, headers: headers)
                    }
                    isPreparingPlayback = false
                }''',
    1,
)
p = p.replace(
    '''        .onDisappear {
            hideControlsTask?.cancel()''',
    '''        .onDisappear {
            if duration > 0 {
                continueStore.record(id: url.absoluteString, title: title, url: url, position: position, duration: duration, headers: headers)
            }
            hideControlsTask?.cancel()''',
    1,
)
p = p.replace(
    '''        isScrubbing = false
        if reloadStream {''',
    '''        isScrubbing = false
        didResume = false
        lastProgressSave = Date.distantPast
        if reloadStream {''',
    1,
)
player.write_text(p, encoding="utf-8")

print("CI source repairs applied.")
