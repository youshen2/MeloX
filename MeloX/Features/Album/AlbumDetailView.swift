import SwiftUI

struct AlbumDetailView: View {
    let id: Int
    private let initialAlbum: Album

    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library
    @Environment(DownloadStore.self) private var downloads
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.setTabViewBottomAccessorySuppressed)
    private var setTabViewBottomAccessorySuppressed

    @State private var album: Album?
    @State private var songs: [Song] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var isSubscribed = false
    @State private var isUpdatingSubscription = false
    @State private var operationError: String?
    @State private var artworkPalette: ArtworkDetailPalette?
    @State private var blurredBackdropImage: CGImage?
    @State private var searchQuery = ""
    @State private var downloadCoordinator =
        MusicCollectionDownloadCoordinator()

    init(context: AlbumRouteContext) {
        let cachedAssets = ArtworkAccentColorProvider.cachedDetailAssets(
            for: context.picURL.flatMap(URL.init(string:))
        )
        id = context.id
        initialAlbum = context.albumSummary
        _artworkPalette = State(initialValue: cachedAssets?.palette)
        _blurredBackdropImage = State(
            initialValue: cachedAssets?.blurredBackdropImage
        )
    }

    var body: some View {
        AlbumDetailContent(
            album: displayedAlbum,
            songs: songs,
            palette: resolvedPalette,
            blurredBackdropImage: blurredBackdropImage,
            searchQuery: searchQuery,
            isLoading: isInitialLoading,
            failureMessage: initialFailureMessage,
            isSubscribed: isSubscribed,
            downloadCoordinator:
                downloadsEnabled
                    ? downloadCoordinator
                    : nil,
            onToggleSubscription: toggleSubscription,
            onRetry: { reloadToken += 1 },
            onRefresh: { await load() }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("ui.album.search_prompt")
        )
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(interfaceColorScheme, for: .navigationBar, .tabBar)
        .toolbar {
            if downloadsEnabled,
               downloadCoordinator.isSelecting {
                downloadSelectionToolbar
            } else {
                albumToolbar
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
            guard album == nil else { return }
            await load(waitingForNavigationTransition: true)
        }
        .task(id: displayedAlbum.artworkURL) {
            let transitionDelay = navigationTransitionDelay()
            defer { transitionDelay.cancel() }

            let loadedAssets = await ArtworkAccentColorProvider.shared.detailAssets(
                for: displayedAlbum.artworkURL,
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
            "ui.album.operation_failed",
            isPresented: Binding(
                get: { operationError != nil },
                set: { isPresented in
                    if !isPresented {
                        operationError = nil
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                operationError = nil
            }
        } message: {
            Text(operationError ?? L10n.string("ui.common.unknown_error"))
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
                    ?? L10n.string("ui.album.load_songs_failed")
            )
        }
    }

    private var displayedAlbum: Album {
        album ?? initialAlbum
    }

    private var downloadsEnabled: Bool {
        settings.isContentFeatureEnabled(.downloads)
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
        guard album == nil else { return false }
        if case .loading = phase {
            return true
        }
        return false
    }

    private var initialFailureMessage: String? {
        guard album == nil, case .failed(let message) = phase else { return nil }
        return message
    }

    private var downloadableSongIDs: [Int] {
        guard downloadsEnabled else { return [] }
        let unavailableSongIDs = Set(downloads.downloads.map(\.id))
            .union(downloads.activeDownloads.keys)
        return MusicCollectionDownloadCoordinator.songIDs(in: songs)
            .filter { !unavailableSongIDs.contains($0) }
    }

    private func updateTabViewBottomAccessoryVisibility() {
        setTabViewBottomAccessorySuppressed(
            downloadsEnabled
                && downloadCoordinator.isSelecting
        )
    }

    @ToolbarContentBuilder
    private var albumToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
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
                NeteaseShareMenuContent(resource: .album(displayedAlbum))
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("ui.album.share")

            Menu {
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

                if let artist = displayedAlbum.artists.first {
                    NavigationLink(value: MusicRoute.artist(artist.id)) {
                        Label("ui.artist.view", systemImage: "person")
                    }
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
        guard downloadsEnabled else { return }
        let songs = songs
        Task {
            await downloadCoordinator.downloadAll(
                in: songs,
                quality: quality,
                api: api,
                downloads: downloads
            )
        }
    }

    private func startSelectedDownloads(quality: MusicQuality) {
        guard downloadsEnabled else { return }
        let songs = songs
        Task {
            await downloadCoordinator.downloadSelection(
                in: songs,
                quality: quality,
                api: api,
                downloads: downloads
            )
        }
    }

    private func toggleSubscription() {
        guard !isUpdatingSubscription else { return }
        guard library.isLoggedIn else {
            operationError = APIError.notLoggedIn.localizedDescription
            return
        }

        let targetState = !isSubscribed
        isSubscribed = targetState
        isUpdatingSubscription = true
        Task {
            defer { isUpdatingSubscription = false }
            do {
                try await library.setAlbumSubscribed(
                    displayedAlbum,
                    isSubscribed: targetState
                )
            } catch {
                isSubscribed.toggle()
                operationError = error.localizedDescription
            }
        }
    }

    private func load(
        waitingForNavigationTransition: Bool = false
    ) async {
        let transitionDelay = navigationTransitionDelay(
            isEnabled: waitingForNavigationTransition
        )
        defer { transitionDelay.cancel() }

        phase = .loading
        do {
            let (loadedAlbum, loadedSongs) = try await api.album(id: id)
            try await transitionDelay.value
            album = loadedAlbum
            songs = loadedSongs
            phase = .loaded

            isSubscribed = library.contains(album: loadedAlbum)
            if library.isLoggedIn,
               let loadedSubscription = try? await api.albumSubscriptionStatus(id: id) {
                isSubscribed = loadedSubscription
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
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
