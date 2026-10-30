import SwiftUI

struct PlaylistDetailView: View {
    let id: Int
    private let initialPlaylist: Playlist
    private let prefersToplistLayout: Bool

    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerStore.self) private var player
    @Environment(DownloadStore.self) private var downloads
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.setTabViewBottomAccessorySuppressed)
    private var setTabViewBottomAccessorySuppressed

    @State private var playlist: Playlist?
    @State private var contentAccountToken: Int?
    @State private var pendingRemoval: Song?
    @State private var isRemovingTrack = false
    @State private var removalError: String?

    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var artworkPalette: ArtworkDetailPalette?
    @State private var blurredBackdropImage: CGImage?
    @State private var searchQuery = ""
    @State private var loadedTrackOffset = 0
    @State private var isLoadingMoreTracks = false
    @State private var loadMoreTracksError: String?
    @State private var isPreparingPlayback = false
    @State private var playbackErrorMessage: String?
    @State private var trackLocator = MusicCollectionTrackLocator()
    @State private var songToLocate: Int?
    @State private var locateErrorMessage: String?
    @State private var downloadCoordinator =
        MusicCollectionDownloadCoordinator()

    private let trackPageSize = 100

    init(playlist context: PlaylistRouteContext) {
        let cachedAssets = ArtworkAccentColorProvider.cachedDetailAssets(
            for: context.coverURLString.flatMap(URL.init(string:))
        )
        id = context.id
        initialPlaylist = context.playlistSummary
        prefersToplistLayout = false
        _artworkPalette = State(initialValue: cachedAssets?.palette)
        _blurredBackdropImage = State(
            initialValue: cachedAssets?.blurredBackdropImage
        )
    }

    init(toplist context: PlaylistRouteContext) {
        let cachedAssets = ArtworkAccentColorProvider.cachedDetailAssets(
            for: context.coverURLString.flatMap(URL.init(string:))
        )
        id = context.id
        initialPlaylist = context.playlistSummary
        prefersToplistLayout = true
        _artworkPalette = State(initialValue: cachedAssets?.palette)
        _blurredBackdropImage = State(
            initialValue: cachedAssets?.blurredBackdropImage
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            PlaylistDetailContent(
                playlist: displayedPlaylist,
                toplistSummary: prefersToplistLayout ? initialPlaylist : nil,
                palette: resolvedPalette,
                blurredBackdropImage: blurredBackdropImage,
                searchQuery: searchQuery,
                isLoading: isInitialLoading,
                failureMessage: initialFailureMessage,
                hasMoreTracks: hasMoreTracks && songToLocate == nil,
                loadedTrackOffset: loadedTrackOffset,
                isLoadingMoreTracks: isLoadingMoreTracks,
                loadMoreTracksError: loadMoreTracksError,
                isPreparingPlayback: isPreparingPlayback,
                downloadCoordinator:
                    downloadsEnabled
                        ? downloadCoordinator
                        : nil,
                onRetry: { reloadToken += 1 },
                onRefresh: { await load() },
                onLoadMore: { await loadMoreTracks() },
                onPlayAll: { shuffled in
                    await playAll(shuffled: shuffled)
                },
                onRemoveSong: library.canDelete(displayedPlaylist)
                    && !isLoadingMoreTracks && songToLocate == nil
                    ? { pendingRemoval = $0 }
                    : nil,
                highlightedSongID: trackLocator.highlightedSongID
            )
            .task(id: songToLocate) {
                if let songToLocate { await locateSong(songToLocate) }
            }
            .task(id: trackLocator.request) {
                await trackLocator.scroll(using: proxy, reduceMotion: accessibilityReduceMotion)
            }
        }
        .disabled(isRemovingTrack)
        .alert("ui.collection.locate_failed", isPresented: Binding(
            get: { locateErrorMessage != nil },
            set: { if !$0 { locateErrorMessage = nil } }
        )) {
            Button("ui.common.ok", role: .cancel) { locateErrorMessage = nil }
        } message: {
            Text(locateErrorMessage ?? "")
        }
        .confirmationDialog(
            "ui.playlists.remove_song",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { song in
            Button("ui.playlists.remove_song", role: .destructive) {
                Task { await removeSong(song) }
            }
            Button("ui.common.cancel", role: .cancel) {}
        } message: { song in
            Text(L10n.format("ui.playlists.remove_song.message", song.name))
        }
        .alert("ui.library.error.title", isPresented: Binding(
            get: { removalError != nil },
            set: { if !$0 { removalError = nil } }
        )) {
            Button("ui.common.ok", role: .cancel) { removalError = nil }
        } message: {
            Text(removalError ?? "")
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(
                prefersToplistLayout
                    ? L10n.string("ui.toplists.search_prompt")
                    : L10n.string("ui.playlists.search_prompt")
            )
        )
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(interfaceColorScheme, for: .navigationBar, .tabBar)
        .toolbar {
            if downloadsEnabled,
               downloadCoordinator.isSelecting {
                downloadSelectionToolbar
            } else {
                playlistToolbar(for: displayedPlaylist)
            }
        }
        .toolbarVisibility(
            downloadsEnabled
                && downloadCoordinator.isSelecting
                ? .hidden
                : .automatic,
            for: .tabBar
        )
        .environment(\.colorScheme, interfaceColorScheme)
        .onAppear {
            updateTabViewBottomAccessoryVisibility()
        }
        .onChange(of: downloadCoordinator.isSelecting) {
            updateTabViewBottomAccessoryVisibility()
        }
        .onChange(of: downloadsEnabled) { _, isEnabled in
            if !isEnabled {
                downloadCoordinator.finishSelection()
            }
            updateTabViewBottomAccessoryVisibility()
        }
        .onDisappear {
            setTabViewBottomAccessorySuppressed(false)
        }
        .onChange(of: downloadableSongIDs) { _, songIDs in
            guard downloadCoordinator.isSelecting else { return }
            downloadCoordinator.retainSelection(in: Set(songIDs))
        }
        .task(id: reloadToken) {
            guard playlist == nil else { return }
            await load(waitingForNavigationTransition: true)
        }
        .task(id: artworkURL) {
            let transitionDelay = navigationTransitionDelay()
            defer { transitionDelay.cancel() }

            let loadedAssets = await ArtworkAccentColorProvider.shared.detailAssets(
                for: artworkURL,
                fallbackPrefersDarkAppearance: systemColorScheme == .dark
            )
            guard !Task.isCancelled else { return }
            let backdropAlreadyResolved = blurredBackdropImage != nil
                || loadedAssets.blurredBackdropImage == nil
            if artworkPalette == loadedAssets.palette,
               backdropAlreadyResolved {
                return
            }
            do {
                try await transitionDelay.value
            } catch {
                return
            }
            withAnimation(artworkTransitionAnimation) {
                artworkPalette = loadedAssets.palette
                blurredBackdropImage = loadedAssets.blurredBackdropImage
            }
        }
        .alert(
            "ui.library.error.title",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        library.clearError()
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? L10n.string("ui.common.unknown_error"))
        }
        .alert(
            "ui.downloads.prepare_failed",
            isPresented: Binding(
                get: {
                    downloadsEnabled
                        && downloadCoordinator.errorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        downloadCoordinator.clearError()
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                downloadCoordinator.clearError()
            }
        } message: {
            Text(
                downloadCoordinator.errorMessage
                    ?? L10n.format("ui.music_collection.load_songs_failed", collectionTitle)
            )
        }
        .alert(
            "ui.library.play_all_failed",
            isPresented: Binding(
                get: { playbackErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        playbackErrorMessage = nil
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                playbackErrorMessage = nil
            }
        } message: {
            Text(playbackErrorMessage ?? L10n.string("ui.playlists.load_complete_failed"))
        }
    }

    private var displayedPlaylist: Playlist {
        playlist ?? initialPlaylist
    }

    private var downloadsEnabled: Bool {
        settings.isContentFeatureEnabled(.downloads)
    }

    private var artworkURL: URL? {
        displayedPlaylist.artworkURL ?? initialPlaylist.artworkURL
    }

    private var collectionTitle: String {
        prefersToplistLayout
            ? L10n.string("ui.toplists.title")
            : L10n.string("ui.common.playlist")
    }

    private var resolvedPalette: ArtworkDetailPalette {
        artworkPalette
            ?? .fallback(prefersDarkAppearance: systemColorScheme == .dark)
    }

    private var interfaceColorScheme: ColorScheme {
        resolvedPalette.colorScheme
    }

    private var artworkTransitionAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var isInitialLoading: Bool {
        guard playlist == nil else { return false }
        if case .loading = phase {
            return true
        }
        return false
    }

    private var initialFailureMessage: String? {
        guard playlist == nil, case .failed(let message) = phase else { return nil }
        return message
    }

    private var hasMoreTracks: Bool {
        guard case .loaded = phase,
              let playlist,
              !playlist.trackIDs.isEmpty else {
            return false
        }
        return loadedTrackOffset < playlist.trackIDs.count
    }

    private var downloadableSongIDs: [Int] {
        guard downloadsEnabled,
              let playlist else { return [] }
        let unavailableSongIDs = Set(downloads.downloads.map(\.id))
            .union(downloads.activeDownloads.keys)
        return MusicCollectionDownloadCoordinator.songIDs(
            in: playlist
        )
        .filter { !unavailableSongIDs.contains($0) }
    }

    private func updateTabViewBottomAccessoryVisibility() {
        setTabViewBottomAccessorySuppressed(
            downloadsEnabled
                && downloadCoordinator.isSelecting
        )
    }

    @ToolbarContentBuilder
    private func playlistToolbar(for playlist: Playlist) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if songToLocate != nil {
                ProgressView()
                    .accessibilityLabel("ui.collection.locating_playing")
            }
            if downloadsEnabled,
               downloadCoordinator.isPreparing {
                ProgressView()
                    .accessibilityLabel(
                        L10n.format(
                            "ui.downloads.preparing_song_count",
                            downloadCoordinator.preparingSongCount
                        )
                    )
            }

            Menu {
                NeteaseShareMenuContent(resource: .playlist(playlist))
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel(L10n.format("ui.common.share_named", collectionTitle))

            Menu {
                Button("ui.collection.locate_playing", systemImage: "scope") {
                    songToLocate = currentSongID
                }
                .disabled(currentSongID == nil || songToLocate != nil || isLoadingMoreTracks)
                Divider()

                if downloadsEnabled {
                    MusicCollectionDownloadMenuContent(
                        coordinator: downloadCoordinator,
                        downloadableSongCount:
                            downloadableSongIDs.count,
                        onDownloadAll: { quality in
                            startDownloadAll(quality: quality)
                        }
                    )

                    Divider()
                }

                Button {
                    library.toggle(playlist: playlist)
                } label: {
                    Label(
                        library.contains(playlist: playlist)
                            ? L10n.string("ui.common.unfavorite")
                            : L10n.string("ui.playlists.favorite"),
                        systemImage: library.contains(playlist: playlist) ? "checkmark" : "plus"
                    )
                }

                Button {
                    Task { await load() }
                } label: {
                    Label("ui.common.refresh", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("ui.common.more")
        }
        .sharedBackgroundVisibility(.visible)
    }

    @ToolbarContentBuilder
    private var downloadSelectionToolbar: some ToolbarContent {
        MusicCollectionDownloadSelectionToolbar(
            coordinator: downloadCoordinator,
            downloadableSongIDs: downloadableSongIDs,
            onDownloadSelection: { quality in
                startSelectedDownloads(quality: quality)
            }
        )
    }

    private func startDownloadAll(quality: MusicQuality) {
        guard downloadsEnabled,
              let playlist else { return }
        Task {
            await downloadCoordinator.downloadAll(
                in: playlist,
                quality: quality,
                api: api,
                downloads: downloads
            )
        }
    }

    private func startSelectedDownloads(quality: MusicQuality) {
        guard downloadsEnabled,
              let playlist else { return }
        Task {
            await downloadCoordinator.downloadSelection(
                in: playlist,
                quality: quality,
                api: api,
                downloads: downloads
            )
        }
    }

    private var currentSongID: Int? {
        guard case .loaded = phase,
              let song = player.currentSong, let playlist,
              playlist.tracks.contains(where: { $0.id == song.id })
                || playlist.trackIDs.contains(where: { $0.id == song.id }),
              !filterMusicCollectionTracks([song], query: searchQuery).isEmpty else { return nil }
        return song.id
    }

    private func locateSong(_ songID: Int) async {
        defer { songToLocate = nil }
        locateErrorMessage = nil
        guard var playlist else { return }

        do {
            if !playlist.tracks.contains(where: { $0.id == songID }),
               let index = playlist.trackIDs.firstIndex(where: { $0.id == songID }) {
                let endOffset = max(
                    loadedTrackOffset,
                    min((index / trackPageSize + 1) * trackPageSize, playlist.trackIDs.count)
                )
                playlist.tracks = try await api.songDetailsCollection(
                    ids: playlist.trackIDs.prefix(endOffset).map(\.id),
                    prefetched: playlist.tracks
                )
                try Task.checkCancellation()
                self.playlist = playlist
                loadedTrackOffset = endOffset
                loadMoreTracksError = nil
                await persistContent()
            }
            guard playlist.tracks.contains(where: { $0.id == songID }) else {
                locateErrorMessage = L10n.string("ui.collection.locate_unavailable")
                return
            }
            guard filterMusicCollectionTracks(playlist.tracks, query: searchQuery)
                .contains(where: { $0.id == songID }) else { return }
            trackLocator.locate(songID)
        } catch is CancellationError {
            return
        } catch {
            locateErrorMessage = error.localizedDescription
        }
    }

    private func load(
        waitingForNavigationTransition: Bool = false
    ) async {
        let accountToken = settings.cookie.hashValue
        songToLocate = nil
        trackLocator.reset()
        locateErrorMessage = nil
        let transitionDelay = navigationTransitionDelay(
            isEnabled: waitingForNavigationTransition
        )
        defer { transitionDelay.cancel() }

        if playlist == nil,
           let snapshot: PlaylistContentSnapshot = await api.pageContentCache.value(
               for: PlaylistContentSnapshot.cacheKey(id: id)
           ) {
            playlist = snapshot.playlist
            contentAccountToken = accountToken
            loadedTrackOffset = snapshot.loadedTrackOffset
            phase = .loaded
        }
        if playlist == nil {
            phase = .loading
        }
        loadMoreTracksError = nil
        do {
            let requestedTrackLimit = max(trackPageSize, loadedTrackOffset)
            let loadedPlaylist = try await api.playlist(
                id: id,
                trackLimit: requestedTrackLimit
            )
            guard loadedPlaylist.trackCount == 0 || !loadedPlaylist.tracks.isEmpty else {
                throw APIError.invalidResponse
            }
            try await transitionDelay.value
            guard accountToken == settings.cookie.hashValue else { return }
            playlist = loadedPlaylist
            contentAccountToken = accountToken
            loadedTrackOffset = min(
                requestedTrackLimit,
                loadedPlaylist.trackIDs.count
            )
            phase = .loaded
            await persistContent()
        } catch is CancellationError {
            return
        } catch {
            if playlist == nil {
                phase = .failed(error.localizedDescription)
            } else {
                phase = .loaded
                loadMoreTracksError = error.localizedDescription
            }
        }
    }

    private func removeSong(_ song: Song) async {
        guard let playlist, !isLoadingMoreTracks, songToLocate == nil else { return }
        isRemovingTrack = true
        defer { isRemovingTrack = false }
        do {
            try await library.remove(song: song, from: playlist)
            guard var updated = self.playlist else { return }
            if let index = updated.removeSong(id: song.id), index < loadedTrackOffset {
                loadedTrackOffset -= 1
            }
            self.playlist = updated
            await persistContent()
        } catch {
            removalError = error.localizedDescription
        }
    }

    private func loadMoreTracks() async {
        guard let currentPlaylist = playlist,
              !isLoadingMoreTracks,
              !isRemovingTrack,
              songToLocate == nil,
              loadedTrackOffset < currentPlaylist.trackIDs.count else {
            return
        }

        let requestedOffset = loadedTrackOffset
        let trackIDs = currentPlaylist.trackIDs.map(\.id)
        isLoadingMoreTracks = true
        loadMoreTracksError = nil
        defer {
            isLoadingMoreTracks = false
        }

        do {
            let page = try await api.songDetailsPage(
                ids: trackIDs,
                offset: requestedOffset,
                limit: trackPageSize
            )
            try Task.checkCancellation()
            guard playlist?.id == currentPlaylist.id,
                  loadedTrackOffset == requestedOffset else {
                return
            }

            var updatedPlaylist = playlist ?? currentPlaylist
            var loadedIDs = Set(updatedPlaylist.tracks.map(\.id))
            updatedPlaylist.tracks.append(
                contentsOf: page.songs.filter {
                    loadedIDs.insert($0.id).inserted
                }
            )
            playlist = updatedPlaylist
            loadedTrackOffset = page.nextOffset
            await persistContent()
        } catch is CancellationError {
            return
        } catch {
            loadMoreTracksError = error.localizedDescription
        }
    }

    private func persistContent() async {
        guard let playlist, contentAccountToken == settings.cookie.hashValue else { return }
        await api.pageContentCache.store(
            PlaylistContentSnapshot(playlist: playlist, loadedTrackOffset: loadedTrackOffset),
            for: PlaylistContentSnapshot.cacheKey(id: id)
        )
    }

    private func playAll(shuffled: Bool) async {
        guard let currentPlaylist = playlist,
              !isPreparingPlayback else {
            return
        }

        isPreparingPlayback = true
        playbackErrorMessage = nil
        defer { isPreparingPlayback = false }

        do {
            let trackIDs = currentPlaylist.trackIDs.map(\.id)
            let songs = if trackIDs.isEmpty {
                currentPlaylist.tracks
            } else {
                try await api.songDetailsCollection(
                    ids: trackIDs,
                    prefetched: currentPlaylist.tracks
                )
            }
            try Task.checkCancellation()
            guard playlist?.id == currentPlaylist.id else { return }
            await player.playAll(
                shuffled ? songs.shuffled() : songs,
                sourceID: currentPlaylist.id
            )
        } catch is CancellationError {
            return
        } catch {
            playbackErrorMessage = error.localizedDescription
        }
    }

    private func navigationTransitionDelay(
        isEnabled: Bool = true
    ) -> Task<Void, Error> {
        Task {
            guard isEnabled else { return }
            try await Task.sleep(
                for: MusicNavigationTransitionTiming.settleDelay
            )
        }
    }
}
