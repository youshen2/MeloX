import SwiftUI

struct ContentView: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @State private var selectedTab: AppTab = .home
    @State private var homePath = NavigationPath()
    @State private var explorePath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var settingsPath = NavigationPath()
    @State private var playerPresentation: PlayerPresentation?
    @Namespace private var playerTransitionNamespace

    private let playerTransitionID = "now-playing"

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("首页", systemImage: "house", value: AppTab.home) {
                NavigationStack(path: $homePath) {
                    HomeView()
                        .musicDestinations()
                }
            }

            Tab("发现", systemImage: "safari", value: AppTab.explore) {
                NavigationStack(path: $explorePath) {
                    ExploreView()
                        .musicDestinations()
                }
            }

            Tab("音乐库", systemImage: "music.note.list", value: AppTab.library) {
                NavigationStack(path: $libraryPath) {
                    LibraryView()
                        .musicDestinations()
                }
            }

            Tab(
                "搜索",
                systemImage: "magnifyingglass",
                value: AppTab.search,
                role: .search
            ) {
                NavigationStack(path: $searchPath) {
                    SearchView()
                        .musicDestinations()
                }
            }

            Tab("设置", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack(path: $settingsPath) {
                    SettingsView()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if player.currentSong != nil {
                MiniPlayerView {
                    playerPresentation = .nowPlaying
                }
                .matchedTransitionSource(
                    id: playerTransitionID,
                    in: playerTransitionNamespace
                )
            }
        }
        .fullScreenCover(item: $playerPresentation) { destination in
            switch destination {
            case .nowPlaying:
                NowPlayingView(initialPage: initialNowPlayingPage)
                    .presentationBackground(.clear)
                    .navigationTransition(
                        .zoom(
                            sourceID: playerTransitionID,
                            in: playerTransitionNamespace
                        )
                    )
            }
        }
        .task {
            await player.restore()
        }
    }

    private var initialNowPlayingPage: NowPlayingPage {
        guard settings.rememberNowPlayingPage else { return .artwork }
        return NowPlayingPage(rawValue: settings.rememberedNowPlayingPage) ?? .artwork
    }
}
