import AVFoundation
import CallKit

enum AudioPlaybackMixMode: Equatable {
    case exclusive
    case mixWithOthers
}

@MainActor
enum AudioPlaybackSessionConfigurator {
    /// Scheme 1: stay mixable for the whole session.
    static var preferredMixMode: AudioPlaybackMixMode = .exclusive

    /// Scheme 3: temporarily mixable after another app interrupted us.
    static var isTemporarilyMixing = false

    private static var isApplyingConfiguration = false
    private static var ignoreInterruptionsUntil = Date.distantPast
    private static let callObserver = CXCallObserver()

    static var effectiveMixMode: AudioPlaybackMixMode {
        if preferredMixMode == .mixWithOthers || isTemporarilyMixing {
            return .mixWithOthers
        }
        return .exclusive
    }

    static var shouldIgnoreInterruption: Bool {
        isApplyingConfiguration || Date.now < ignoreInterruptionsUntil
    }

    static var hasActivePhoneCall: Bool {
        callObserver.calls.contains { !$0.hasEnded }
    }

    static func activate() throws {
        let session = AVAudioSession.sharedInstance()
        if session.category == .playAndRecord {
            return
        }

        let mixMode = effectiveMixMode
        let options: AVAudioSession.CategoryOptions =
            mixMode == .mixWithOthers ? [.mixWithOthers] : []
        let needsCategory =
            session.category != .playback
            || session.mode != .default
            || session.categoryOptions != options

        isApplyingConfiguration = true
        ignoreInterruptionsUntil = Date.now.addingTimeInterval(0.6)
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
