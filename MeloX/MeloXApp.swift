import Foundation
import SwiftUI

@main
struct MeloXApp: App {
    @State private var settings: AppSettings
    @State private var api: NeteaseAPI
    @State private var library: LibraryStore
    @State private var cloud: CloudMusicStore
    @State private var player: PlayerStore
    @State private var screenAwakeCoordinator: ScreenAwakeCoordinator
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    init() {
        let settings = AppSettings()
        let api = NeteaseAPI(settings: settings)
        let library = LibraryStore(api: api, settings: settings)
        let cloud = CloudMusicStore(api: api, settings: settings)
        _settings = State(initialValue: settings)
        _api = State(initialValue: api)
        _library = State(initialValue: library)
        _cloud = State(initialValue: cloud)
        _player = State(
            initialValue: PlayerStore(
                api: api,
                settings: settings,
                onPlaybackRecorded: { song in
                    library.recordRecentlyPlayed(song)
                }
            )
        )
        _screenAwakeCoordinator = State(initialValue: ScreenAwakeCoordinator())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(api)
                .environment(library)
                .environment(cloud)
                .environment(player)
                .environment(screenAwakeCoordinator)
                .environment(\.effectiveLyricsRefreshRate, effectiveLyricsRefreshRate)
                .tint(.red)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: .NSProcessInfoPowerStateDidChange
                    )
                ) { _ in
                    isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
        }
    }

    private var effectiveLyricsRefreshRate: LyricsRefreshRate {
        isLowPowerModeEnabled ? .lowPowerValue : settings.lyricsRefreshRate
    }
}
