import Foundation

// Centralizes MPV track property names so the player never falls back to
// unsupported "audio"/"sub" aliases. MPV exposes selectable tracks through
// track-list and the active IDs through aid/sid.
enum PlayerTrackBridge {
    static let audioID = "aid"
    static let subtitleID = "sid"
    static let trackList = "track-list"
}
