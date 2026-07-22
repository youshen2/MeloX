import SwiftUI

struct ContentView: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    @State private var selectedTab: AppTab = .home
    @State private var homePath = NavigationPath()
    @State private var explorePath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var settingsPath = NavigationPath()
    @State private var playerPresentation: PlayerPresentation?
    @State private var pendingMusicRoute: MusicRoute?
    @Namespace private var playerTransitionNamespace

    private let playerTransitionID = "now-playing"

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                mainExperience
            } else {
                OnboardingView()
            }
        }
    }

    private var mainExperience: some View {
        playerAwareTabView
            .environment(
                \.openMusicRoute,
                OpenMusicRouteAction(action: openMusicRoute)
            )
            .fullScreenCover(
                item: $playerPresentation,
                onDismiss: finishPendingSongNavigation
            ) { destination in
                switch destination {
                case .nowPlaying:
                    NowPlayingView(initialPage: initialNowPlayingPage)
                        .environment(
                            \.openMusicRoute,
                            OpenMusicRouteAction(action: openMusicRoute)
                        )
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
            .task(id: settings.cookie) {
                await library.refresh()
            }
            .appLaunchExperience()
    }

    @ViewBuilder
    private var playerAwareTabView: some View {
        if player.currentSong != nil {
            tabs
                .tabViewBottomAccessory {
                    MiniPlayerView {
                        playerPresentation = .nowPlaying
                    }
                    .matchedTransitionSource(
                        id: playerTransitionID,
                        in: playerTransitionNamespace
                    )
                }
        } else {
            tabs
        }
    }

    private var tabs: some View {
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
                        .musicDestinations()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var initialNowPlayingPage: NowPlayingPage {
        guard settings.rememberNowPlayingPage else { return .artwork }
        return NowPlayingPage(rawValue: settings.rememberedNowPlayingPage) ?? .artwork
    }

    private func openMusicRoute(_ route: MusicRoute) {
        guard playerPresentation == nil else {
            pendingMusicRoute = route
            playerPresentation = nil
            return
        }
        navigate(to: route)
    }

    private func finishPendingSongNavigation() {
        guard let route = pendingMusicRoute else { return }
        pendingMusicRoute = nil
        navigate(to: route)
    }

    private func navigate(to route: MusicRoute) {
        switch selectedTab {
        case .home:
            homePath.append(route)
        case .explore:
            explorePath.append(route)
        case .library:
            libraryPath.append(route)
        case .search:
            searchPath.append(route)
        case .settings:
            settingsPath.append(route)
        }
    }
}
