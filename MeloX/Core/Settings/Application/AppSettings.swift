import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    static let defaultPlayerVolumeControlMode: PlayerVolumeControlMode = .system
    static let defaultPlayerBackgroundStyle: PlayerBackgroundStyle =
        .appleMusicBackdrop
    static let defaultPlayerBackgroundMotionIntensity = 1.0
    static let defaultPlayerBackgroundSaturation = 1.0
    static let defaultPlayerBackgroundAudioResponseEnabled = false
    static let defaultPlayerBackgroundBeatEffectsEnabled = false
    static let defaultBeatNetDebugEnabled = false
    static let defaultStartsHeartModeOnLaunch = false
    static let defaultRecognizesClipboardLinksOnLaunch = false
    static let defaultSystemNowPlayingLyricsEnabled = true
    static var defaultSystemNowPlayingLyricsTitleFormat: String {
        L10n.string("ui.lyrics.format.token.lyrics")
    }
    static var defaultSystemNowPlayingLyricsSubtitleFormat: String {
        L10n.format(
            "ui.lyrics.format.default.title_artist",
            L10n.string("ui.lyrics.format.token.title"),
            L10n.string("ui.lyrics.format.token.artist")
        )
    }
    static let defaultLyricsLiveActivityEnabled = false
    static var defaultLyricsLiveActivityTitleFormat: String {
        L10n.string("ui.lyrics.format.token.lyrics")
    }
    static var defaultLyricsLiveActivitySubtitleFormat: String {
        L10n.format(
            "ui.lyrics.format.default.title_artist",
            L10n.string("ui.lyrics.format.token.title"),
            L10n.string("ui.lyrics.format.token.artist")
        )
    }
    static var defaultLyricsLiveActivityCompactFormat: String {
        L10n.string("ui.lyrics.format.token.lyrics")
    }
    static let defaultLyricsLiveActivityShowsArtwork = true
    static let defaultLyricsLiveActivityShowsNextLyric = true
    static let defaultLyricsLiveActivityShowsProgress = true
    static let defaultLyricsLiveActivityScrollsCompactText = true
    static let defaultLyricsLiveActivityCompactTextSize:
        LyricsLiveActivityCompactTextSize = .standard
    static let defaultLyricsLiveActivityScrollSpeed = 52.0
    static let lyricsLiveActivityScrollSpeedRange = 8.0...80.0
    static let defaultLyricsLiveActivityScrollPause = 1.0
    static let lyricsLiveActivityScrollPauseRange = 0.0...3.0
    static let automaticCachePlaybackThresholdOptions = [3, 5, 10, 20]
    static let defaultAppleMusicLyricsInterfaceAutoHideDelay = 5.0
    static let appleMusicLyricsInterfaceAutoHideDelayRange = 3.0...15.0
    static let defaultAppleMusicLyricsScrollHideThreshold = 200.0
    static let appleMusicLyricsScrollHideThresholdRange = 40.0...240.0
    static let defaultLyricsFontSize = 34.0
    static let defaultLyricsFontWeight: LyricsFontWeight = .heavy
    static let defaultLyricsCurrentLineScale = 1.02
    static let defaultLyricsLineSpacing = 28.0
    static let defaultLyricsBlurIntensity = 0.8
    static let defaultLyricsUsesUniformDimmingWhileBrowsing = true
    static let defaultLyricsDimAmount = 1.0
    static let defaultLyricsFocusPosition = 0.25
    static let lyricsFocusPositionRange = 0.05...0.8
    static let lyricsCurrentLineScaleRange = 1.0...1.5
    static let defaultLyricsDistanceBlurScale = 1.05
    static let defaultLyricsHiddenInterfaceBlurScale = 0.85
    static let lyricsDistanceBlurScaleRange = 0.0...1.5
    static let defaultLyricsFocusCascadeDelay = 0.021
    static let lyricsFocusCascadeDelayRange = 0.0...0.1
    static let defaultLyricsFocusCascadeDelayIncrease = 0.005
    static let lyricsFocusCascadeDelayIncreaseRange = 0.0...0.1
    static let defaultLyricsFocusCascadeFollowingDelay = 0.030
    static let lyricsFocusCascadeFollowingDelayRange = 0.0...0.2
    static let defaultLyricsFocusCascadeCatchUpRatio = 0.97
    static let lyricsFocusCascadeCatchUpRatioRange = 0.5...1.0
    static let defaultLyricsFocusCascadeChaseSpeedGradient = 0.70
    static let lyricsFocusCascadeChaseSpeedGradientRange = 0.0...1.0
    static let defaultLyricsFocusCascadeDuration = 0.74
    static let lyricsFocusCascadeDurationRange = 0.2...1.2
    static let defaultLyricsFocusSnapThreshold = 0.26
    static let lyricsFocusSnapThresholdRange = 0.05...0.5
    static let defaultLyricsFocusCascadeBounceEnabled = true
    static let defaultLyricsFocusCascadeBounce = 0.26
    static let lyricsFocusCascadeBounceRange = 0.0...0.8
    static let defaultLyricsFocusCascadeBounceGradient = 0.85
    static let lyricsFocusCascadeBounceGradientRange = 0.0...1.0
    static let defaultLyricsFocusScaleBounceEnabled = true
    static let defaultLyricsFocusScaleBounce = 0.32
    static let lyricsFocusScaleBounceRange = 0.0...0.5
    static let defaultLyricsFocusScaleBounceDuration = 0.58
    static let lyricsFocusScaleBounceDurationRange = 0.15...0.8
    static let defaultLyricsFocusColorLeadTime = 0.0
    static let lyricsFocusColorLeadTimeRange = -0.3...0.3
    static let defaultLyricsRomanizationFontScale = 0.65
    static let defaultLyricsRomanizationOpacity = 0.9
    static let defaultLyricsTranslationFontScale = 0.65
    static let defaultLyricsTranslationOpacity = 0.9
    static let defaultLyricsLiftMode: LyricsLiftMode = .character
    static let defaultLyricsSourcePreference: LyricSourcePreference = .automatic
    static let defaultLyricsLongSyllableDetectionMode:
        LyricsLongSyllableDetectionMode = .character
    static let defaultLyricsGlowLongSyllablesOnly = true
    static let defaultLyricsLongSyllableDurationThreshold = 0.95
    static let lyricsLongSyllableDurationThresholdRange = 0.3...1.5
    static let defaultLyricsLongToneExpansionAmount = 0.05
    static let lyricsLongToneExpansionAmountRange = 0.0...0.15
    static let defaultLyricsHighlightGradientWidth = 0.7
    static let lyricsHighlightGradientWidthRange = 0.4...3.0
    static let defaultLyricsHighlightGradientReduction = 0.65
    static let lyricsHighlightGradientReductionRange = 0.0...1.0
    private enum Key {
        static let hasCompletedOnboarding = "melox.hasCompletedOnboarding"
        static let cookie = "musicCookie"
        static let quality = "musicQuality"
        static let cellularQuality = "cellularMusicQuality"
        static let playerVolumeControlMode = "playerVolumeControlMode"
        static let systemNowPlayingLyricsEnabled =
            "systemNowPlayingLyricsEnabled"
        static let systemNowPlayingLyricsTitleFormat =
            "systemNowPlayingLyricsTitleFormat"
        static let systemNowPlayingLyricsSubtitleFormat =
            "systemNowPlayingLyricsSubtitleFormat"
        static let lyricsLiveActivityEnabled =
            "lyricsLiveActivityEnabled"
        static let lyricsLiveActivityTitleFormat =
            "lyricsLiveActivityTitleFormat"
        static let lyricsLiveActivitySubtitleFormat =
            "lyricsLiveActivitySubtitleFormat"
        static let lyricsLiveActivityCompactFormat =
            "lyricsLiveActivityCompactFormat"
        static let lyricsLiveActivityShowsArtwork =
            "lyricsLiveActivityShowsArtwork"
        static let lyricsLiveActivityShowsNextLyric =
            "lyricsLiveActivityShowsNextLyric"
        static let lyricsLiveActivityShowsProgress =
            "lyricsLiveActivityShowsProgress"
        static let lyricsLiveActivityScrollsCompactText =
            "lyricsLiveActivityScrollsCompactText"
        static let lyricsLiveActivityCompactTextSize =
            "lyricsLiveActivityCompactTextSize"
        static let lyricsLiveActivityScrollSpeed =
            "lyricsLiveActivityScrollSpeed"
        static let lyricsLiveActivityScrollPause =
            "lyricsLiveActivityScrollPause"
        static let appLanguage = AppLanguage.storageKey
        static let searchSuggestionsEnabled = "searchSuggestionsEnabled"
        static let appearance = "appAppearance"
        static let defaultLaunchTab = "defaultLaunchTab"
        static let restoresLastSelectedTab = "restoresLastSelectedTab"
        static let lastSelectedTab = "lastSelectedTab"
        static let defaultLibraryPage = "defaultLibraryPage"
        static let restoresLastLibraryPage = "restoresLastLibraryPage"
        static let lastLibraryPage = "lastLibraryPage"
        static let separatedLibraryPages =
            "melox.navigation.separatedLibraryPages"
        static let homeTabOrder = "melox.navigation.homeTabOrder"
        static let tabOrder = "melox.navigation.tabOrder"
        static let area = "musicArea"
        static let showPlayCount = "showPlayCount"
        static let playerBackgroundStyle = "playerBackgroundStyle"
        static let playerBackgroundMotionIntensity =
            "playerBackgroundMotionIntensity"
        static let playerBackgroundBeatEffectsEnabled =
            "playerBackgroundBeatEffectsEnabled"
        static let playerBackgroundAudioResponseEnabled =
            "playerBackgroundAudioResponseEnabled"
        static let beatNetDebugEnabled = "beatNetDebugEnabled"
        static let playerBackgroundBlur = "playerBackgroundBlur"
        static let playerBackgroundSaturation = "playerBackgroundSaturation"
        static let shrinksPausedArtwork = "shrinksPausedArtwork"
        static let lyricsStyle = "lyricsStyle"
        static let appleMusicLyricsInterfaceAutoHideDelay =
            "appleMusicLyricsInterfaceAutoHideDelay"
        static let appleMusicLyricsScrollHideThreshold =
            "appleMusicLyricsScrollHideThreshold"
        static let lyricsFontSize = "lyricsFontSize"
        static let lyricsFontWeight = "lyricsFontWeight"
        static let lyricsCurrentLineScale = "lyricsCurrentLineScale"
        static let lyricsLineSpacing = "lyricsLineSpacing"
        static let lyricsBlurIntensity = "lyricsBlurIntensity"
        static let lyricsUsesUniformDimmingWhileBrowsing =
            "lyricsUsesUniformDimmingWhileBrowsing"
        static let lyricsDistanceBlurScale = "lyricsDistanceBlurScale"
        static let lyricsHiddenInterfaceBlurScale = "lyricsHiddenInterfaceBlurScale"
        static let lyricsDimAmount = "lyricsDimAmount"
        static let lyricsTapToSeek = "lyricsTapToSeek"
        static let lyricsLongPressToShare = "lyricsLongPressToShare"
        static let lyricsWordByWord = "lyricsWordByWord"
        static let lyricsPseudoWordByWord = "lyricsPseudoWordByWord"
        static let lyricsDuetLayoutEnabled = "lyricsDuetLayoutEnabled"
        static let lyricsAMLLSourceEnabled = "lyricsAMLLSourceEnabled"
        static let lyricsQQMusicSourceEnabled = "lyricsQQMusicSourceEnabled"
        static let lyricsSourcePreference = "lyricsSourcePreference"
        static let lyricsLiftMode = "lyricsLiftMode"
        static let lyricsHighlightGradientWidth =
            "lyricsHighlightGradientWidth"
        static let lyricsHighlightGradientReduction =
            "lyricsHighlightGradientReduction"
        static let lyricsGlowEnabled = "lyricsGlowEnabled"
        static let lyricsLongSyllableDetectionMode =
            "lyricsLongSyllableDetectionMode"
        static let lyricsGlowLongSyllablesOnly =
            "lyricsGlowLongSyllablesOnly"
        static let lyricsLongSyllableDurationThreshold =
            "lyricsLongSyllableDurationThreshold"
        static let lyricsLongToneExpansionAmount =
            "lyricsLongToneExpansionAmount"
        static let lyricsGlowIntensity = "lyricsGlowIntensity"
        static let lyricsRomanizationEnabled = "lyricsRomanizationEnabled"
        static let lyricsRomanizationFontScale =
            "lyricsRomanizationFontScale"
        static let lyricsRomanizationOpacity =
            "lyricsRomanizationOpacity"
        static let lyricsRomanizationDisplayMode =
            "lyricsRomanizationDisplayMode"
        static let lyricsTranslationEnabled = "lyricsTranslationEnabled"
        static let lyricsTranslationDisplayMode = "lyricsTranslationDisplayMode"
        static let lyricsTranslationFontScale = "lyricsTranslationFontScale"
        static let lyricsTranslationOpacity = "lyricsTranslationOpacity"
        static let lyricsAutoFollow = "lyricsAutoFollow"
        static let lyricsFollowDelay = "lyricsFollowDelay"
        static let lyricsFocusPosition = "lyricsFocusPosition"
        static let lyricsFocusCascadeDelay = "lyricsFocusCascadeDelay"
        static let lyricsFocusCascadeDelayIncrease =
            "lyricsFocusCascadeDelayIncrease"
        static let lyricsFocusCascadeFollowingDelay =
            "lyricsFocusCascadeFollowingDelay"
        static let lyricsFocusCascadeCatchUpRatio =
            "lyricsFocusCascadeCatchUpRatio"
        static let lyricsFocusCascadeChaseSpeedGradient =
            "lyricsFocusCascadeChaseSpeedGradient"
        static let lyricsFocusCascadeDuration = "lyricsFocusCascadeDuration"
        static let lyricsFocusSnapThreshold = "lyricsFocusSnapThreshold"
        static let lyricsFocusCascadeBounceEnabled = "lyricsFocusCascadeBounceEnabled"
        static let lyricsFocusCascadeBounce = "lyricsFocusCascadeBounce"
        static let lyricsFocusCascadeBounceGradient =
            "lyricsFocusCascadeBounceGradient"
        static let lyricsFocusScaleBounceEnabled = "lyricsFocusScaleBounceEnabled"
        static let lyricsFocusScaleBounce = "lyricsFocusScaleBounce"
        static let lyricsFocusScaleBounceDuration =
            "lyricsFocusScaleBounceDuration"
        static let legacyLyricsFocusCascadeMinimumBounceDuration =
            "lyricsFocusCascadeMinimumBounceDuration"
        static let lyricsFocusColorLeadTime = "lyricsFocusColorLeadTime"
        static let lyricsAdvanceTime = "lyricsAdvanceTime"
        static let lyricsAdvanceTimeAppliesToWordByWord =
            "lyricsAdvanceTimeAppliesToWordByWord"
        static let lyricsRefreshRate = "lyricsRefreshRate"
        static let playerScreenAwakeMode = "playerScreenAwakeMode"
        static let legacyLyricsKeepsScreenAwake = "lyricsKeepsScreenAwake"
        static let rememberNowPlayingPage = "rememberNowPlayingPage"
        static let rememberedNowPlayingPage = "rememberedNowPlayingPage"
        static let previousRestartsCurrentSong = "previousRestartsCurrentSong"
        static let startsHeartModeOnLaunch = "startsHeartModeOnLaunch"
        static let recognizesClipboardLinksOnLaunch =
            "recognizesClipboardLinksOnLaunch"
        static let checksUpdatesOnLaunch = "checksUpdatesOnLaunch"
        static let automaticallyCachesFrequentlyPlayedSongs = "automaticallyCachesFrequentlyPlayedSongs"
        static let automaticCachePlaybackThreshold = "automaticCachePlaybackThreshold"
        static let automaticCacheQuality = "automaticCacheQuality"
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(
                hasCompletedOnboarding,
                forKey: Key.hasCompletedOnboarding
            )
        }
    }

    var cookie: String {
        didSet { defaults.set(cookie, forKey: Key.cookie) }
    }

    var quality: MusicQuality {
        didSet { defaults.set(quality.rawValue, forKey: Key.quality) }
    }

    var cellularQuality: MusicQuality {
        didSet {
            defaults.set(
                cellularQuality.rawValue,
                forKey: Key.cellularQuality
            )
        }
    }

    var playerVolumeControlMode: PlayerVolumeControlMode {
        didSet {
            defaults.set(
                playerVolumeControlMode.rawValue,
                forKey: Key.playerVolumeControlMode
            )
        }
    }

    var systemNowPlayingLyricsEnabled: Bool {
        didSet {
            defaults.set(
                systemNowPlayingLyricsEnabled,
                forKey: Key.systemNowPlayingLyricsEnabled
            )
        }
    }

    var systemNowPlayingLyricsTitleFormat: String {
        didSet {
            defaults.set(
                systemNowPlayingLyricsTitleFormat,
                forKey: Key.systemNowPlayingLyricsTitleFormat
            )
        }
    }

    var systemNowPlayingLyricsSubtitleFormat: String {
        didSet {
            defaults.set(
                systemNowPlayingLyricsSubtitleFormat,
                forKey: Key.systemNowPlayingLyricsSubtitleFormat
            )
        }
    }

    var lyricsLiveActivityEnabled: Bool {
        didSet {
            defaults.set(
                lyricsLiveActivityEnabled,
                forKey: Key.lyricsLiveActivityEnabled
            )
        }
    }

    var lyricsLiveActivityTitleFormat: String {
        didSet {
            defaults.set(
                lyricsLiveActivityTitleFormat,
                forKey: Key.lyricsLiveActivityTitleFormat
            )
        }
    }

    var lyricsLiveActivitySubtitleFormat: String {
        didSet {
            defaults.set(
                lyricsLiveActivitySubtitleFormat,
                forKey: Key.lyricsLiveActivitySubtitleFormat
            )
        }
    }

    var lyricsLiveActivityCompactFormat: String {
        didSet {
            defaults.set(
                lyricsLiveActivityCompactFormat,
                forKey: Key.lyricsLiveActivityCompactFormat
            )
        }
    }

    var lyricsLiveActivityShowsArtwork: Bool {
        didSet {
            defaults.set(
                lyricsLiveActivityShowsArtwork,
                forKey: Key.lyricsLiveActivityShowsArtwork
            )
        }
    }

    var lyricsLiveActivityShowsNextLyric: Bool {
        didSet {
            defaults.set(
                lyricsLiveActivityShowsNextLyric,
                forKey: Key.lyricsLiveActivityShowsNextLyric
            )
        }
    }

    var lyricsLiveActivityShowsProgress: Bool {
        didSet {
            defaults.set(
                lyricsLiveActivityShowsProgress,
                forKey: Key.lyricsLiveActivityShowsProgress
            )
        }
    }

    var lyricsLiveActivityScrollsCompactText: Bool {
        didSet {
            defaults.set(
                lyricsLiveActivityScrollsCompactText,
                forKey: Key.lyricsLiveActivityScrollsCompactText
            )
        }
    }

    var lyricsLiveActivityCompactTextSize:
        LyricsLiveActivityCompactTextSize {
        didSet {
            defaults.set(
                lyricsLiveActivityCompactTextSize.rawValue,
                forKey: Key.lyricsLiveActivityCompactTextSize
            )
        }
    }

    var lyricsLiveActivityScrollSpeed: Double {
        didSet {
            defaults.set(
                lyricsLiveActivityScrollSpeed,
                forKey: Key.lyricsLiveActivityScrollSpeed
            )
        }
    }

    var lyricsLiveActivityScrollPause: Double {
        didSet {
            defaults.set(
                lyricsLiveActivityScrollPause,
                forKey: Key.lyricsLiveActivityScrollPause
            )
        }
    }

    var searchSuggestionsEnabled: Bool {
        didSet { defaults.set(searchSuggestionsEnabled, forKey: Key.searchSuggestionsEnabled) }
    }

    private(set) var appLanguage: AppLanguage

    var appearance: AppAppearance {
        didSet {
            defaults.set(
                appearance.rawValue,
                forKey: Key.appearance
            )
        }
    }

    var defaultLaunchTab: AppTab {
        didSet {
            defaults.set(defaultLaunchTab.rawValue, forKey: Key.defaultLaunchTab)
        }
    }

    var restoresLastSelectedTab: Bool {
        didSet {
            defaults.set(
                restoresLastSelectedTab,
                forKey: Key.restoresLastSelectedTab
            )
        }
    }

    var lastSelectedTab: AppTab {
        didSet {
            defaults.set(lastSelectedTab.rawValue, forKey: Key.lastSelectedTab)
        }
    }

    var defaultLibraryPage: LibraryPage {
        didSet {
            defaults.set(
                defaultLibraryPage.rawValue,
                forKey: Key.defaultLibraryPage
            )
        }
    }

    var restoresLastLibraryPage: Bool {
        didSet {
            defaults.set(
                restoresLastLibraryPage,
                forKey: Key.restoresLastLibraryPage
            )
        }
    }

    var lastLibraryPage: LibraryPage {
        didSet {
            defaults.set(lastLibraryPage.rawValue, forKey: Key.lastLibraryPage)
        }
    }

    private(set) var separatedLibraryPages: [LibraryPage] {
        didSet {
            defaults.set(
                separatedLibraryPages.map(\.rawValue),
                forKey: Key.separatedLibraryPages
            )
        }
    }

    private(set) var homeTabOrder: [AppTab] {
        didSet {
            defaults.set(
                homeTabOrder.map(\.rawValue),
                forKey: Key.homeTabOrder
            )
        }
    }

    private(set) var tabOrder: [AppTab] {
        didSet {
            defaults.set(
                tabOrder.map(\.rawValue),
                forKey: Key.tabOrder
            )
        }
    }

    var embeddedLibraryPages: [LibraryPage] {
        LibraryPage.availableCases.filter {
            isLibraryPageEnabled($0)
                && !separatedLibraryPages.contains($0)
        }
    }

    var homeTabs: [AppTab] {
        Self.normalizedHomeTabOrder(
            homeTabOrder,
            separatedLibraryPages: separatedLibraryPages
        )
        .filter(isNavigationTabEnabled)
    }

    var visibleTabs: [AppTab] {
        Self.normalizedTabOrder(
            tabOrder,
            separatedLibraryPages: separatedLibraryPages,
            homeTabs: homeTabs
        )
        .filter(isNavigationTabEnabled)
    }

    var launchTab: AppTab {
        let requestedTab =
            restoresLastSelectedTab ? lastSelectedTab : defaultLaunchTab
        return visibleTabs.contains(requestedTab)
            ? requestedTab
            : fallbackNavigationTab
    }

    var initialLibraryPage: LibraryPage {
        let requestedPage =
            restoresLastLibraryPage ? lastLibraryPage : defaultLibraryPage
        return embeddedLibraryPages.contains(requestedPage)
            ? requestedPage
            : embeddedLibraryPages.first ?? .songs
    }

    var fallbackNavigationTab: AppTab {
        if visibleTabs.contains(.home) {
            return .home
        }
        if visibleTabs.contains(.library) {
            return .library
        }
        return visibleTabs.first ?? .search
    }

    func placement(for tab: AppTab) -> AppPagePlacement {
        if tab == .recommended || homeTabs.contains(tab) {
            return .home
        }
        if let libraryPage = tab.libraryPage,
           !separatedLibraryPages.contains(libraryPage) {
            return .library
        }
        return .tabBar
    }

    func setPage(
        _ tab: AppTab,
        placement: AppPagePlacement
    ) {
        guard AppTab.configurablePages.contains(tab),
              isNavigationTabEnabled(tab),
              tab.allowedPlacements.contains(placement) else {
            return
        }

        let previousTabOrder = visibleTabs
        var nextHomeTabs = homeTabs
        var separatedPages = Set(separatedLibraryPages)

        if let libraryPage = tab.libraryPage {
            switch placement {
            case .home:
                separatedPages.insert(libraryPage)
                Self.appendIfNeeded(tab, to: &nextHomeTabs)
            case .tabBar:
                separatedPages.insert(libraryPage)
                nextHomeTabs.removeAll(where: { $0 == tab })
            case .library:
                separatedPages.remove(libraryPage)
                nextHomeTabs.removeAll(where: { $0 == tab })
            }
        } else {
            switch placement {
            case .home:
                Self.appendIfNeeded(tab, to: &nextHomeTabs)
            case .tabBar:
                nextHomeTabs.removeAll(where: { $0 == tab })
            case .library:
                return
            }
        }

        separatedLibraryPages = Self.normalizedLibraryPages(
            Array(separatedPages)
        )
        homeTabOrder = Self.normalizedHomeTabOrder(
            nextHomeTabs,
            separatedLibraryPages: separatedLibraryPages
        )
        tabOrder = Self.normalizedTabOrder(
            previousTabOrder,
            separatedLibraryPages: separatedLibraryPages,
            homeTabs: homeTabs
        )
        normalizeNavigationSelections()
    }

    func setHomeTabOrder(_ tabs: [AppTab]) {
        let disabledTabs = homeTabOrder.filter {
            !isNavigationTabEnabled($0)
        }
        homeTabOrder = Self.normalizedHomeTabOrder(
            tabs + disabledTabs,
            separatedLibraryPages: separatedLibraryPages
        )
    }

    func setVisibleTabOrder(_ tabs: [AppTab]) {
        let disabledTabs = tabOrder.filter {
            !isNavigationTabEnabled($0)
        }
        tabOrder = Self.normalizedTabOrder(
            tabs + disabledTabs,
            separatedLibraryPages: separatedLibraryPages,
            homeTabs: homeTabs
        )
    }

    func isContentFeatureEnabled(_ feature: ContentFeature) -> Bool {
        contentFeatures.isEnabled(feature)
    }

    func setContentFeature(
        _ feature: ContentFeature,
        isEnabled: Bool
    ) {
        contentFeatures.setEnabled(isEnabled, for: feature)
        normalizeNavigationSelections()
    }

    func isNavigationTabEnabled(_ tab: AppTab) -> Bool {
        guard let feature = tab.requiredContentFeature else { return true }
        return isContentFeatureEnabled(feature)
    }

    func isLibraryPageEnabled(_ page: LibraryPage) -> Bool {
        guard let feature = page.requiredContentFeature else { return true }
        return isContentFeatureEnabled(feature)
    }

    func resetTabLayout() {
        separatedLibraryPages = [.cloud]
        homeTabOrder = Self.normalizedHomeTabOrder(
            [.recommended, .music, .podcasts],
            separatedLibraryPages: separatedLibraryPages
        )
        tabOrder = Self.normalizedTabOrder(
            [],
            separatedLibraryPages: separatedLibraryPages,
            homeTabs: homeTabs
        )
        normalizeNavigationSelections()
    }

    var musicArea: String {
        didSet { defaults.set(musicArea, forKey: Key.area) }
    }

    var showPlayCount: Bool {
        didSet { defaults.set(showPlayCount, forKey: Key.showPlayCount) }
    }

    var playerBackgroundStyle: PlayerBackgroundStyle {
        didSet {
            defaults.set(
                playerBackgroundStyle.rawValue,
                forKey: Key.playerBackgroundStyle
            )
        }
    }

    var playerBackgroundMotionIntensity: Double {
        didSet {
            defaults.set(
                playerBackgroundMotionIntensity,
                forKey: Key.playerBackgroundMotionIntensity
            )
        }
    }

    var playerBackgroundBeatEffectsEnabled: Bool {
        didSet {
            defaults.set(
                playerBackgroundBeatEffectsEnabled,
                forKey: Key.playerBackgroundBeatEffectsEnabled
            )
        }
    }

    var playerBackgroundAudioResponseEnabled: Bool {
        didSet {
            defaults.set(
                playerBackgroundAudioResponseEnabled,
                forKey: Key.playerBackgroundAudioResponseEnabled
            )
        }
    }

    var beatNetDebugEnabled: Bool {
        didSet {
            defaults.set(
                beatNetDebugEnabled,
                forKey: Key.beatNetDebugEnabled
            )
        }
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

    var appleMusicLyricsInterfaceAutoHideDelay: Double {
        didSet {
            defaults.set(
                appleMusicLyricsInterfaceAutoHideDelay,
                forKey: Key.appleMusicLyricsInterfaceAutoHideDelay
            )
        }
    }

    var appleMusicLyricsScrollHideThreshold: Double {
        didSet {
            defaults.set(
                appleMusicLyricsScrollHideThreshold,
                forKey: Key.appleMusicLyricsScrollHideThreshold
            )
        }
    }

    var lyricsFontSize: Double {
        didSet { defaults.set(lyricsFontSize, forKey: Key.lyricsFontSize) }
    }

    var lyricsFontWeight: LyricsFontWeight {
        didSet {
            defaults.set(
                lyricsFontWeight.rawValue,
                forKey: Key.lyricsFontWeight
            )
        }
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

    var lyricsUsesUniformDimmingWhileBrowsing: Bool {
        didSet {
            defaults.set(
                lyricsUsesUniformDimmingWhileBrowsing,
                forKey: Key.lyricsUsesUniformDimmingWhileBrowsing
            )
        }
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

    var lyricsLongPressToShare: Bool {
        didSet {
            defaults.set(
                lyricsLongPressToShare,
                forKey: Key.lyricsLongPressToShare
            )
        }
    }

    var lyricsWordByWord: Bool {
        didSet { defaults.set(lyricsWordByWord, forKey: Key.lyricsWordByWord) }
    }

    var lyricsPseudoWordByWord: Bool {
        didSet { defaults.set(lyricsPseudoWordByWord, forKey: Key.lyricsPseudoWordByWord) }
    }

    var lyricsDuetLayoutEnabled: Bool {
        didSet {
            defaults.set(
                lyricsDuetLayoutEnabled,
                forKey: Key.lyricsDuetLayoutEnabled
            )
        }
    }

    var lyricsAMLLSourceEnabled: Bool {
        didSet {
            defaults.set(
                lyricsAMLLSourceEnabled,
                forKey: Key.lyricsAMLLSourceEnabled
            )
        }
    }

    var lyricsQQMusicSourceEnabled: Bool {
        didSet {
            defaults.set(
                lyricsQQMusicSourceEnabled,
                forKey: Key.lyricsQQMusicSourceEnabled
            )
        }
    }

    var lyricsSourcePreference: LyricSourcePreference {
        didSet {
            defaults.set(
                lyricsSourcePreference.rawValue,
                forKey: Key.lyricsSourcePreference
            )
        }
    }

    var lyricsLiftMode: LyricsLiftMode {
        didSet {
            defaults.set(
                lyricsLiftMode.rawValue,
                forKey: Key.lyricsLiftMode
            )
        }
    }

    var lyricsHighlightGradientWidth: Double {
        didSet {
            defaults.set(
                lyricsHighlightGradientWidth,
                forKey: Key.lyricsHighlightGradientWidth
            )
        }
    }

    var lyricsHighlightGradientReduction: Double {
        didSet {
            defaults.set(
                lyricsHighlightGradientReduction,
                forKey: Key.lyricsHighlightGradientReduction
            )
        }
    }

    var lyricsGlowEnabled: Bool {
        didSet { defaults.set(lyricsGlowEnabled, forKey: Key.lyricsGlowEnabled) }
    }

    var lyricsLongSyllableDetectionMode:
        LyricsLongSyllableDetectionMode {
        didSet {
            defaults.set(
                lyricsLongSyllableDetectionMode.rawValue,
                forKey: Key.lyricsLongSyllableDetectionMode
            )
        }
    }

    var lyricsGlowLongSyllablesOnly: Bool {
        didSet {
            defaults.set(
                lyricsGlowLongSyllablesOnly,
                forKey: Key.lyricsGlowLongSyllablesOnly
            )
        }
    }

    var lyricsLongSyllableDurationThreshold: Double {
        didSet {
            defaults.set(
                lyricsLongSyllableDurationThreshold,
                forKey: Key.lyricsLongSyllableDurationThreshold
            )
        }
    }

    var lyricsLongToneExpansionAmount: Double {
        didSet {
            defaults.set(
                lyricsLongToneExpansionAmount,
                forKey: Key.lyricsLongToneExpansionAmount
            )
        }
    }

    var lyricsGlowIntensity: Double {
        didSet { defaults.set(lyricsGlowIntensity, forKey: Key.lyricsGlowIntensity) }
    }

    var lyricsRomanizationEnabled: Bool {
        didSet {
            defaults.set(
                lyricsRomanizationEnabled,
                forKey: Key.lyricsRomanizationEnabled
            )
        }
    }

    var lyricsRomanizationFontScale: Double {
        didSet {
            defaults.set(
                lyricsRomanizationFontScale,
                forKey: Key.lyricsRomanizationFontScale
            )
        }
    }

    var lyricsRomanizationOpacity: Double {
        didSet {
            defaults.set(
                lyricsRomanizationOpacity,
                forKey: Key.lyricsRomanizationOpacity
            )
        }
    }

    var lyricsRomanizationDisplayMode: LyricsTranslationDisplayMode {
        didSet {
            defaults.set(
                lyricsRomanizationDisplayMode.rawValue,
                forKey: Key.lyricsRomanizationDisplayMode
            )
        }
    }

    var lyricsTranslationEnabled: Bool {
        didSet { defaults.set(lyricsTranslationEnabled, forKey: Key.lyricsTranslationEnabled) }
    }

    var lyricsTranslationDisplayMode: LyricsTranslationDisplayMode {
        didSet {
            defaults.set(
                lyricsTranslationDisplayMode.rawValue,
                forKey: Key.lyricsTranslationDisplayMode
            )
        }
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

    var lyricsFocusCascadeDelayIncrease: Double {
        didSet {
            defaults.set(
                lyricsFocusCascadeDelayIncrease,
                forKey: Key.lyricsFocusCascadeDelayIncrease
            )
        }
    }

    var lyricsFocusCascadeFollowingDelay: Double {
        didSet {
            defaults.set(
                lyricsFocusCascadeFollowingDelay,
                forKey: Key.lyricsFocusCascadeFollowingDelay
            )
        }
    }

    var lyricsFocusCascadeCatchUpRatio: Double {
        didSet {
            defaults.set(
                lyricsFocusCascadeCatchUpRatio,
                forKey: Key.lyricsFocusCascadeCatchUpRatio
            )
        }
    }

    var lyricsFocusCascadeChaseSpeedGradient: Double {
        didSet {
            defaults.set(
                lyricsFocusCascadeChaseSpeedGradient,
                forKey: Key.lyricsFocusCascadeChaseSpeedGradient
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

    var lyricsFocusCascadeBounce: Double {
        didSet {
            defaults.set(
                lyricsFocusCascadeBounce,
                forKey: Key.lyricsFocusCascadeBounce
            )
        }
    }

    var lyricsFocusCascadeBounceGradient: Double {
        didSet {
            defaults.set(
                lyricsFocusCascadeBounceGradient,
                forKey: Key.lyricsFocusCascadeBounceGradient
            )
        }
    }

    var lyricsFocusScaleBounceEnabled: Bool {
        didSet {
            defaults.set(
                lyricsFocusScaleBounceEnabled,
                forKey: Key.lyricsFocusScaleBounceEnabled
            )
        }
    }

    var lyricsFocusScaleBounce: Double {
        didSet {
            defaults.set(
                lyricsFocusScaleBounce,
                forKey: Key.lyricsFocusScaleBounce
            )
        }
    }

    var lyricsFocusScaleBounceDuration: Double {
        didSet {
            defaults.set(
                lyricsFocusScaleBounceDuration,
                forKey: Key.lyricsFocusScaleBounceDuration
            )
        }
    }

    var lyricsFocusCascadeDuration: Double {
        didSet {
            defaults.set(
                lyricsFocusCascadeDuration,
                forKey: Key.lyricsFocusCascadeDuration
            )
        }
    }

    var lyricsFocusSnapThreshold: Double {
        didSet {
            defaults.set(
                lyricsFocusSnapThreshold,
                forKey: Key.lyricsFocusSnapThreshold
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

    var lyricsAdvanceTimeAppliesToWordByWord: Bool {
        didSet {
            defaults.set(
                lyricsAdvanceTimeAppliesToWordByWord,
                forKey: Key.lyricsAdvanceTimeAppliesToWordByWord
            )
        }
    }

    var wordByWordLyricsAdvanceTime: TimeInterval {
        lyricsAdvanceTimeAppliesToWordByWord
            ? lyricsAdvanceTime
            : 0
    }

    func effectiveLyricsAdvanceTime(
        hasSyllableSyncedLyrics: Bool
    ) -> TimeInterval {
        let usesWordByWordPresentation = hasSyllableSyncedLyrics
            ? lyricsWordByWord
            : lyricsPseudoWordByWord
        return usesWordByWordPresentation
            ? wordByWordLyricsAdvanceTime
            : lyricsAdvanceTime
    }

    func effectiveLyricsAdvanceTime(
        for lyrics: [LyricLine]
    ) -> TimeInterval {
        effectiveLyricsAdvanceTime(
            hasSyllableSyncedLyrics:
                lyrics.contains(where: \.isSyllableSynced)
        )
    }

    var lyricsRefreshRate: LyricsRefreshRate {
        didSet { defaults.set(lyricsRefreshRate.rawValue, forKey: Key.lyricsRefreshRate) }
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

    var startsHeartModeOnLaunch: Bool {
        didSet {
            defaults.set(
                startsHeartModeOnLaunch,
                forKey: Key.startsHeartModeOnLaunch
            )
        }
    }

    var recognizesClipboardLinksOnLaunch: Bool {
        didSet {
            defaults.set(
                recognizesClipboardLinksOnLaunch,
                forKey: Key.recognizesClipboardLinksOnLaunch
            )
        }
    }

    var checksUpdatesOnLaunch: Bool {
        didSet { defaults.set(checksUpdatesOnLaunch, forKey: Key.checksUpdatesOnLaunch) }
    }

    var automaticallyCachesFrequentlyPlayedSongs: Bool {
        didSet {
            defaults.set(
                automaticallyCachesFrequentlyPlayedSongs,
                forKey: Key.automaticallyCachesFrequentlyPlayedSongs
            )
        }
    }

    var automaticCachePlaybackThreshold: Int {
        didSet {
            defaults.set(
                automaticCachePlaybackThreshold,
                forKey: Key.automaticCachePlaybackThreshold
            )
        }
    }

    var automaticCacheQuality: MusicQuality {
        didSet {
            defaults.set(
                automaticCacheQuality.rawValue,
                forKey: Key.automaticCacheQuality
            )
        }
    }

    let skylineLyrics: SkylineLyricsPreferences
    let appleMusicLyrics: AppleMusicLyricsPreferences
    let lyricsInterlude: LyricsInterludePreferences
    let textPV: TextPVPreferences
    let equalizer: AudioEqualizerPreferences
    let autoMix: AutoMixPreferences
    let floatingLyrics: FloatingLyricsPreferences
    let lyricsNotifications: LyricsNotificationPreferences
    let songRecognition: SongRecognitionPreferences
    let contentFeatures: ContentFeaturePreferences

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        skylineLyrics = SkylineLyricsPreferences(defaults: defaults)
        appleMusicLyrics = AppleMusicLyricsPreferences(defaults: defaults)
        lyricsInterlude = LyricsInterludePreferences(defaults: defaults)
        textPV = TextPVPreferences(defaults: defaults)
        equalizer = AudioEqualizerPreferences(defaults: defaults)
        autoMix = AutoMixPreferences(defaults: defaults)
        floatingLyrics = FloatingLyricsPreferences(defaults: defaults)
        lyricsNotifications = LyricsNotificationPreferences(
            defaults: defaults
        )
        songRecognition = SongRecognitionPreferences(defaults: defaults)
        contentFeatures = ContentFeaturePreferences(defaults: defaults)
        hasCompletedOnboarding = defaults.bool(
            forKey: Key.hasCompletedOnboarding
        )
        let storedAppLanguage = AppLanguage(
            rawValue: defaults.string(forKey: Key.appLanguage) ?? ""
        ) ?? .system
        appLanguage = storedAppLanguage
        searchSuggestionsEnabled = defaults.object(forKey: Key.searchSuggestionsEnabled) as? Bool ?? true
        L10n.activate(storedAppLanguage)
        cookie = defaults.string(forKey: Key.cookie) ?? ""
        quality = MusicQuality(rawValue: defaults.string(forKey: Key.quality) ?? "") ?? .high
        cellularQuality = MusicQuality(
            rawValue: defaults.string(forKey: Key.cellularQuality) ?? ""
        ) ?? .high
        playerVolumeControlMode = PlayerVolumeControlMode(
            rawValue: defaults.string(forKey: Key.playerVolumeControlMode) ?? ""
        ) ?? Self.defaultPlayerVolumeControlMode
        systemNowPlayingLyricsEnabled = defaults.object(
            forKey: Key.systemNowPlayingLyricsEnabled
        ) as? Bool
            ?? defaults.object(
                forKey: "dynamicIslandLyricsEnabled"
            ) as? Bool
            ?? Self.defaultSystemNowPlayingLyricsEnabled
        systemNowPlayingLyricsTitleFormat = defaults.string(
            forKey: Key.systemNowPlayingLyricsTitleFormat
        )
            ?? defaults.string(forKey: "dynamicIslandLyricsTitleFormat")
            ?? Self.defaultSystemNowPlayingLyricsTitleFormat
        systemNowPlayingLyricsSubtitleFormat = defaults.string(
            forKey: Key.systemNowPlayingLyricsSubtitleFormat
        )
            ?? defaults.string(forKey: "dynamicIslandLyricsSubtitleFormat")
            ?? Self.defaultSystemNowPlayingLyricsSubtitleFormat
        lyricsLiveActivityEnabled = defaults.object(
            forKey: Key.lyricsLiveActivityEnabled
        ) as? Bool ?? Self.defaultLyricsLiveActivityEnabled
        lyricsLiveActivityTitleFormat = defaults.string(
            forKey: Key.lyricsLiveActivityTitleFormat
        ) ?? Self.defaultLyricsLiveActivityTitleFormat
        lyricsLiveActivitySubtitleFormat = defaults.string(
            forKey: Key.lyricsLiveActivitySubtitleFormat
        ) ?? Self.defaultLyricsLiveActivitySubtitleFormat
        lyricsLiveActivityCompactFormat = defaults.string(
            forKey: Key.lyricsLiveActivityCompactFormat
        ) ?? Self.defaultLyricsLiveActivityCompactFormat
        lyricsLiveActivityShowsArtwork = defaults.object(
            forKey: Key.lyricsLiveActivityShowsArtwork
        ) as? Bool ?? Self.defaultLyricsLiveActivityShowsArtwork
        lyricsLiveActivityShowsNextLyric = defaults.object(
            forKey: Key.lyricsLiveActivityShowsNextLyric
        ) as? Bool ?? Self.defaultLyricsLiveActivityShowsNextLyric
        lyricsLiveActivityShowsProgress = defaults.object(
            forKey: Key.lyricsLiveActivityShowsProgress
        ) as? Bool ?? Self.defaultLyricsLiveActivityShowsProgress
        lyricsLiveActivityScrollsCompactText = defaults.object(
            forKey: Key.lyricsLiveActivityScrollsCompactText
        ) as? Bool ?? Self.defaultLyricsLiveActivityScrollsCompactText
        lyricsLiveActivityCompactTextSize =
            LyricsLiveActivityCompactTextSize(
                rawValue: defaults.string(
                    forKey: Key.lyricsLiveActivityCompactTextSize
                ) ?? ""
            ) ?? Self.defaultLyricsLiveActivityCompactTextSize
        lyricsLiveActivityScrollSpeed = defaults.object(
            forKey: Key.lyricsLiveActivityScrollSpeed
        ) as? Double ?? Self.defaultLyricsLiveActivityScrollSpeed
        lyricsLiveActivityScrollPause = defaults.object(
            forKey: Key.lyricsLiveActivityScrollPause
        ) as? Double ?? Self.defaultLyricsLiveActivityScrollPause
        appearance = AppAppearance(
            rawValue: defaults.string(forKey: Key.appearance) ?? ""
        ) ?? .system
        defaultLaunchTab = AppTab(
            rawValue: defaults.string(forKey: Key.defaultLaunchTab) ?? ""
        ) ?? .home
        restoresLastSelectedTab = defaults.object(
            forKey: Key.restoresLastSelectedTab
        ) as? Bool ?? false
        lastSelectedTab = AppTab(
            rawValue: defaults.string(forKey: Key.lastSelectedTab) ?? ""
        ) ?? .home
        defaultLibraryPage = LibraryPage(
            rawValue: defaults.string(forKey: Key.defaultLibraryPage) ?? ""
        ) ?? .songs
        restoresLastLibraryPage = defaults.object(
            forKey: Key.restoresLastLibraryPage
        ) as? Bool ?? false
        lastLibraryPage = LibraryPage(
            rawValue: defaults.string(forKey: Key.lastLibraryPage) ?? ""
        ) ?? .songs
        let storedSeparatedPages = (
            defaults.array(forKey: Key.separatedLibraryPages) as? [String]
        )?.compactMap(LibraryPage.init(rawValue:))
        let normalizedSeparatedPages = Self.normalizedLibraryPages(
            storedSeparatedPages ?? [.cloud]
        )
        separatedLibraryPages = normalizedSeparatedPages
        let storedHomeTabOrder = (
            defaults.array(forKey: Key.homeTabOrder) as? [String]
        )?.compactMap(AppTab.init(rawValue:))
        let normalizedHomeTabOrder = Self.normalizedHomeTabOrder(
            storedHomeTabOrder
                ?? [.recommended, .music, .podcasts],
            separatedLibraryPages: normalizedSeparatedPages
        )
        homeTabOrder = normalizedHomeTabOrder
        let storedTabOrder = (
            defaults.array(forKey: Key.tabOrder) as? [String]
        )?.compactMap(AppTab.init(rawValue:)) ?? []
        tabOrder = Self.normalizedTabOrder(
            storedTabOrder,
            separatedLibraryPages: normalizedSeparatedPages,
            homeTabs: normalizedHomeTabOrder
        )
        musicArea = defaults.string(forKey: Key.area) ?? "ALL"
        showPlayCount = defaults.object(forKey: Key.showPlayCount) as? Bool ?? true
        playerBackgroundStyle = PlayerBackgroundStyle(
            rawValue: defaults.string(
                forKey: Key.playerBackgroundStyle
            ) ?? ""
        ) ?? Self.defaultPlayerBackgroundStyle
        let storedPlayerBackgroundMotionIntensity = defaults.object(
            forKey: Key.playerBackgroundMotionIntensity
        ) as? Double ?? Self.defaultPlayerBackgroundMotionIntensity
        playerBackgroundMotionIntensity = min(
            max(storedPlayerBackgroundMotionIntensity, 0.4),
            1.4
        )
        playerBackgroundBeatEffectsEnabled = defaults.object(
            forKey: Key.playerBackgroundBeatEffectsEnabled
        ) as? Bool ?? Self.defaultPlayerBackgroundBeatEffectsEnabled
        playerBackgroundAudioResponseEnabled = defaults.object(
            forKey: Key.playerBackgroundAudioResponseEnabled
        ) as? Bool ?? Self.defaultPlayerBackgroundAudioResponseEnabled
        beatNetDebugEnabled = defaults.object(
            forKey: Key.beatNetDebugEnabled
        ) as? Bool ?? Self.defaultBeatNetDebugEnabled
        playerBackgroundBlur = defaults.object(forKey: Key.playerBackgroundBlur) as? Double ?? 90
        playerBackgroundSaturation = defaults.object(
            forKey: Key.playerBackgroundSaturation
        ) as? Double ?? Self.defaultPlayerBackgroundSaturation
        shrinksPausedArtwork = defaults.object(forKey: Key.shrinksPausedArtwork) as? Bool ?? true
        let storedLyricsStyle = defaults.string(forKey: Key.lyricsStyle) ?? ""
        switch storedLyricsStyle {
        case "spotlight":
            lyricsStyle = .eva
        default:
            lyricsStyle = LyricsStyle(rawValue: storedLyricsStyle) ?? .appleMusic
        }
        let storedAppleMusicInterfaceAutoHideDelay = defaults.object(
            forKey: Key.appleMusicLyricsInterfaceAutoHideDelay
        ) as? Double ?? Self.defaultAppleMusicLyricsInterfaceAutoHideDelay
        appleMusicLyricsInterfaceAutoHideDelay = min(
            max(
                storedAppleMusicInterfaceAutoHideDelay,
                Self.appleMusicLyricsInterfaceAutoHideDelayRange.lowerBound
            ),
            Self.appleMusicLyricsInterfaceAutoHideDelayRange.upperBound
        )
        let storedAppleMusicScrollHideThreshold = defaults.object(
            forKey: Key.appleMusicLyricsScrollHideThreshold
        ) as? Double ?? Self.defaultAppleMusicLyricsScrollHideThreshold
        appleMusicLyricsScrollHideThreshold = min(
            max(
                storedAppleMusicScrollHideThreshold,
                Self.appleMusicLyricsScrollHideThresholdRange.lowerBound
            ),
            Self.appleMusicLyricsScrollHideThresholdRange.upperBound
        )
        lyricsFontSize = defaults.object(
            forKey: Key.lyricsFontSize
        ) as? Double ?? Self.defaultLyricsFontSize
        lyricsFontWeight = LyricsFontWeight(
            rawValue: defaults.string(forKey: Key.lyricsFontWeight) ?? ""
        ) ?? Self.defaultLyricsFontWeight
        let storedLyricsCurrentLineScale = defaults.object(
            forKey: Key.lyricsCurrentLineScale
        ) as? Double ?? Self.defaultLyricsCurrentLineScale
        lyricsCurrentLineScale = min(
            max(
                storedLyricsCurrentLineScale,
                Self.lyricsCurrentLineScaleRange.lowerBound
            ),
            Self.lyricsCurrentLineScaleRange.upperBound
        )
        lyricsLineSpacing = defaults.object(
            forKey: Key.lyricsLineSpacing
        ) as? Double ?? Self.defaultLyricsLineSpacing
        lyricsBlurIntensity = defaults.object(forKey: Key.lyricsBlurIntensity) as? Double
            ?? Self.defaultLyricsBlurIntensity
        lyricsUsesUniformDimmingWhileBrowsing = defaults.object(
            forKey: Key.lyricsUsesUniformDimmingWhileBrowsing
        ) as? Bool ?? Self.defaultLyricsUsesUniformDimmingWhileBrowsing
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
        lyricsLongPressToShare = defaults.object(
            forKey: Key.lyricsLongPressToShare
        ) as? Bool ?? true
        lyricsWordByWord = defaults.object(forKey: Key.lyricsWordByWord) as? Bool ?? true
        lyricsPseudoWordByWord = defaults.object(forKey: Key.lyricsPseudoWordByWord) as? Bool ?? false
        lyricsDuetLayoutEnabled = defaults.object(
            forKey: Key.lyricsDuetLayoutEnabled
        ) as? Bool ?? true
        lyricsAMLLSourceEnabled = defaults.object(
            forKey: Key.lyricsAMLLSourceEnabled
        ) as? Bool ?? true
        lyricsQQMusicSourceEnabled = defaults.object(
            forKey: Key.lyricsQQMusicSourceEnabled
        ) as? Bool ?? true
        lyricsSourcePreference = LyricSourcePreference(
            rawValue: defaults.string(
                forKey: Key.lyricsSourcePreference
            ) ?? ""
        ) ?? Self.defaultLyricsSourcePreference
        lyricsLiftMode = LyricsLiftMode(
            rawValue: defaults.string(forKey: Key.lyricsLiftMode) ?? ""
        ) ?? Self.defaultLyricsLiftMode
        let storedLyricsHighlightGradientWidth = defaults.object(
            forKey: Key.lyricsHighlightGradientWidth
        ) as? Double ?? Self.defaultLyricsHighlightGradientWidth
        lyricsHighlightGradientWidth = min(
            max(
                storedLyricsHighlightGradientWidth,
                Self.lyricsHighlightGradientWidthRange.lowerBound
            ),
            Self.lyricsHighlightGradientWidthRange.upperBound
        )
        let storedLyricsHighlightGradientReduction = defaults.object(
            forKey: Key.lyricsHighlightGradientReduction
        ) as? Double ?? Self.defaultLyricsHighlightGradientReduction
        lyricsHighlightGradientReduction = min(
            max(
                storedLyricsHighlightGradientReduction,
                Self.lyricsHighlightGradientReductionRange.lowerBound
            ),
            Self.lyricsHighlightGradientReductionRange.upperBound
        )
        lyricsGlowEnabled = defaults.object(forKey: Key.lyricsGlowEnabled) as? Bool ?? true
        lyricsLongSyllableDetectionMode =
            LyricsLongSyllableDetectionMode(
                rawValue: defaults.string(
                    forKey: Key.lyricsLongSyllableDetectionMode
                ) ?? ""
            ) ?? Self.defaultLyricsLongSyllableDetectionMode
        lyricsGlowLongSyllablesOnly = defaults.object(
            forKey: Key.lyricsGlowLongSyllablesOnly
        ) as? Bool ?? Self.defaultLyricsGlowLongSyllablesOnly
        let storedLongSyllableDurationThreshold = defaults.object(
            forKey: Key.lyricsLongSyllableDurationThreshold
        ) as? Double ?? Self.defaultLyricsLongSyllableDurationThreshold
        lyricsLongSyllableDurationThreshold = min(
            max(
                storedLongSyllableDurationThreshold,
                Self.lyricsLongSyllableDurationThresholdRange.lowerBound
            ),
            Self.lyricsLongSyllableDurationThresholdRange.upperBound
        )
        let storedLyricsLongToneExpansionAmount = defaults.object(
            forKey: Key.lyricsLongToneExpansionAmount
        ) as? Double ?? Self.defaultLyricsLongToneExpansionAmount
        lyricsLongToneExpansionAmount = min(
            max(
                storedLyricsLongToneExpansionAmount,
                Self.lyricsLongToneExpansionAmountRange.lowerBound
            ),
            Self.lyricsLongToneExpansionAmountRange.upperBound
        )
        lyricsGlowIntensity = defaults.object(forKey: Key.lyricsGlowIntensity) as? Double ?? 1
        lyricsRomanizationEnabled = defaults.object(
            forKey: Key.lyricsRomanizationEnabled
        ) as? Bool ?? true
        lyricsRomanizationFontScale = defaults.object(
            forKey: Key.lyricsRomanizationFontScale
        ) as? Double ?? Self.defaultLyricsRomanizationFontScale
        lyricsRomanizationOpacity = defaults.object(
            forKey: Key.lyricsRomanizationOpacity
        ) as? Double ?? Self.defaultLyricsRomanizationOpacity
        lyricsRomanizationDisplayMode = LyricsTranslationDisplayMode(
            rawValue: defaults.string(
                forKey: Key.lyricsRomanizationDisplayMode
            ) ?? ""
        ) ?? .allLines
        lyricsTranslationEnabled = defaults.object(forKey: Key.lyricsTranslationEnabled) as? Bool ?? true
        lyricsTranslationDisplayMode = LyricsTranslationDisplayMode(
            rawValue: defaults.string(forKey: Key.lyricsTranslationDisplayMode) ?? ""
        ) ?? .focusedLine
        lyricsTranslationFontScale = defaults.object(
            forKey: Key.lyricsTranslationFontScale
        ) as? Double ?? Self.defaultLyricsTranslationFontScale
        lyricsTranslationOpacity = defaults.object(
            forKey: Key.lyricsTranslationOpacity
        ) as? Double ?? Self.defaultLyricsTranslationOpacity
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
        let storedFocusCascadeDelayIncrease = defaults.object(
            forKey: Key.lyricsFocusCascadeDelayIncrease
        ) as? Double ?? Self.defaultLyricsFocusCascadeDelayIncrease
        lyricsFocusCascadeDelayIncrease = min(
            max(
                storedFocusCascadeDelayIncrease,
                Self.lyricsFocusCascadeDelayIncreaseRange.lowerBound
            ),
            Self.lyricsFocusCascadeDelayIncreaseRange.upperBound
        )
        let storedFocusCascadeFollowingDelay = defaults.object(
            forKey: Key.lyricsFocusCascadeFollowingDelay
        ) as? Double ?? Self.defaultLyricsFocusCascadeFollowingDelay
        lyricsFocusCascadeFollowingDelay = min(
            max(
                storedFocusCascadeFollowingDelay,
                Self.lyricsFocusCascadeFollowingDelayRange.lowerBound
            ),
            Self.lyricsFocusCascadeFollowingDelayRange.upperBound
        )
        let storedFocusCascadeCatchUpRatio = defaults.object(
            forKey: Key.lyricsFocusCascadeCatchUpRatio
        ) as? Double ?? Self.defaultLyricsFocusCascadeCatchUpRatio
        lyricsFocusCascadeCatchUpRatio = min(
            max(
                storedFocusCascadeCatchUpRatio,
                Self.lyricsFocusCascadeCatchUpRatioRange.lowerBound
            ),
            Self.lyricsFocusCascadeCatchUpRatioRange.upperBound
        )
        let storedFocusCascadeChaseSpeedGradient = defaults.object(
            forKey: Key.lyricsFocusCascadeChaseSpeedGradient
        ) as? Double ?? Self.defaultLyricsFocusCascadeChaseSpeedGradient
        lyricsFocusCascadeChaseSpeedGradient = min(
            max(
                storedFocusCascadeChaseSpeedGradient,
                Self.lyricsFocusCascadeChaseSpeedGradientRange.lowerBound
            ),
            Self.lyricsFocusCascadeChaseSpeedGradientRange.upperBound
        )
        lyricsFocusCascadeBounceEnabled = defaults.object(
            forKey: Key.lyricsFocusCascadeBounceEnabled
        ) as? Bool ?? Self.defaultLyricsFocusCascadeBounceEnabled
        let storedFocusCascadeBounce = defaults.object(
            forKey: Key.lyricsFocusCascadeBounce
        ) as? Double ?? Self.defaultLyricsFocusCascadeBounce
        lyricsFocusCascadeBounce = min(
            max(
                storedFocusCascadeBounce,
                Self.lyricsFocusCascadeBounceRange.lowerBound
            ),
            Self.lyricsFocusCascadeBounceRange.upperBound
        )
        let storedFocusCascadeBounceGradient = defaults.object(
            forKey: Key.lyricsFocusCascadeBounceGradient
        ) as? Double ?? Self.defaultLyricsFocusCascadeBounceGradient
        lyricsFocusCascadeBounceGradient = min(
            max(
                storedFocusCascadeBounceGradient,
                Self.lyricsFocusCascadeBounceGradientRange.lowerBound
            ),
            Self.lyricsFocusCascadeBounceGradientRange.upperBound
        )
        lyricsFocusScaleBounceEnabled = defaults.object(
            forKey: Key.lyricsFocusScaleBounceEnabled
        ) as? Bool ?? Self.defaultLyricsFocusScaleBounceEnabled
        let storedFocusScaleBounce = defaults.object(
            forKey: Key.lyricsFocusScaleBounce
        ) as? Double ?? Self.defaultLyricsFocusScaleBounce
        lyricsFocusScaleBounce = min(
            max(
                storedFocusScaleBounce,
                Self.lyricsFocusScaleBounceRange.lowerBound
            ),
            Self.lyricsFocusScaleBounceRange.upperBound
        )
        let storedFocusScaleBounceDuration = defaults.object(
            forKey: Key.lyricsFocusScaleBounceDuration
        ) as? Double ?? Self.defaultLyricsFocusScaleBounceDuration
        lyricsFocusScaleBounceDuration = min(
            max(
                storedFocusScaleBounceDuration,
                Self.lyricsFocusScaleBounceDurationRange.lowerBound
            ),
            Self.lyricsFocusScaleBounceDurationRange.upperBound
        )
        let storedFocusCascadeDuration = defaults.object(
            forKey: Key.lyricsFocusCascadeDuration
        ) as? Double
            ?? defaults.object(
                forKey: Key.legacyLyricsFocusCascadeMinimumBounceDuration
            ) as? Double
            ?? Self.defaultLyricsFocusCascadeDuration
        lyricsFocusCascadeDuration = min(
            max(
                storedFocusCascadeDuration,
                Self.lyricsFocusCascadeDurationRange.lowerBound
            ),
            Self.lyricsFocusCascadeDurationRange.upperBound
        )
        let storedFocusSnapThreshold = defaults.object(
            forKey: Key.lyricsFocusSnapThreshold
        ) as? Double ?? Self.defaultLyricsFocusSnapThreshold
        lyricsFocusSnapThreshold = min(
            max(
                storedFocusSnapThreshold,
                Self.lyricsFocusSnapThresholdRange.lowerBound
            ),
            Self.lyricsFocusSnapThresholdRange.upperBound
        )
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
        lyricsAdvanceTimeAppliesToWordByWord =
            defaults.object(
                forKey: Key.lyricsAdvanceTimeAppliesToWordByWord
            ) as? Bool ?? false
        lyricsRefreshRate = LyricsRefreshRate(
            rawValue: defaults.object(forKey: Key.lyricsRefreshRate) as? Int ?? 0
        ) ?? .defaultValue
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
        startsHeartModeOnLaunch = defaults.object(
            forKey: Key.startsHeartModeOnLaunch
        ) as? Bool ?? Self.defaultStartsHeartModeOnLaunch
        recognizesClipboardLinksOnLaunch = defaults.object(
            forKey: Key.recognizesClipboardLinksOnLaunch
        ) as? Bool ?? Self.defaultRecognizesClipboardLinksOnLaunch
        checksUpdatesOnLaunch = defaults.object(forKey: Key.checksUpdatesOnLaunch) as? Bool ?? true
        automaticallyCachesFrequentlyPlayedSongs = defaults.object(
            forKey: Key.automaticallyCachesFrequentlyPlayedSongs
        ) as? Bool ?? false
        let storedAutomaticCacheThreshold = defaults.integer(
            forKey: Key.automaticCachePlaybackThreshold
        )
        automaticCachePlaybackThreshold = Self.automaticCachePlaybackThresholdOptions.contains(
            storedAutomaticCacheThreshold
        ) ? storedAutomaticCacheThreshold : 5
        automaticCacheQuality = MusicQuality(
            rawValue: defaults.string(forKey: Key.automaticCacheQuality) ?? ""
        ) ?? .high
        normalizeNavigationSelections()
    }

    func setAppLanguage(_ language: AppLanguage) {
        guard appLanguage != language else { return }
        L10n.activate(language)
        defaults.set(language.rawValue, forKey: Key.appLanguage)
        appLanguage = language
    }

    private func normalizeNavigationSelections() {
        defaultLaunchTab = normalizedNavigationTab(
            for: defaultLaunchTab
        )
        lastSelectedTab = normalizedNavigationTab(
            for: lastSelectedTab
        )

        let embeddedPages = embeddedLibraryPages
        if let firstEmbeddedPage = embeddedPages.first {
            if !embeddedPages.contains(defaultLibraryPage) {
                defaultLibraryPage = firstEmbeddedPage
            }
            if !embeddedPages.contains(lastLibraryPage) {
                lastLibraryPage = firstEmbeddedPage
            }
        }
    }

    private func normalizedNavigationTab(
        for requestedTab: AppTab
    ) -> AppTab {
        if visibleTabs.contains(requestedTab) {
            return requestedTab
        }
        if homeTabs.contains(requestedTab),
           visibleTabs.contains(.home) {
            return .home
        }
        if requestedTab.libraryPage != nil,
           visibleTabs.contains(.library) {
            return .library
        }
        return fallbackNavigationTab
    }

    private static func normalizedLibraryPages(
        _ pages: [LibraryPage]
    ) -> [LibraryPage] {
        let pageSet = Set(pages)
        return LibraryPage.availableCases.filter(pageSet.contains)
    }

    private static func normalizedHomeTabOrder(
        _ tabs: [AppTab],
        separatedLibraryPages: [LibraryPage]
    ) -> [AppTab] {
        let allowedTabs = Set(
            AppTab.movablePrimaryContentPages
                + separatedLibraryPages.map(
                    AppTab.init(libraryPage:)
                )
        )
        var seen: Set<AppTab> = [.recommended]
        var normalized: [AppTab] = [.recommended]

        for tab in tabs
        where allowedTabs.contains(tab)
            && seen.insert(tab).inserted {
            normalized.append(tab)
        }
        return normalized
    }

    private static func normalizedTabOrder(
        _ tabs: [AppTab],
        separatedLibraryPages: [LibraryPage],
        homeTabs: [AppTab]
    ) -> [AppTab] {
        let separatedSet = Set(separatedLibraryPages)
        let embeddedPages = LibraryPage.availableCases.filter {
            !separatedSet.contains($0)
        }
        let homeTabSet = Set(homeTabs)
        var defaultVisibleTabs: [AppTab] = [.home]

        for tab in AppTab.movablePrimaryContentPages
        where !homeTabSet.contains(tab) {
            if tab != .library || !embeddedPages.isEmpty {
                defaultVisibleTabs.append(tab)
            }
        }
        defaultVisibleTabs.append(
            contentsOf: separatedLibraryPages
                .map(AppTab.init(libraryPage:))
                .filter { !homeTabSet.contains($0) }
        )
        defaultVisibleTabs.append(.search)

        let allowedTabs = Set(defaultVisibleTabs)
        var seen = Set<AppTab>()
        var normalized = tabs.filter {
            allowedTabs.contains($0) && seen.insert($0).inserted
        }

        for tab in defaultVisibleTabs
        where !seen.contains(tab) {
            let defaultIndex = defaultVisibleTabs.firstIndex(of: tab)
                ?? defaultVisibleTabs.endIndex
            let followingTab = defaultVisibleTabs
                .dropFirst(defaultIndex + 1)
                .first(where: normalized.contains)

            if let followingTab,
               let insertionIndex = normalized.firstIndex(of: followingTab) {
                normalized.insert(tab, at: insertionIndex)
            } else {
                normalized.append(tab)
            }
            seen.insert(tab)
        }

        normalized.removeAll(where: { $0 == .home })
        normalized.insert(.home, at: 0)
        normalized.removeAll(where: { $0 == .search })
        normalized.append(.search)

        return normalized
    }

    private static func appendIfNeeded(
        _ tab: AppTab,
        to tabs: inout [AppTab]
    ) {
        guard !tabs.contains(tab) else { return }
        tabs.append(tab)
    }

    func clearAccount() {
        cookie = ""
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func resetPlayerSettings() {
        quality = .high
        cellularQuality = .high
        playerVolumeControlMode = Self.defaultPlayerVolumeControlMode
        systemNowPlayingLyricsEnabled =
            Self.defaultSystemNowPlayingLyricsEnabled
        systemNowPlayingLyricsTitleFormat =
            Self.defaultSystemNowPlayingLyricsTitleFormat
        systemNowPlayingLyricsSubtitleFormat =
            Self.defaultSystemNowPlayingLyricsSubtitleFormat
        lyricsLiveActivityEnabled =
            Self.defaultLyricsLiveActivityEnabled
        lyricsLiveActivityTitleFormat =
            Self.defaultLyricsLiveActivityTitleFormat
        lyricsLiveActivitySubtitleFormat =
            Self.defaultLyricsLiveActivitySubtitleFormat
        lyricsLiveActivityCompactFormat =
            Self.defaultLyricsLiveActivityCompactFormat
        lyricsLiveActivityShowsArtwork =
            Self.defaultLyricsLiveActivityShowsArtwork
        lyricsLiveActivityShowsNextLyric =
            Self.defaultLyricsLiveActivityShowsNextLyric
        lyricsLiveActivityShowsProgress =
            Self.defaultLyricsLiveActivityShowsProgress
        lyricsLiveActivityScrollsCompactText =
            Self.defaultLyricsLiveActivityScrollsCompactText
        lyricsLiveActivityCompactTextSize =
            Self.defaultLyricsLiveActivityCompactTextSize
        lyricsLiveActivityScrollSpeed =
            Self.defaultLyricsLiveActivityScrollSpeed
        lyricsLiveActivityScrollPause =
            Self.defaultLyricsLiveActivityScrollPause
        equalizer.reset()
        autoMix.reset()
        playerBackgroundStyle =
            Self.defaultPlayerBackgroundStyle
        playerBackgroundMotionIntensity =
            Self.defaultPlayerBackgroundMotionIntensity
        playerBackgroundBeatEffectsEnabled =
            Self.defaultPlayerBackgroundBeatEffectsEnabled
        playerBackgroundAudioResponseEnabled =
            Self.defaultPlayerBackgroundAudioResponseEnabled
        beatNetDebugEnabled =
            Self.defaultBeatNetDebugEnabled
        playerBackgroundBlur = 90
        playerBackgroundSaturation =
            Self.defaultPlayerBackgroundSaturation
        shrinksPausedArtwork = true
        lyricsStyle = .appleMusic
        lyricsInterlude.reset()
        appleMusicLyricsInterfaceAutoHideDelay =
            Self.defaultAppleMusicLyricsInterfaceAutoHideDelay
        appleMusicLyricsScrollHideThreshold =
            Self.defaultAppleMusicLyricsScrollHideThreshold
        lyricsFontSize = Self.defaultLyricsFontSize
        lyricsFontWeight = Self.defaultLyricsFontWeight
        lyricsCurrentLineScale = Self.defaultLyricsCurrentLineScale
        lyricsLineSpacing = Self.defaultLyricsLineSpacing
        lyricsBlurIntensity = Self.defaultLyricsBlurIntensity
        lyricsUsesUniformDimmingWhileBrowsing =
            Self.defaultLyricsUsesUniformDimmingWhileBrowsing
        lyricsDistanceBlurScale = Self.defaultLyricsDistanceBlurScale
        lyricsHiddenInterfaceBlurScale = Self.defaultLyricsHiddenInterfaceBlurScale
        lyricsDimAmount = Self.defaultLyricsDimAmount
        lyricsTapToSeek = true
        lyricsLongPressToShare = true
        lyricsWordByWord = true
        lyricsPseudoWordByWord = false
        lyricsDuetLayoutEnabled = true
        lyricsAMLLSourceEnabled = true
        lyricsQQMusicSourceEnabled = true
        lyricsSourcePreference = Self.defaultLyricsSourcePreference
        lyricsLiftMode = Self.defaultLyricsLiftMode
        lyricsHighlightGradientWidth =
            Self.defaultLyricsHighlightGradientWidth
        lyricsHighlightGradientReduction =
            Self.defaultLyricsHighlightGradientReduction
        lyricsGlowEnabled = true
        lyricsLongSyllableDetectionMode =
            Self.defaultLyricsLongSyllableDetectionMode
        lyricsGlowLongSyllablesOnly =
            Self.defaultLyricsGlowLongSyllablesOnly
        lyricsLongSyllableDurationThreshold =
            Self.defaultLyricsLongSyllableDurationThreshold
        lyricsLongToneExpansionAmount =
            Self.defaultLyricsLongToneExpansionAmount
        lyricsGlowIntensity = 1
        lyricsRomanizationEnabled = true
        lyricsRomanizationFontScale =
            Self.defaultLyricsRomanizationFontScale
        lyricsRomanizationOpacity =
            Self.defaultLyricsRomanizationOpacity
        lyricsRomanizationDisplayMode = .allLines
        lyricsTranslationEnabled = true
        lyricsTranslationDisplayMode = .focusedLine
        lyricsTranslationFontScale = Self.defaultLyricsTranslationFontScale
        lyricsTranslationOpacity = Self.defaultLyricsTranslationOpacity
        lyricsAutoFollow = true
        lyricsFollowDelay = 3
        lyricsFocusPosition = Self.defaultLyricsFocusPosition
        lyricsFocusCascadeDelay = Self.defaultLyricsFocusCascadeDelay
        lyricsFocusCascadeDelayIncrease =
            Self.defaultLyricsFocusCascadeDelayIncrease
        lyricsFocusCascadeFollowingDelay =
            Self.defaultLyricsFocusCascadeFollowingDelay
        lyricsFocusCascadeCatchUpRatio =
            Self.defaultLyricsFocusCascadeCatchUpRatio
        lyricsFocusCascadeChaseSpeedGradient =
            Self.defaultLyricsFocusCascadeChaseSpeedGradient
        lyricsFocusCascadeBounceEnabled = Self.defaultLyricsFocusCascadeBounceEnabled
        lyricsFocusCascadeBounce = Self.defaultLyricsFocusCascadeBounce
        lyricsFocusCascadeBounceGradient =
            Self.defaultLyricsFocusCascadeBounceGradient
        lyricsFocusScaleBounceEnabled = Self.defaultLyricsFocusScaleBounceEnabled
        lyricsFocusScaleBounce = Self.defaultLyricsFocusScaleBounce
        lyricsFocusScaleBounceDuration =
            Self.defaultLyricsFocusScaleBounceDuration
        lyricsFocusCascadeDuration = Self.defaultLyricsFocusCascadeDuration
        lyricsFocusSnapThreshold = Self.defaultLyricsFocusSnapThreshold
        lyricsFocusColorLeadTime = Self.defaultLyricsFocusColorLeadTime
        lyricsAdvanceTime = 0.2
        lyricsAdvanceTimeAppliesToWordByWord = false
        lyricsRefreshRate = .defaultValue
        textPV.reset()
        floatingLyrics.reset()
        lyricsNotifications.reset()
        playerScreenAwakeMode = .lyrics
        rememberNowPlayingPage = false
        rememberedNowPlayingPage = "artwork"
        previousRestartsCurrentSong = true
        startsHeartModeOnLaunch = Self.defaultStartsHeartModeOnLaunch
        appleMusicLyrics.reset()
        skylineLyrics.reset()
    }
}
