import Foundation
import Observation

@MainActor
@Observable
final class SkylineLyricsPreferences {
    private enum Key {
        static let keepsScreenAwake = "skylineKeepsScreenAwake"
        static let currentLyricFontSize = "skylineCurrentLyricFontSize"
        static let currentLyricMaximumScale = "skylineCurrentLyricMaximumScale"
        static let nextLyricFontSize = "skylineNextLyricFontSize"
        static let currentLyricsSpacing = "skylineCurrentLyricsSpacing"
        static let currentLyricsWidth = "skylineCurrentLyricsWidth"
        static let nextLyricOpacity = "skylineNextLyricOpacity"
        static let ambientFontSize = "skylineAmbientFontSize"
        static let ambientMaximumCharacters = "skylineAmbientMaximumCharacters"
        static let ambientMaximumVisibleTexts = "skylineAmbientMaximumVisibleTexts"
        static let ambientOpacity = "skylineAmbientOpacity"
        static let ambientBlur = "skylineAmbientBlur"
        static let ambientMaximumTilt = "skylineAmbientMaximumTilt"
        static let ambientDrift = "skylineAmbientDrift"
    }

    private enum Default {
        static let keepsScreenAwake = true
        static let currentLyricFontSize = 54.0
        static let currentLyricMaximumScale = 1.10
        static let nextLyricFontSize = 24.0
        static let currentLyricsSpacing = 14.0
        static let currentLyricsWidth = 0.64
        static let nextLyricOpacity = 0.48
        static let ambientFontSize = 44.0
        static let ambientMaximumCharacters = 4
        static let ambientMaximumVisibleTexts = 16
        static let ambientOpacity = 1.0
        static let ambientBlur = 1.0
        static let ambientMaximumTilt = 8.0
        static let ambientDrift = 1.0
    }

    var keepsScreenAwake: Bool {
        didSet { defaults.set(keepsScreenAwake, forKey: Key.keepsScreenAwake) }
    }

    var currentLyricFontSize: Double {
        didSet { defaults.set(currentLyricFontSize, forKey: Key.currentLyricFontSize) }
    }

    var currentLyricMaximumScale: Double {
        didSet {
            defaults.set(
                currentLyricMaximumScale,
                forKey: Key.currentLyricMaximumScale
            )
        }
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

    var ambientMaximumVisibleTexts: Int {
        didSet {
            defaults.set(
                ambientMaximumVisibleTexts,
                forKey: Key.ambientMaximumVisibleTexts
            )
        }
    }

    var ambientOpacity: Double {
        didSet { defaults.set(ambientOpacity, forKey: Key.ambientOpacity) }
    }

    var ambientBlur: Double {
        didSet { defaults.set(ambientBlur, forKey: Key.ambientBlur) }
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
        keepsScreenAwake = defaults.object(forKey: Key.keepsScreenAwake) as? Bool
            ?? Default.keepsScreenAwake
        currentLyricFontSize = defaults.object(forKey: Key.currentLyricFontSize) as? Double
            ?? Default.currentLyricFontSize
        currentLyricMaximumScale = min(
            max(
                defaults.object(forKey: Key.currentLyricMaximumScale) as? Double
                    ?? Default.currentLyricMaximumScale,
                1
            ),
            1.2
        )
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
            4
        )
        ambientMaximumVisibleTexts = min(
            max(
                defaults.object(forKey: Key.ambientMaximumVisibleTexts) as? Int
                    ?? Default.ambientMaximumVisibleTexts,
                4
            ),
            24
        )
        ambientOpacity = defaults.object(forKey: Key.ambientOpacity) as? Double
            ?? Default.ambientOpacity
        ambientBlur = defaults.object(forKey: Key.ambientBlur) as? Double
            ?? Default.ambientBlur
        ambientMaximumTilt = defaults.object(forKey: Key.ambientMaximumTilt) as? Double
            ?? Default.ambientMaximumTilt
        ambientDrift = defaults.object(forKey: Key.ambientDrift) as? Double
            ?? Default.ambientDrift
    }

    func reset() {
        keepsScreenAwake = Default.keepsScreenAwake
        currentLyricFontSize = Default.currentLyricFontSize
        currentLyricMaximumScale = Default.currentLyricMaximumScale
        nextLyricFontSize = Default.nextLyricFontSize
        currentLyricsSpacing = Default.currentLyricsSpacing
        currentLyricsWidth = Default.currentLyricsWidth
        nextLyricOpacity = Default.nextLyricOpacity
        ambientFontSize = Default.ambientFontSize
        ambientMaximumCharacters = Default.ambientMaximumCharacters
        ambientMaximumVisibleTexts = Default.ambientMaximumVisibleTexts
        ambientOpacity = Default.ambientOpacity
        ambientBlur = Default.ambientBlur
        ambientMaximumTilt = Default.ambientMaximumTilt
        ambientDrift = Default.ambientDrift
    }
}
