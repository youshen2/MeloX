import Foundation
import Observation

@MainActor
@Observable
final class SkylineLyricsPreferences {
    private enum Key {
        static let currentLyricFontSize = "skylineCurrentLyricFontSize"
        static let nextLyricFontSize = "skylineNextLyricFontSize"
        static let currentLyricsSpacing = "skylineCurrentLyricsSpacing"
        static let currentLyricsWidth = "skylineCurrentLyricsWidth"
        static let nextLyricOpacity = "skylineNextLyricOpacity"
        static let ambientFontSize = "skylineAmbientFontSize"
        static let ambientMaximumCharacters = "skylineAmbientMaximumCharacters"
        static let ambientOpacity = "skylineAmbientOpacity"
        static let ambientBlur = "skylineAmbientBlur"
        static let ambientPositionRandomness = "skylineAmbientPositionRandomness"
        static let ambientMaximumTilt = "skylineAmbientMaximumTilt"
        static let ambientDrift = "skylineAmbientDrift"
    }

    private enum Default {
        static let currentLyricFontSize = 54.0
        static let nextLyricFontSize = 24.0
        static let currentLyricsSpacing = 14.0
        static let currentLyricsWidth = 0.64
        static let nextLyricOpacity = 0.48
        static let ambientFontSize = 44.0
        static let ambientMaximumCharacters = 2
        static let ambientOpacity = 1.0
        static let ambientBlur = 1.0
        static let ambientPositionRandomness = 1.0
        static let ambientMaximumTilt = 8.0
        static let ambientDrift = 1.0
    }

    var currentLyricFontSize: Double {
        didSet { defaults.set(currentLyricFontSize, forKey: Key.currentLyricFontSize) }
    }

    var nextLyricFontSize: Double {
        didSet { defaults.set(nextLyricFontSize, forKey: Key.nextLyricFontSize) }
    }

    var currentLyricsSpacing: Double {
        didSet { defaults.set(currentLyricsSpacing, forKey: Key.currentLyricsSpacing) }
    }

    var currentLyricsWidth: Double {
        didSet { defaults.set(currentLyricsWidth, forKey: Key.currentLyricsWidth) }
    }

    var nextLyricOpacity: Double {
        didSet { defaults.set(nextLyricOpacity, forKey: Key.nextLyricOpacity) }
    }

    var ambientFontSize: Double {
        didSet { defaults.set(ambientFontSize, forKey: Key.ambientFontSize) }
    }

    var ambientMaximumCharacters: Int {
        didSet {
            defaults.set(
                ambientMaximumCharacters,
                forKey: Key.ambientMaximumCharacters
            )
        }
    }

    var ambientOpacity: Double {
        didSet { defaults.set(ambientOpacity, forKey: Key.ambientOpacity) }
    }

    var ambientBlur: Double {
        didSet { defaults.set(ambientBlur, forKey: Key.ambientBlur) }
    }

    var ambientPositionRandomness: Double {
        didSet {
            defaults.set(
                ambientPositionRandomness,
                forKey: Key.ambientPositionRandomness
            )
        }
    }

    var ambientMaximumTilt: Double {
        didSet { defaults.set(ambientMaximumTilt, forKey: Key.ambientMaximumTilt) }
    }

    var ambientDrift: Double {
        didSet { defaults.set(ambientDrift, forKey: Key.ambientDrift) }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currentLyricFontSize = defaults.object(forKey: Key.currentLyricFontSize) as? Double
            ?? Default.currentLyricFontSize
        nextLyricFontSize = defaults.object(forKey: Key.nextLyricFontSize) as? Double
            ?? Default.nextLyricFontSize
        currentLyricsSpacing = defaults.object(forKey: Key.currentLyricsSpacing) as? Double
            ?? Default.currentLyricsSpacing
        currentLyricsWidth = defaults.object(forKey: Key.currentLyricsWidth) as? Double
            ?? Default.currentLyricsWidth
        nextLyricOpacity = defaults.object(forKey: Key.nextLyricOpacity) as? Double
            ?? Default.nextLyricOpacity
        ambientFontSize = defaults.object(forKey: Key.ambientFontSize) as? Double
            ?? Default.ambientFontSize
        ambientMaximumCharacters = min(
            max(
                defaults.object(forKey: Key.ambientMaximumCharacters) as? Int
                    ?? Default.ambientMaximumCharacters,
                1
            ),
            2
        )
        ambientOpacity = defaults.object(forKey: Key.ambientOpacity) as? Double
            ?? Default.ambientOpacity
        ambientBlur = defaults.object(forKey: Key.ambientBlur) as? Double
            ?? Default.ambientBlur
        ambientPositionRandomness = defaults.object(
            forKey: Key.ambientPositionRandomness
        ) as? Double ?? Default.ambientPositionRandomness
        ambientMaximumTilt = defaults.object(forKey: Key.ambientMaximumTilt) as? Double
            ?? Default.ambientMaximumTilt
        ambientDrift = defaults.object(forKey: Key.ambientDrift) as? Double
            ?? Default.ambientDrift
    }

    func reset() {
        currentLyricFontSize = Default.currentLyricFontSize
        nextLyricFontSize = Default.nextLyricFontSize
        currentLyricsSpacing = Default.currentLyricsSpacing
        currentLyricsWidth = Default.currentLyricsWidth
        nextLyricOpacity = Default.nextLyricOpacity
        ambientFontSize = Default.ambientFontSize
        ambientMaximumCharacters = Default.ambientMaximumCharacters
        ambientOpacity = Default.ambientOpacity
        ambientBlur = Default.ambientBlur
        ambientPositionRandomness = Default.ambientPositionRandomness
        ambientMaximumTilt = Default.ambientMaximumTilt
        ambientDrift = Default.ambientDrift
    }
}
