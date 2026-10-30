import SwiftUI

struct HomeRecommendedView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(AppSettings.self) private var settings
    @Environment(\.openMusicRoute) private var openMusicRoute

    @State private var payload: HomePagePayload?
    @State private var fallbacks: [
        HomeRecommendationSlot: HomeRecommendationFallback
    ] = [:]
    @State private var charts: [Playlist] = []
    @State private var loadedPrimaryContext:
        HomeRecommendedPrimaryContext?
    @State private var displayedPrimaryContext: HomeRecommendedPrimaryContext?
    @State private var lastSuccessfulRefresh: Date?
    @State private var hotSongsChart: Playlist?
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var payloadVersion = 0
    @State private var activeAction: HomeQuickAction?
    @State private var actionErrorMessage: String?

    private var feed: HomeRecommendationFeed {
        HomeRecommendationFeed(
            blocks: payload?.blocks ?? [],
            fallbacks: fallbacks,
            includesPodcasts:
                settings.isContentFeatureEnabled(.podcasts)
        )
    }

    var body: some View {
        content
        .task(
            id: HomeRecommendedLoadRequest(
                reloadToken: reloadToken,
                accountToken: settings.cookie.hashValue,
                musicArea: settings.musicArea
            )
        ) {
            await load()
        }
        .task(
            id: HomeRecommendedFallbackLoadRequest(
                payloadVersion: payloadVersion,
                chartIDs: charts.map(\.id),
                accountID: library.profile?.id,
                isLoggedIn: library.isLoggedIn,
                musicArea: settings.musicArea,
                podcastsEnabled:
                    settings.isContentFeatureEnabled(.podcasts),
                favoritePlaylistIDs:
                    library.favoritePlaylists.map(\.id),
                likedSongID: library.favoriteSongs.first?.id
            )
        ) {
            await loadFallbacks()
        }
        .alert(
            "ui.error.operation_failed.title",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        actionErrorMessage = nil
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                actionErrorMessage = nil
            }
        } message: {
            Text(actionErrorMessage ?? L10n.string("ui.error.try_again_later"))
        }
    }

    @ViewBuilder
    private var initialState: some View {
        switch phase {
        case .loading:
            ProgressView("ui.home.preparing_recommendations")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ConnectionUnavailableView(message: message) {
                reloadToken += 1
            }
        case .loaded:
            ContentUnavailableView(
                "ui.home.no_recommendations",
                systemImage: "music.note.house"
            )
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                HomeQuickActionsView(
                    activeAction: activeAction,
                    perform: perform
                )

                if payload == nil {
                    initialState
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 280
                        )
                        .padding(.horizontal)
                } else {
                    ForEach(feed.sections) { section in
                        HomeRecommendationSectionView(
                            section: section
                        )
                    }

                    if feed.sections.isEmpty {
                        ContentUnavailableView(
                            "ui.home.no_personalized_recommendations",
                            systemImage: "sparkles",
                            description: Text(
                                library.isLoggedIn
                                    ? L10n.string("ui.home.pull_to_refresh")
                                    : L10n.string("ui.home.login_for_personalized_content")
                            )
                        )
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 280
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .refreshable {
            await load(refresh: true)
        }
    }

    private func perform(_ action: HomeQuickAction) {
        switch action {
        case .dailySongs:
            openMusicRoute(.dailySongs)
        case .hotSongs:
            if let hotSongsChart {
                openMusicRoute(.toplist(hotSongsChart))
            } else {
                openMusicRoute(.toplists)
            }
        case .privateRadar:
            guard let playlist = feed.firstRadarPlaylist else {
                actionErrorMessage = L10n.string("ui.home.error.no_private_radar")
                return
            }
            openMusicRoute(.playlist(playlist))
        case .heartMode, .privateRoaming, .similarSongs:
            startPlaybackAction(action)
        }
    }

    private func startPlaybackAction(_ action: HomeQuickAction) {
        guard activeAction == nil else { return }
        activeAction = action
        actionErrorMessage = nil

        Task { @MainActor in
            defer { activeAction = nil }
            do {
                switch action {
                case .heartMode:
                    try await startHeartMode()
                case .privateRoaming:
                    try await startPrivateRoaming()
                case .similarSongs:
                    try await startSimilarSongs()
                case .dailySongs, .hotSongs, .privateRadar:
                    break
                }
            } catch is CancellationError {
                return
            } catch {
                actionErrorMessage = error.localizedDescription
            }
        }
    }

    private func startHeartMode() async throws {
        guard library.isLoggedIn else {
            throw HomePlaybackActionError.loginRequired
        }
        guard let playlistID = library.likedPlaylistID,
              let seedSongID =
                library.randomHeartModeSeedSongID() else {
            throw HomePlaybackActionError.noLikedSongs
        }
        try await player.playHeartMode(
            playlistID: playlistID,
            seedSongID: seedSongID
        )
    }

    private func startPrivateRoaming() async throws {
        guard library.isLoggedIn else {
            throw HomePlaybackActionError.loginRequired
        }
        let songs = try await api.personalFM(
            mode: .explore,
            limit: 30
        )
        guard !songs.isEmpty else {
            throw HomePlaybackActionError.noRecommendations
        }
        await player.playAll(songs)
    }

    private func startSimilarSongs() async throws {
        guard let currentSong = player.currentSong,
              !currentSong.isPodcastProgram else {
            throw HomePlaybackActionError.songRequired
        }
        let songs = try await api.similarSongs(
            id: currentSong.id,
            limit: 50
        )
        guard !songs.isEmpty else {
            throw HomePlaybackActionError.noRecommendations
        }
        await player.playAll(songs)
    }

    private func load(refresh: Bool = false) async {
        if payload == nil {
            phase = .loading
        }

        do {
            let primaryContext = HomeRecommendedPrimaryContext(
                accountToken: settings.cookie.hashValue,
                musicArea: settings.musicArea
            )
            if displayedPrimaryContext != primaryContext {
                payload = nil
                charts = []
                fallbacks = [:]
                hotSongsChart = nil
                loadedPrimaryContext = nil
                lastSuccessfulRefresh = nil
                if let snapshot: HomeContentSnapshot = await api.pageContentCache.value(
                    for: HomeContentSnapshot.cacheKey(musicArea: settings.musicArea)
                ) {
                    payload = snapshot.payload
                    charts = snapshot.charts
                    fallbacks = snapshot.fallbacks
                    hotSongsChart = Self.hotSongsChart(in: charts)
                    phase = .loaded
                    payloadVersion += 1
                }
                try Task.checkCancellation()
                displayedPrimaryContext = primaryContext
            }
            let newPayload: HomePagePayload
            let newCharts: [Playlist]

            if !refresh,
               loadedPrimaryContext == primaryContext,
               let lastSuccessfulRefresh,
               Date().timeIntervalSince(lastSuccessfulRefresh) < 300,
               let payload {
                newPayload = payload
                newCharts = charts
            } else {
                async let loadedHomePage = api.homePage(
                    refresh: refresh
                )
                async let loadedCharts = try? api.toplists()
                newPayload = try await loadedHomePage
                try Task.checkCancellation()
                if newPayload.blocks.isEmpty, let payload, !payload.blocks.isEmpty {
                    throw APIError.invalidResponse
                }

                payload = newPayload
                loadedPrimaryContext = primaryContext
                phase = .loaded
                payloadVersion += 1

                newCharts = await loadedCharts ?? charts
                lastSuccessfulRefresh = Date()
            }
            try Task.checkCancellation()

            payload = newPayload
            charts = newCharts
            loadedPrimaryContext = primaryContext
            hotSongsChart = Self.hotSongsChart(in: newCharts)
            phase = .loaded
            await persistContent()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            lastSuccessfulRefresh = nil
            if payload == nil {
                phase = .failed(error.localizedDescription)
            } else {
                phase = .loaded
                actionErrorMessage = error.localizedDescription
            }
        }
    }

    private func loadFallbacks() async {
        guard let payload else { return }

        do {
            // LibraryStore fills profile, playlists and liked songs in several
            // steps. Coalesce those changes without restarting the homepage
            // request that already produced visible content.
            try await Task.sleep(for: .milliseconds(250))
            try Task.checkCancellation()
        } catch {
            return
        }

        let requestedBlockIDs = payload.blocks.map(\.id)
        let serverFeed = HomeRecommendationFeed(
            blocks: payload.blocks,
            includesPodcasts:
                settings.isContentFeatureEnabled(.podcasts)
        )
        let fallbackLoader = HomeRecommendationFallbackLoader(
            api: api,
            library: library,
            serverFeed: serverFeed,
            region: HomeMusicRegion(
                settingValue: settings.musicArea
            ),
            includesPodcasts:
                settings.isContentFeatureEnabled(.podcasts)
        )
        let newFallbacks = await fallbackLoader.load(
            charts: charts
        )

        guard !Task.isCancelled,
              self.payload?.blocks.map(\.id)
                == requestedBlockIDs else {
            return
        }
        fallbacks.merge(newFallbacks) { _, updated in updated }
        await persistContent()
    }

    private func persistContent() async {
        guard let payload, !feed.sections.isEmpty,
              displayedPrimaryContext == HomeRecommendedPrimaryContext(
                accountToken: settings.cookie.hashValue,
                musicArea: settings.musicArea
              ) else { return }
        await api.pageContentCache.store(
            HomeContentSnapshot(payload: payload, charts: charts, fallbacks: fallbacks),
            for: HomeContentSnapshot.cacheKey(musicArea: settings.musicArea)
        )
    }

    private static func hotSongsChart(
        in charts: [Playlist]
    ) -> Playlist? {
        charts.first { $0.name.contains("热歌榜") }
            ?? charts.first { $0.id == 3_778_678 }
    }
}

private struct HomeRecommendedLoadRequest: Hashable {
    let reloadToken: Int
    let accountToken: Int
    let musicArea: String
}

private struct HomeRecommendedFallbackLoadRequest: Hashable {
    let payloadVersion: Int
    let chartIDs: [Int]
    let accountID: Int?
    let isLoggedIn: Bool
    let musicArea: String
    let podcastsEnabled: Bool
    let favoritePlaylistIDs: [Int]
    let likedSongID: Int?
}

private struct HomeRecommendedPrimaryContext: Equatable {
    let accountToken: Int
    let musicArea: String
}

private enum HomePlaybackActionError: LocalizedError {
    case loginRequired
    case noLikedSongs
    case songRequired
    case noRecommendations

    var errorDescription: String? {
        switch self {
        case .loginRequired:
            L10n.string("ui.home.error.login_required")
        case .noLikedSongs:
            L10n.string("ui.home.error.liked_songs_required")
        case .songRequired:
            L10n.string("ui.home.error.current_song_required")
        case .noRecommendations:
            L10n.string("ui.home.error.no_playable_recommendations")
        }
    }
}
