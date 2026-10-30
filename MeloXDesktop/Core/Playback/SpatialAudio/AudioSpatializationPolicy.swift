import AVFoundation

@MainActor
enum AudioSpatializationPolicy {
    static func apply(_ mode: SpatialAudioMode, to deck: AudioPlaybackDeck) {
        let isEnabled = switch mode {
        case .automatic: true
        case .multichannelOnly: deck.channelCount > 2
        case .disabled: false
        }
        deck.setSpatializationEnabled(isEnabled)
    }
}
