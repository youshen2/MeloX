import AVFoundation

enum AudioPlaybackMixMode: Equatable {
    case exclusive
    case mixWithOthers
}

@MainActor
enum AudioPlaybackSessionConfigurator {
    /// When on, the playback session stays mixable so other apps do not interrupt it.
    static var preferredMixMode: AudioPlaybackMixMode = .exclusive

    private static var isApplyingConfiguration = false
    private static var ignoreInterruptionsUntil = Date.distantPast

    static var shouldIgnoreInterruption: Bool {
        isApplyingConfiguration || Date.now < ignoreInterruptionsUntil
    }

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
        if needsCategory {
            // setCategory can post an interruption. Ignore that one and keep playing.
            ignoreInterruptionsUntil = Date.now.addingTimeInterval(0.6)
        }
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
