import SwiftUI

struct PlaylistDetailView: View {
    let id: Int
    private let initialPlaylist: Playlist
    private let prefersToplistLayout: Bool

    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var playlist: Playlist?
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var artworkPalette: ArtworkDetailPalette?
    @State private var blurredBackdropImage: CGImage?
    @State private var searchQuery = ""

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
        PlaylistDetailContent(
            playlist: displayedPlaylist,
            toplistSummary: prefersToplistLayout ? initialPlaylist : nil,
            palette: resolvedPalette,
            blurredBackdropImage: blurredBackdropImage,
            searchQuery: searchQuery,
            isLoading: isInitialLoading,
            failureMessage: initialFailureMessage,
            onRetry: { reloadToken += 1 },
            onRefresh: { await load() }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(prefersToplistLayout ? "在排行榜中搜索" : "在歌单中搜索")
        )
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(interfaceColorScheme, for: .navigationBar, .tabBar)
        .toolbar {
            playlistToolbar(for: displayedPlaylist)
        }
        .environment(\.colorScheme, interfaceColorScheme)
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
            "音乐库操作失败",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        library.clearError()
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? "未知错误")
        }
    }

    private var displayedPlaylist: Playlist {
        playlist ?? initialPlaylist
    }

    private var artworkURL: URL? {
        displayedPlaylist.artworkURL ?? initialPlaylist.artworkURL
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

    @ToolbarContentBuilder
    private func playlistToolbar(for playlist: Playlist) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            ShareLink(item: "https://music.163.com/playlist?id=\(playlist.id)") {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享歌单")

            Menu {
                Button {
                    library.toggle(playlist: playlist)
                } label: {
                    Label(
                        library.contains(playlist: playlist) ? "取消收藏" : "收藏歌单",
                        systemImage: library.contains(playlist: playlist) ? "checkmark" : "plus"
                    )
                }

                Button {
                    Task { await load() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("更多")
        }
        .sharedBackgroundVisibility(.visible)
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
            let loadedPlaylist = try await api.playlist(id: id)
            try await transitionDelay.value
            playlist = loadedPlaylist
            phase = .loaded
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
