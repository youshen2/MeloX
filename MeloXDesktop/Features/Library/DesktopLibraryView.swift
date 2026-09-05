import SwiftUI
import UniformTypeIdentifiers

struct DesktopLibraryView: View {
    @Environment(DesktopAppModel.self) private var model
    let section: DesktopSection

    @State private var showsImporter = false
    @State private var isPreparingPlayback = false
    @State private var playbackErrorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 145, maximum: 205), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    Text(section.title)
                        .font(.system(size: 32, weight: .bold))
                    Spacer()
                    headerActions
                }

                content
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
        }
        .navigationTitle(section.title)
        .task {
            await model.library.refresh()
            if section == .cloud {
                await model.cloud.refresh()
            }
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result,
                  let url = urls.first else { return }
            Task {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                await model.cloud.upload(fileAt: url)
            }
        }
        .alert(
            L10n.string("ui.desktop.collection.play_all_failed"),
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
            Text(playbackErrorMessage ?? L10n.string("ui.desktop.collection.complete_list_failed"))
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        switch section {
        case .songs:
            Button(action: playFavoriteSongs) {
                HStack(spacing: 7) {
                    Label("ui.common.play_all", systemImage: "play.fill")
                    if isPreparingPlayback {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(
                model.library.favoriteSongs.isEmpty
                    || isPreparingPlayback
            )
        case .downloads:
            Button("ui.common.play_all", systemImage: "play.fill") {
                Task { await model.player.playAll(model.downloads.downloadedSongs) }
            }
            .disabled(model.downloads.downloadedSongs.isEmpty)
        case .cloud:
            Button("ui.cloud.upload_music", systemImage: "plus") { showsImporter = true }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isAwaitingInitialContent {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 340)
        } else {
            switch section {
            case .recent:
                songList(model.library.recentSongs)
            case .songs:
                favoriteSongList
            case .downloads:
                songList(model.downloads.downloadedSongs)
            case .cloud:
                cloudList
            case .playlists:
                playlistGrid
            case .albums:
                albumGrid
            case .podcasts:
                podcastGrid
            default:
                EmptyView()
            }
        }
    }

    private var favoriteSongList: some View {
        VStack(spacing: 0) {
            songList(
                model.library.favoriteSongs,
                loadMoreToken: model.library.hasMoreFavoriteSongs
                    ? model.library.favoriteSongsNextOffset
                    : nil,
                onLoadMore: {
                    await model.library.loadMoreFavoriteSongs()
                }
            )

            if model.library.hasMoreFavoriteSongs {
                DesktopCollectionPaginationFooter(
                    isLoading: model.library.isLoadingMoreFavoriteSongs,
                    failureMessage:
                        model.library.favoriteSongsLoadMoreError
                ) {
                    await model.library.loadMoreFavoriteSongs()
                }
            }
        }
    }

    private var isAwaitingInitialContent: Bool {
        switch section {
        case .recent:
            model.library.phase == .loading
                && model.library.recentSongs.isEmpty
        case .songs:
            model.library.phase == .loading
                && model.library.favoriteSongs.isEmpty
        case .playlists:
            model.library.phase == .loading
                && model.library.favoritePlaylists.isEmpty
        case .albums:
            model.library.phase == .loading
                && model.library.favoriteAlbums.isEmpty
        case .podcasts:
            model.library.phase == .loading
                && model.library.subscribedPodcasts.isEmpty
        case .cloud:
            (model.cloud.phase == .loading || model.cloud.isUploading)
                && model.cloud.items.isEmpty
        default:
            false
        }
    }

    @ViewBuilder
    private func songList(
        _ songs: [Song],
        loadMoreToken: Int? = nil,
        onLoadMore: (() async -> Void)? = nil
    ) -> some View {
        if songs.isEmpty {
            libraryEmptyView
        } else {
            LazyVStack(spacing: 2) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    let row = DesktopTrackRow(
                        song: song,
                        index: index,
                        songs: songs,
                        showsArtwork: true
                    )

                    if song.id == songs.last?.id,
                       let loadMoreToken,
                       let onLoadMore {
                        row.task(id: loadMoreToken) {
                            await onLoadMore()
                        }
                    } else {
                        row
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var playlistGrid: some View {
        let playlists = model.library.favoritePlaylists
        if playlists.isEmpty {
            libraryEmptyView
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(playlists) { playlist in
                    DesktopMediaCard(
                        title: playlist.name,
                        subtitle: playlist.creator?.nickname,
                        artworkURL: playlist.artworkURL,
                        playCount: playlist.playCount,
                        showsPlayCount: model.settings.showPlayCount,
                        action: { model.ui.navigate(to: .playlist(playlist.id)) },
                        playAction: { play(playlist) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var albumGrid: some View {
        let albums = model.library.favoriteAlbums
        if albums.isEmpty {
            libraryEmptyView
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(albums) { album in
                    DesktopMediaCard(
                        title: album.name,
                        subtitle: album.artistText,
                        artworkURL: album.artworkURL,
                        action: { model.ui.navigate(to: .album(album.id)) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var podcastGrid: some View {
        let podcasts = model.library.subscribedPodcasts
        if podcasts.isEmpty {
            libraryEmptyView
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(podcasts) { podcast in
                    let card = DesktopMediaCard(
                        title: podcast.name,
                        subtitle: podcast.subtitle,
                        artworkURL: podcast.artworkURL,
                        action: { model.ui.navigate(to: .podcast(podcast.id)) }
                    )

                    if podcast.id == podcasts.last?.id,
                       model.library.hasMoreSubscribedPodcasts {
                        card.task(
                            id: model.library.subscribedPodcastsNextOffset
                        ) {
                            await model.library.loadMoreSubscribedPodcasts()
                        }
                    } else {
                        card
                    }
                }
            }

            if model.library.hasMoreSubscribedPodcasts {
                DesktopCollectionPaginationFooter(
                    isLoading:
                        model.library.isLoadingMoreSubscribedPodcasts,
                    failureMessage:
                        model.library.subscribedPodcastsLoadMoreError,
                    loadingTitle: L10n.string("ui.podcasts.loading_more")
                ) {
                    await model.library.loadMoreSubscribedPodcasts()
                }
            }
        }
    }

    @ViewBuilder
    private var cloudList: some View {
        if model.cloud.items.isEmpty {
            libraryEmptyView
        } else {
            LazyVStack(spacing: 2) {
                ForEach(Array(model.cloud.items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 0) {
                        DesktopTrackRow(
                            song: item.simpleSong,
                            index: index,
                            songs: model.cloud.songs,
                            showsArtwork: true
                        )
                        Button(role: .destructive) {
                            Task { await model.cloud.delete(item) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                    }
                    .task { await model.cloud.loadMoreIfNeeded(after: item) }
                }
            }
        }
    }

    private var libraryEmptyView: some View {
        ContentUnavailableView {
            Label(
                model.library.isLoggedIn
                    ? L10n.string("ui.desktop.library.empty")
                    : L10n.string("ui.desktop.library.sign_in_title"),
                systemImage: section.systemImage
            )
        } description: {
            Text(
                model.library.isLoggedIn
                    ? L10n.string("ui.desktop.library.empty.message")
                    : L10n.string("ui.desktop.library.sign_in_message")
            )
        } actions: {
            if !model.library.isLoggedIn {
                Button("ui.common.login") { model.ui.sheet = .login }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 340)
    }

    private func play(_ playlist: Playlist) {
        Task {
            guard let detail = try? await model.api.playlist(
                id: playlist.id,
                trackLimit: nil
            ) else { return }
            await model.player.playAll(detail.tracks, sourceID: playlist.id)
        }
    }

    private func playFavoriteSongs() {
        guard !isPreparingPlayback else { return }
        isPreparingPlayback = true
        playbackErrorMessage = nil

        Task { @MainActor in
            defer { isPreparingPlayback = false }
            do {
                let songs = try await model.library.favoriteSongsForPlayback()
                try Task.checkCancellation()
                await model.player.playAll(songs)
            } catch is CancellationError {
                return
            } catch {
                playbackErrorMessage = error.localizedDescription
            }
        }
    }
}
