import Foundation
import Observation

@MainActor
@Observable
final class DesktopAppModel {
    let settings: AppSettings
    let api: NeteaseAPI
    let library: LibraryStore
    let cloud: CloudMusicStore
    let downloads: DownloadStore
    let player: PlayerStore
    let playbackVolume: DesktopPlaybackVolumeController
    let listenTogether: ListenTogetherStore
    let lyrics: LyricsStore
    let lyricsNotifications: LyricsNotificationController
    let screenAwakeCoordinator: ScreenAwakeCoordinator
    let home: DesktopHomeStore
    let ui = DesktopUIState()

    private(set) var hasBootstrapped = false
    private(set) var launchErrorMessage: String?

    init() {
        let settings = AppSettings()
        Self.normalizeDesktopSettings(settings)
        let api = NeteaseAPI(settings: settings)
        let library = LibraryStore(api: api, settings: settings)
        let cloud = CloudMusicStore(api: api, settings: settings)
        let downloads = DownloadStore(api: api, settings: settings)
        let notifications = LyricsNotificationController(
            preferences: settings.lyricsNotifications
        )
        let player = PlayerStore(
            api: api,
            settings: settings,
            downloads: downloads,
            lyricsNotificationController: notifications,
            onPlaybackRecorded: { song in
                library.recordRecentlyPlayed(song)
            }
        )

        self.settings = settings
        self.api = api
        self.library = library
        self.cloud = cloud
        self.downloads = downloads
        self.lyricsNotifications = notifications
        self.player = player
        playbackVolume = DesktopPlaybackVolumeController(
            settings: settings,
            player: player
        )
        listenTogether = ListenTogetherStore(api: api, player: player)
        let lyricService = LyricsService(api: api, settings: settings)
        lyrics = LyricsStore(service: lyricService)
        screenAwakeCoordinator = ScreenAwakeCoordinator()
        home = DesktopHomeStore(api: api, settings: settings)

        if !settings.hasCompletedOnboarding {
            ui.sheet = .onboarding
        }
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        await player.restore()
        async let homeLoad: Void = home.load()
        async let notificationLoad: Void = lyricsNotifications
            .refreshAuthorizationStatus()
        if library.isLoggedIn {
            async let libraryLoad: Void = library.refresh()
            async let cloudLoad: Void = refreshCloudIfEnabled()
            async let roomLoad: Void = listenTogether
                .accountDidChange(hasCredentials: true)
            _ = await (libraryLoad, cloudLoad, roomLoad)
            await startHeartModeOnLaunchIfNeeded()
        }
        _ = await (homeLoad, notificationLoad)
        await synchronizeLyrics()
        // Apply this after launch-time clipboard/update tasks so the debug
        // harness always ends on the real dynamic playback page.
        await activateDebugPlaybackPageIfRequested()
    }

    /// Test-only entry point for repeatable real-player performance runs.
    /// It uses the restored song and queue so old and new builds can be
    /// launched into the same dynamic lyrics page without manual clicks.
    private func activateDebugPlaybackPageIfRequested() async {
        let environment = ProcessInfo.processInfo.environment
        guard environment["MELOX_DEBUG_FIXED_PLAYBACK_PAGE"] == "1"
            || CommandLine.arguments.contains(
                "--melox-debug-fixed-playback-page"
            ) else { return }
        guard player.currentSong != nil else {
            print("[MeloX debug] fixed playback page requested without a restored song")
            return
        }

        ui.isNowPlayingPresented = true
        if !player.isPlaying {
            player.togglePlayback()
        }
        print(
            "[MeloX debug] fixed playback page active for song \(player.currentSong?.id ?? 0)"
        )
    }

    func synchronizeLyrics() async {
        let song = player.currentSong
        let lyricSong = song?.isPodcastProgram == true ? nil : song
        await lyrics.load(for: lyricSong)
        player.setNowPlayingLyrics(lyrics.lyrics, for: lyricSong?.id)
    }

    func refreshAll() async {
        async let homeLoad: Void = home.load(force: true)
        async let libraryLoad: Void = library.refresh(force: true)
        async let cloudLoad: Void = refreshCloudIfEnabled(force: true)
        _ = await (homeLoad, libraryLoad, cloudLoad)
    }

    func accountCookieDidChange() async {
        async let homeLoad: Void = home.load(force: true)
        await library.refresh(force: true)
        await refreshCloudIfEnabled(force: true)
        await listenTogether.accountDidChange(
            hasCredentials: library.isLoggedIn
        )
        _ = await homeLoad
    }

    func logOut() {
        settings.clearAccount()
        library.clearAccountData()
        Task {
            async let homeLoad: Void = home.load(force: true)
            async let roomUpdate: Void = listenTogether.accountDidChange(
                hasCredentials: false
            )
            _ = await (homeLoad, roomUpdate)
        }
    }

    func clearLaunchError() {
        launchErrorMessage = nil
    }

    func isSectionEnabled(_ section: DesktopSection) -> Bool {
        guard let feature = section.requiredContentFeature else {
            return true
        }
        return settings.isContentFeatureEnabled(feature)
    }

    func ensureSelectedSectionIsEnabled() {
        guard !isSectionEnabled(ui.selection) else { return }
        ui.selection = .home
    }

    private func refreshCloudIfEnabled(
        force: Bool = false
    ) async {
        guard settings.isContentFeatureEnabled(.cloudMusic) else {
            return
        }
        await cloud.refresh(force: force)
    }

    private func startHeartModeOnLaunchIfNeeded() async {
        guard settings.startsHeartModeOnLaunch,
              library.canStartHeartMode,
              let playlistID = library.likedPlaylistID,
              let seedSongID = library.randomHeartModeSeedSongID() else {
            return
        }

        do {
            try await player.playHeartMode(
                playlistID: playlistID,
                seedSongID: seedSongID
            )
        } catch is CancellationError {
            return
        } catch {
            launchErrorMessage = error.localizedDescription
        }
    }

    private static func normalizeDesktopSettings(_ settings: AppSettings) {
        // The desktop target currently ships the Apple Music lyric renderer.
        // Do not retain mobile-only renderer selections that the Mac cannot show.
        if settings.lyricsStyle != .appleMusic {
            settings.lyricsStyle = .appleMusic
        }

        // Desktop lyrics have no independently hidden full-screen interface.
        if settings.playerScreenAwakeMode == .hiddenLyricsInterface {
            settings.playerScreenAwakeMode = .lyrics
        }
    }
}
