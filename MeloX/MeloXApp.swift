import SwiftUI

@main
struct MeloXApp: App {
    @State private var settings: AppSettings
    @State private var api: NeteaseAPI
    @State private var library: LibraryStore
    @State private var player: PlayerStore

    init() {
        let settings = AppSettings()
        let api = NeteaseAPI(settings: settings)
        let library = LibraryStore(api: api, settings: settings)
        _settings = State(initialValue: settings)
        _api = State(initialValue: api)
        _library = State(initialValue: library)
        _player = State(initialValue: PlayerStore(api: api, settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(api)
                .environment(library)
                .environment(player)
                .tint(.red)
        }
    }
}
