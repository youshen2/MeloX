import Foundation
import Observation

enum SongRecognitionDuration: Int, CaseIterable, Identifiable {
    case quick = 3
    case balanced = 6
    case extended = 9
    case continuous = 0

    var id: Int { rawValue }

    var maximumDuration: Int? {
        isContinuous ? nil : rawValue
    }

    var isContinuous: Bool {
        self == .continuous
    }

    var title: String {
        switch self {
        case .quick:
            L10n.format("ui.common.seconds", 3)
        case .balanced:
            L10n.format("ui.common.seconds", 6)
        case .extended:
            L10n.format("ui.common.seconds", 9)
        case .continuous:
            L10n.string("ui.settings.recognition.duration.continuous")
        }
    }

    var detail: String {
        switch self {
        case .quick:
            L10n.string("ui.settings.recognition.duration.quick.detail")
        case .balanced:
            L10n.string("ui.common.recommended")
        case .extended:
            L10n.string("ui.settings.recognition.duration.extended.detail")
        case .continuous:
            L10n.string("ui.settings.recognition.duration.continuous.detail")
        }
    }
}

@MainActor
@Observable
final class SongRecognitionPreferences {
    private enum Key {
        static let duration = "songRecognition.duration"
        static let audioSource = "songRecognition.audioSource"
    }

    var duration: SongRecognitionDuration {
        didSet {
            defaults.set(duration.rawValue, forKey: Key.duration)
        }
    }

    var audioSource: SongRecognitionAudioSource {
        didSet {
            defaults.set(audioSource.rawValue, forKey: Key.audioSource)
        }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        audioSource = defaults.string(forKey: Key.audioSource)
            .flatMap(SongRecognitionAudioSource.init(rawValue:)) ?? .microphone
        if defaults.object(forKey: Key.duration) != nil {
            duration =
                SongRecognitionDuration(
                    rawValue: defaults.integer(
                        forKey: Key.duration
                    )
                )
                ?? .balanced
        } else {
            duration = .balanced
        }
    }
}
