import AVFoundation

enum PlaybackAudio {
    static func configureToMixWithOtherAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Best effort: playback can still proceed if audio mixing is unavailable.
        }
    }
}
