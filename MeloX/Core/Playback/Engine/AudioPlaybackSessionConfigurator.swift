import AVFoundation

enum AudioPlaybackMixMode: Equatable {
    case exclusive
    case mixWithOthers
}

@MainActor
enum AudioPlaybackSessionConfigurator {
    /// When on, the playback session stays mixable so other apps do not interrupt it.
    static var preferredMixMode: AudioPlaybackMixMode = .exclusive

    private(set) static var isApplyingConfiguration = false

    static func activate() throws {
        let session = AVAudioSession.sharedInstance()
        if session.category == .playAndRecord {
            return
        }

        let options: AVAudioSession.CategoryOptions =
            preferredMixMode == .mixWithOthers ? [.mixWithOthers] : []
        let needsCategory =
            session.category != .playback
            || session.mode != .default
            || session.categoryOptions != options

        isApplyingConfiguration = true
        defer { isApplyingConfiguration = false }

        if needsCategory {
            try session.setCategory(
                .playback,
                mode: .default,
                options: options
            )
        }
        if !session.supportsMultichannelContent {
            try? session.setSupportsMultichannelContent(true)
        }
        if !session.prefersInterruptionOnRouteDisconnect {
            try session.setPrefersInterruptionOnRouteDisconnect(true)
        }
        try session.setActive(true)
    }
}
