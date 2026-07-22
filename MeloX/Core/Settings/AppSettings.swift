import Foundation
import Observation

enum MusicQuality: String, CaseIterable, Identifiable {
    case standard = "128000"
    case high = "320000"
    case lossless = "flac"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "标准"
        case .high: "高品质"
        case .lossless: "无损"
        }
    }

    var bitrate: String {
        self == .lossless ? "350000" : rawValue
    }
}

@MainActor
@Observable
final class AppSettings {
    static let defaultLyricsFontSize = 25.0
    static let defaultLyricsCurrentLineScale = 1.2
    static let defaultLyricsLineSpacing = 27.0
    static let defaultLyricsBlurIntensity = 0.8
    static let defaultLyricsDimAmount = 1.0
    static let defaultLyricsFocusPosition = 0.25
    static let lyricsFocusPositionRange = 0.05...0.8
    static let lyricsCurrentLineScaleRange = 1.0...1.5
    static let defaultLyricsDistanceBlurScale = 0.65
    static let defaultLyricsHiddenInterfaceBlurScale = 0.6
    static let lyricsDistanceBlurScaleRange = 0.0...1.5
    static let defaultLyricsFocusCascadeDelay = 0.025
    static let lyricsFocusCascadeDelayRange = 0.0...0.05
    static let defaultLyricsFocusCascadeBounceEnabled = true
    static let defaultLyricsFocusColorLeadTime = 0.06
    static let lyricsFocusColorLeadTimeRange = 0.0...0.1
    static let defaultTextPV1MotionIntensity = 1.0
    static let textPV1MotionIntensityRange = 0.5...1.5

    private enum Key {
        static let cookie = "musicCookie"
        static let quality = "musicQuality"
        static let area = "musicArea"
        static let showPlayCount = "showPlayCount"
        static let playerBackgroundBlur = "playerBackgroundBlur"
        static let playerBackgroundSaturation = "playerBackgroundSaturation"
        static let shrinksPausedArtwork = "shrinksPausedArtwork"
        static let lyricsStyle = "lyricsStyle"
        static let lyricsFontSize = "lyricsFontSize"
        static let lyricsCurrentLineScale = "lyricsCurrentLineScale"
        static let lyricsLineSpacing = "lyricsLineSpacing"
        static let lyricsBlurIntensity = "lyricsBlurIntensity"
        static let lyricsDistanceBlurScale = "lyricsDistanceBlurScale"
        static let lyricsHiddenInterfaceBlurScale = "lyricsHiddenInterfaceBlurScale"
        static let lyricsDimAmount = "lyricsDimAmount"
        static let lyricsTapToSeek = "lyricsTapToSeek"
        static let lyricsWordByWord = "lyricsWordByWord"
        static let lyricsPseudoWordByWord = "lyricsPseudoWordByWord"
        static let lyricsGlowEnabled = "lyricsGlowEnabled"
        static let lyricsGlowIntensity = "lyricsGlowIntensity"
        static let lyricsTranslationEnabled = "lyricsTranslationEnabled"
        static let lyricsTranslationFontScale = "lyricsTranslationFontScale"
        static let lyricsTranslationOpacity = "lyricsTranslationOpacity"
        static let lyricsAutoFollow = "lyricsAutoFollow"
        static let lyricsFollowDelay = "lyricsFollowDelay"
        static let lyricsFocusPosition = "lyricsFocusPosition"
        static let lyricsFocusCascadeDelay = "lyricsFocusCascadeDelay"
        static let lyricsFocusCascadeBounceEnabled = "lyricsFocusCascadeBounceEnabled"
        static let lyricsFocusColorLeadTime = "lyricsFocusColorLeadTime"
        static let lyricsAdvanceTime = "lyricsAdvanceTime"
        static let lyricsRefreshRate = "lyricsRefreshRate"
        static let textPV1MotionIntensity = "textPV1MotionIntensity"
        static let playerScreenAwakeMode = "playerScreenAwakeMode"
        static let legacyLyricsKeepsScreenAwake = "lyricsKeepsScreenAwake"
        static let rememberNowPlayingPage = "rememberNowPlayingPage"
        static let rememberedNowPlayingPage = "rememberedNowPlayingPage"
        static let previousRestartsCurrentSong = "previousRestartsCurrentSong"
        static let checksUpdatesOnLaunch = "checksUpdatesOnLaunch"
    }

    var cookie: String {
        didSet { defaults.set(cookie, forKey: Key.cookie) }
    }

    var quality: MusicQuality {
        didSet { defaults.set(quality.rawValue, forKey: Key.quality) }
    }

    var musicArea: String {
        didSet { defaults.set(musicArea, forKey: Key.area) }
    }

    var showPlayCount: Bool {
        didSet { defaults.set(showPlayCount, forKey: Key.showPlayCount) }
    }

    var playerBackgroundBlur: Double {
        didSet { defaults.set(playerBackgroundBlur, forKey: Key.playerBackgroundBlur) }
    }

    var playerBackgroundSaturation: Double {
        didSet { defaults.set(playerBackgroundSaturation, forKey: Key.playerBackgroundSaturation) }
    }

    var shrinksPausedArtwork: Bool {
        didSet { defaults.set(shrinksPausedArtwork, forKey: Key.shrinksPausedArtwork) }
    }

    var lyricsStyle: LyricsStyle {
        didSet { defaults.set(lyricsStyle.rawValue, forKey: Key.lyricsStyle) }
    }

    var lyricsFontSize: Double {
        didSet { defaults.set(lyricsFontSize, forKey: Key.lyricsFontSize) }
    }

    var lyricsCurrentLineScale: Double {
        didSet { defaults.set(lyricsCurrentLineScale, forKey: Key.lyricsCurrentLineScale) }
    }

    var lyricsLineSpacing: Double {
        didSet { defaults.set(lyricsLineSpacing, forKey: Key.lyricsLineSpacing) }
    }

    var lyricsBlurIntensity: Double {
        didSet { defaults.set(lyricsBlurIntensity, forKey: Key.lyricsBlurIntensity) }
    }

    var lyricsDistanceBlurScale: Double {
        didSet {
            defaults.set(
                lyricsDistanceBlurScale,
                forKey: Key.lyricsDistanceBlurScale
            )
        }
    }

    var lyricsHiddenInterfaceBlurScale: Double {
        didSet {
            defaults.set(
                lyricsHiddenInterfaceBlurScale,
                forKey: Key.lyricsHiddenInterfaceBlurScale
            )
        }
    }

    var lyricsDimAmount: Double {
        didSet { defaults.set(lyricsDimAmount, forKey: Key.lyricsDimAmount) }
    }

    var lyricsTapToSeek: Bool {
        didSet { defaults.set(lyricsTapToSeek, forKey: Key.lyricsTapToSeek) }
    }

    var lyricsWordByWord: Bool {
        didSet { defaults.set(lyricsWordByWord, forKey: Key.lyricsWordByWord) }
    }

    var lyricsPseudoWordByWord: Bool {
        didSet { defaults.set(lyricsPseudoWordByWord, forKey: Key.lyricsPseudoWordByWord) }
    }

    var lyricsGlowEnabled: Bool {
        didSet { defaults.set(lyricsGlowEnabled, forKey: Key.lyricsGlowEnabled) }
    }

    var lyricsGlowIntensity: Double {
        didSet { defaults.set(lyricsGlowIntensity, forKey: Key.lyricsGlowIntensity) }
    }

    var lyricsTranslationEnabled: Bool {
        didSet { defaults.set(lyricsTranslationEnabled, forKey: Key.lyricsTranslationEnabled) }
    }

    var lyricsTranslationFontScale: Double {
        didSet { defaults.set(lyricsTranslationFontScale, forKey: Key.lyricsTranslationFontScale) }
    }

    var lyricsTranslationOpacity: Double {
        didSet { defaults.set(lyricsTranslationOpacity, forKey: Key.lyricsTranslationOpacity) }
    }

    var lyricsAutoFollow: Bool {
        didSet { defaults.set(lyricsAutoFollow, forKey: Key.lyricsAutoFollow) }
    }

    var lyricsFollowDelay: Double {
        didSet { defaults.set(lyricsFollowDelay, forKey: Key.lyricsFollowDelay) }
    }

    var lyricsFocusPosition: Double {
        didSet { defaults.set(lyricsFocusPosition, forKey: Key.lyricsFocusPosition) }
    }

    var lyricsFocusCascadeDelay: Double {
        didSet {
            defaults.set(
                lyricsFocusCascadeDelay,
                forKey: Key.lyricsFocusCascadeDelay
            )
        }
    }

    var lyricsFocusCascadeBounceEnabled: Bool {
        didSet {
            defaults.set(
                lyricsFocusCascadeBounceEnabled,
                forKey: Key.lyricsFocusCascadeBounceEnabled
            )
        }
    }

    var lyricsFocusColorLeadTime: Double {
        didSet {
            defaults.set(
                lyricsFocusColorLeadTime,
                forKey: Key.lyricsFocusColorLeadTime
            )
        }
    }

    var lyricsAdvanceTime: Double {
        didSet { defaults.set(lyricsAdvanceTime, forKey: Key.lyricsAdvanceTime) }
    }

    var lyricsRefreshRate: LyricsRefreshRate {
        didSet { defaults.set(lyricsRefreshRate.rawValue, forKey: Key.lyricsRefreshRate) }
    }

    var textPV1MotionIntensity: Double {
        didSet {
            defaults.set(
                textPV1MotionIntensity,
                forKey: Key.textPV1MotionIntensity
            )
        }
    }

    var playerScreenAwakeMode: PlayerScreenAwakeMode {
        didSet {
            defaults.set(
                playerScreenAwakeMode.rawValue,
                forKey: Key.playerScreenAwakeMode
            )
        }
    }

    var rememberNowPlayingPage: Bool {
        didSet {
            defaults.set(rememberNowPlayingPage, forKey: Key.rememberNowPlayingPage)
            if !rememberNowPlayingPage {
                rememberedNowPlayingPage = "artwork"
            }
        }
    }

    var rememberedNowPlayingPage: String {
        didSet { defaults.set(rememberedNowPlayingPage, forKey: Key.rememberedNowPlayingPage) }
    }

    var previousRestartsCurrentSong: Bool {
        didSet { defaults.set(previousRestartsCurrentSong, forKey: Key.previousRestartsCurrentSong) }
    }

    var checksUpdatesOnLaunch: Bool {
        didSet { defaults.set(checksUpdatesOnLaunch, forKey: Key.checksUpdatesOnLaunch) }
    }

    let skylineLyrics: SkylineLyricsPreferences

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        skylineLyrics = SkylineLyricsPreferences(defaults: defaults)
        cookie = defaults.string(forKey: Key.cookie) ?? ""
        quality = MusicQuality(rawValue: defaults.string(forKey: Key.quality) ?? "") ?? .high
        musicArea = defaults.string(forKey: Key.area) ?? "ALL"
        showPlayCount = defaults.object(forKey: Key.showPlayCount) as? Bool ?? true
        playerBackgroundBlur = defaults.object(forKey: Key.playerBackgroundBlur) as? Double ?? 90
        playerBackgroundSaturation = defaults.object(forKey: Key.playerBackgroundSaturation) as? Double ?? 0.82
        shrinksPausedArtwork = defaults.object(forKey: Key.shrinksPausedArtwork) as? Bool ?? true
        let storedLyricsStyle = defaults.string(forKey: Key.lyricsStyle) ?? ""
        lyricsStyle = storedLyricsStyle == "spotlight"
            ? .eva
            : LyricsStyle(rawValue: storedLyricsStyle) ?? .appleMusic
        lyricsFontSize = defaults.object(forKey: Key.lyricsFontSize) as? Double
            ?? Self.defaultLyricsFontSize
        let storedCurrentLineScale = defaults.object(
            forKey: Key.lyricsCurrentLineScale
        ) as? Double ?? Self.defaultLyricsCurrentLineScale
        lyricsCurrentLineScale = min(
            max(
                storedCurrentLineScale,
                Self.lyricsCurrentLineScaleRange.lowerBound
            ),
            Self.lyricsCurrentLineScaleRange.upperBound
        )
        lyricsLineSpacing = defaults.object(forKey: Key.lyricsLineSpacing) as? Double
            ?? Self.defaultLyricsLineSpacing
        lyricsBlurIntensity = defaults.object(forKey: Key.lyricsBlurIntensity) as? Double
            ?? Self.defaultLyricsBlurIntensity
        let storedLyricsDistanceBlurScale = defaults.object(
            forKey: Key.lyricsDistanceBlurScale
        ) as? Double ?? Self.defaultLyricsDistanceBlurScale
        lyricsDistanceBlurScale = min(
            max(
                storedLyricsDistanceBlurScale,
                Self.lyricsDistanceBlurScaleRange.lowerBound
            ),
            Self.lyricsDistanceBlurScaleRange.upperBound
        )
        let storedLyricsHiddenInterfaceBlurScale = defaults.object(
            forKey: Key.lyricsHiddenInterfaceBlurScale
        ) as? Double ?? Self.defaultLyricsHiddenInterfaceBlurScale
        lyricsHiddenInterfaceBlurScale = min(
            max(
                storedLyricsHiddenInterfaceBlurScale,
                Self.lyricsDistanceBlurScaleRange.lowerBound
            ),
            Self.lyricsDistanceBlurScaleRange.upperBound
        )
        lyricsDimAmount = defaults.object(forKey: Key.lyricsDimAmount) as? Double
            ?? Self.defaultLyricsDimAmount
        lyricsTapToSeek = defaults.object(forKey: Key.lyricsTapToSeek) as? Bool ?? true
        lyricsWordByWord = defaults.object(forKey: Key.lyricsWordByWord) as? Bool ?? true
        lyricsPseudoWordByWord = defaults.object(forKey: Key.lyricsPseudoWordByWord) as? Bool ?? false
        lyricsGlowEnabled = defaults.object(forKey: Key.lyricsGlowEnabled) as? Bool ?? true
        lyricsGlowIntensity = defaults.object(forKey: Key.lyricsGlowIntensity) as? Double ?? 1
        lyricsTranslationEnabled = defaults.object(forKey: Key.lyricsTranslationEnabled) as? Bool ?? true
        lyricsTranslationFontScale = defaults.object(forKey: Key.lyricsTranslationFontScale) as? Double ?? 0.62
        lyricsTranslationOpacity = defaults.object(forKey: Key.lyricsTranslationOpacity) as? Double ?? 0.66
        lyricsAutoFollow = defaults.object(forKey: Key.lyricsAutoFollow) as? Bool ?? true
        lyricsFollowDelay = defaults.object(forKey: Key.lyricsFollowDelay) as? Double ?? 3
        let storedLyricsFocusPosition = defaults.object(
            forKey: Key.lyricsFocusPosition
        ) as? Double ?? Self.defaultLyricsFocusPosition
        lyricsFocusPosition = min(
            max(
                storedLyricsFocusPosition,
                Self.lyricsFocusPositionRange.lowerBound
            ),
            Self.lyricsFocusPositionRange.upperBound
        )
        let storedFocusCascadeDelay = defaults.object(
            forKey: Key.lyricsFocusCascadeDelay
        ) as? Double ?? Self.defaultLyricsFocusCascadeDelay
        lyricsFocusCascadeDelay = min(
            max(
                storedFocusCascadeDelay,
                Self.lyricsFocusCascadeDelayRange.lowerBound
            ),
            Self.lyricsFocusCascadeDelayRange.upperBound
        )
        lyricsFocusCascadeBounceEnabled = defaults.object(
            forKey: Key.lyricsFocusCascadeBounceEnabled
        ) as? Bool ?? Self.defaultLyricsFocusCascadeBounceEnabled
        let storedFocusColorLeadTime = defaults.object(
            forKey: Key.lyricsFocusColorLeadTime
        ) as? Double ?? Self.defaultLyricsFocusColorLeadTime
        lyricsFocusColorLeadTime = min(
            max(
                storedFocusColorLeadTime,
                Self.lyricsFocusColorLeadTimeRange.lowerBound
            ),
            Self.lyricsFocusColorLeadTimeRange.upperBound
        )
        lyricsAdvanceTime = defaults.object(forKey: Key.lyricsAdvanceTime) as? Double ?? 0.2
        lyricsRefreshRate = LyricsRefreshRate(
            rawValue: defaults.object(forKey: Key.lyricsRefreshRate) as? Int ?? 0
        ) ?? .defaultValue
        let storedTextPV1MotionIntensity = defaults.object(
            forKey: Key.textPV1MotionIntensity
        ) as? Double ?? Self.defaultTextPV1MotionIntensity
        textPV1MotionIntensity = min(
            max(
                storedTextPV1MotionIntensity,
                Self.textPV1MotionIntensityRange.lowerBound
            ),
            Self.textPV1MotionIntensityRange.upperBound
        )
        if let storedScreenAwakeMode = defaults.string(
            forKey: Key.playerScreenAwakeMode
        ), let screenAwakeMode = PlayerScreenAwakeMode(
            rawValue: storedScreenAwakeMode
        ) {
            playerScreenAwakeMode = screenAwakeMode
        } else {
            let legacyLyricsKeepsScreenAwake = defaults.object(
                forKey: Key.legacyLyricsKeepsScreenAwake
            ) as? Bool ?? true
            playerScreenAwakeMode = legacyLyricsKeepsScreenAwake
                ? .lyrics
                : .disabled
        }
        rememberNowPlayingPage = defaults.object(forKey: Key.rememberNowPlayingPage) as? Bool ?? false
        rememberedNowPlayingPage = defaults.string(forKey: Key.rememberedNowPlayingPage) ?? "artwork"
        previousRestartsCurrentSong = defaults.object(forKey: Key.previousRestartsCurrentSong) as? Bool ?? true
        checksUpdatesOnLaunch = defaults.object(forKey: Key.checksUpdatesOnLaunch) as? Bool ?? true
    }

    func clearAccount() {
        cookie = ""
    }

    func resetPlayerSettings() {
        quality = .high
        playerBackgroundBlur = 90
        playerBackgroundSaturation = 0.82
        shrinksPausedArtwork = true
        lyricsStyle = .appleMusic
        lyricsFontSize = Self.defaultLyricsFontSize
        lyricsCurrentLineScale = Self.defaultLyricsCurrentLineScale
        lyricsLineSpacing = Self.defaultLyricsLineSpacing
        lyricsBlurIntensity = Self.defaultLyricsBlurIntensity
        lyricsDistanceBlurScale = Self.defaultLyricsDistanceBlurScale
        lyricsHiddenInterfaceBlurScale = Self.defaultLyricsHiddenInterfaceBlurScale
        lyricsDimAmount = Self.defaultLyricsDimAmount
        lyricsTapToSeek = true
        lyricsWordByWord = true
        lyricsPseudoWordByWord = false
        lyricsGlowEnabled = true
        lyricsGlowIntensity = 1
        lyricsTranslationEnabled = true
        lyricsTranslationFontScale = 0.62
        lyricsTranslationOpacity = 0.66
        lyricsAutoFollow = true
        lyricsFollowDelay = 3
        lyricsFocusPosition = Self.defaultLyricsFocusPosition
        lyricsFocusCascadeDelay = Self.defaultLyricsFocusCascadeDelay
        lyricsFocusCascadeBounceEnabled = Self.defaultLyricsFocusCascadeBounceEnabled
        lyricsFocusColorLeadTime = Self.defaultLyricsFocusColorLeadTime
        lyricsAdvanceTime = 0.2
        lyricsRefreshRate = .defaultValue
        textPV1MotionIntensity = Self.defaultTextPV1MotionIntensity
        playerScreenAwakeMode = .lyrics
        rememberNowPlayingPage = false
        rememberedNowPlayingPage = "artwork"
        previousRestartsCurrentSong = true
        skylineLyrics.reset()
    }
}
