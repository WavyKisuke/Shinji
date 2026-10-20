from pathlib import Path


# CI source repair for known generated/escaped Swift fragments. Keep this
# idempotent so repeated builds always converge to compilable source.

unified = Path("Shinji/Views/UnifiedLibraryView.swift")
text = unified.read_text(encoding="utf-8")

text = text.replace(
    '        let text = "\\(item.name) \\(item.description ?? \\\"\\\")"',
    '        let text = item.name + " " + (item.description ?? "")',
)

# The "For You" branch used to render the same More shelf a second time.
duplicate_more = '''                    if selectedFilter == "For You" {
                        shelfSection(kind == .movies ? "More Movies" : "More TV Shows", items: moreItems)
                    }
'''
text = text.replace(duplicate_more, "", 1)
unified.write_text(text, encoding="utf-8")

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
mpv.write_text(mpv_text, encoding="utf-8")

print("CI source repairs applied.")
