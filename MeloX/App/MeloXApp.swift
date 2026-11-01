import Foundation
import SwiftUI

@main
struct MeloXApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var settings: AppSettings
    @State private var api: NeteaseAPI
    @State private var library: LibraryStore
    @State private var cloud: CloudMusicStore
    @State private var downloads: DownloadStore
    @State private var player: PlayerStore
    @State private var phoneWatchSync: PhoneWatchSyncService
    @State private var listenTogether: ListenTogetherStore
    @State private var lyrics: LyricsStore
    @State private var floatingLyrics: FloatingLyricsController
    @State private var lyricsNotifications:
        LyricsNotificationController
    @State private var screenAwakeCoordinator: ScreenAwakeCoordinator
    @State private var releaseNotes: AppReleaseNotesStore
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    init() {
        let settings = AppSettings()
        #if DEBUG && targetEnvironment(simulator)
        if MeloXDesignPreview.isEnabled {
            settings.hasCompletedOnboarding = true
            settings.setAppLanguage(.simplifiedChinese)
            settings.lastSelectedTab = .home
            if ProcessInfo.processInfo.environment["MELOX_UI_LIBRARY_HOME"] == "1" {
                settings.setPage(.libraryAlbums, placement: .home)
            }
        }
        #endif
        let releaseNotes = AppReleaseNotesStore(
            currentVersion: Bundle.main.appReleaseVersion,
            hadCompletedOnboarding: settings.hasCompletedOnboarding,
            currentReleaseNotes: AppReleaseNotesLoader.load()
        )
        let api = NeteaseAPI(settings: settings)
        let library = LibraryStore(api: api, settings: settings)
        let cloud = CloudMusicStore(api: api, settings: settings)
        let downloads = DownloadStore(api: api, settings: settings)
        let lyricsNotifications = LyricsNotificationController(
            preferences: settings.lyricsNotifications
        )
        let player = PlayerStore(
            api: api,
            settings: settings,
            downloads: downloads,
            lyricsNotificationController: lyricsNotifications,
            onPlaybackRecorded: { song in
                library.recordRecentlyPlayed(song)
            }
        )
        let listenTogether = ListenTogetherStore(
            api: api,
            player: player
        )
        let phoneWatchSync = PhoneWatchSyncService(
            settings: settings
        )
        let lyricService = LyricsService(api: api, settings: settings)
        let lyrics = LyricsStore(service: lyricService)
        let floatingLyrics = FloatingLyricsController(
            player: player,
            settings: settings,
            lyricsStore: lyrics
        )
        _settings = State(initialValue: settings)
        _api = State(initialValue: api)
        _library = State(initialValue: library)
        _cloud = State(initialValue: cloud)
        _downloads = State(initialValue: downloads)
        _player = State(initialValue: player)
        _phoneWatchSync = State(initialValue: phoneWatchSync)
        _listenTogether = State(initialValue: listenTogether)
        _lyrics = State(initialValue: lyrics)
        _floatingLyrics = State(initialValue: floatingLyrics)
        _lyricsNotifications = State(
            initialValue: lyricsNotifications
        )
        _screenAwakeCoordinator = State(initialValue: ScreenAwakeCoordinator())
        _releaseNotes = State(initialValue: releaseNotes)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(initialTab: settings.launchTab)
                .environment(settings)
                .environment(api)
                .environment(library)
                .environment(cloud)
                .environment(downloads)
                .environment(player)
                .environment(listenTogether)
                .environment(lyrics)
                .environment(floatingLyrics)
                .environment(lyricsNotifications)
                .environment(screenAwakeCoordinator)
                .environment(releaseNotes)
                .environment(\.effectiveLyricsRefreshRate, effectiveLyricsRefreshRate)
                .environment(\.locale, settings.appLanguage.locale)
                .tint(.red)
                .preferredColorScheme(
                    settings.appearance.preferredColorScheme
                )
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: .NSProcessInfoPowerStateDidChange
                    )
                ) { _ in
                    isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
                .task {
                    phoneWatchSync.start()
                    await lyricsNotifications
                        .refreshAuthorizationStatus()
                }
                .onChange(of: scenePhase) {
                    guard scenePhase == .active else { return }
                    Task {
                        await lyricsNotifications
                            .refreshAuthorizationStatus()
                    }
                }
        }
    }

    private var effectiveLyricsRefreshRate: LyricsRefreshRate {
        isLowPowerModeEnabled ? .lowPowerValue : settings.lyricsRefreshRate
    }
}
