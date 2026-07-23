import SwiftUI

private enum LibraryRoute: Hashable {
    case privateMessages
}

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings
    @Environment(DownloadStore.self) private var downloads

    @State private var section: LibraryPage = .songs
    @State private var hasAppliedInitialPage = false
    @State private var showsLogin = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("音乐库分类", selection: $section) {
                ForEach(LibraryPage.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if section == .downloads {
                downloadedSongList
            } else if !library.isLoggedIn {
                loginUnavailableView
            } else {
                libraryContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("音乐库")
        .toolbar {
            if library.isLoggedIn {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: LibraryRoute.privateMessages) {
                        Image(
                            systemName: "bubble.left.and.bubble.right"
                        )
                    }
                    .accessibilityLabel("私信")
                }
            }
        }
        .navigationDestination(for: LibraryRoute.self) { route in
            switch route {
            case .privateMessages:
                NeteasePrivateMessagesView()
            }
        }
        .onAppear {
            guard !hasAppliedInitialPage else { return }
            hasAppliedInitialPage = true
            section = settings.initialLibraryPage
        }
        .onChange(of: section) { _, page in
            settings.lastLibraryPage = page
        }
        .sheet(isPresented: $showsLogin) {
            NavigationStack {
                NeteaseLoginView()
            }
        }
        .task(id: settings.cookie) {
            await library.refresh()
        }
        .alert(
            "音乐库操作失败",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { presented in
                    if !presented {
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

    private var loginUnavailableView: some View {
        ContentUnavailableView {
            Label("需要登录", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text("登录后可读取收藏歌曲、歌单、音乐云盘和播放记录；已下载歌曲无需登录。")
        } actions: {
            Button("登录网易云音乐") {
                showsLogin = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        switch library.phase {
        case .loading where library.profile == nil:
            ProgressView("正在读取音乐库")
        case .failed(let message) where library.profile == nil:
            ConnectionUnavailableView(message: message) {
                Task { await library.refresh(force: true) }
            }
        default:
            switch section {
            case .songs:
                songList(
                    library.favoriteSongs,
                    emptyTitle: "还没有收藏歌曲",
                    hasMore: library.hasMoreFavoriteSongs,
                    isLoadingMore: library.isLoadingMoreFavoriteSongs,
                    loadMoreFailure: library.favoriteSongsLoadMoreError,
                    loadMoreToken: library.favoriteSongsNextOffset,
                    onLoadMore: {
                        await library.loadMoreFavoriteSongs()
                    }
                )
            case .playlists:
                playlistList
            case .downloads:
                downloadedSongList
            case .cloud:
                CloudMusicView()
            case .history:
                songList(
                    library.recentSongs,
                    emptyTitle: "还没有播放记录"
                )
            }
        }
    }

    private var downloadedSongList: some View {
        List {
            NavigationLink {
                DownloadsView()
            } label: {
                HStack {
                    Label("下载管理", systemImage: "arrow.down.circle")
                    Spacer()
                    Text(downloadManagementValue)
                        .foregroundStyle(.secondary)
                }
            }

            if !activeDownloadSongs.isEmpty {
                Section("正在下载") {
                    ForEach(activeDownloadSongs) { song in
                        TrackRowView(song: song, showsArtwork: true)
                        .swipeActions {
                            Button(role: .destructive) {
                                downloads.cancel(songID: song.id)
                            } label: {
                                Label("取消", systemImage: "xmark")
                            }
                        }
                    }
                }
            }

            if !downloads.downloadedSongs.isEmpty {
                Button {
                    Task { await player.playAll(downloads.downloadedSongs) }
                } label: {
                    Label("播放全部", systemImage: "play.fill")
                }
            }

            ForEach(downloads.downloads) { download in
                Button {
                    Task {
                        await player.play(
                            download.song,
                            in: downloads.downloadedSongs
                        )
                    }
                } label: {
                    TrackRowView(song: download.song, showsArtwork: true)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        downloads.remove(songID: download.id)
                    } label: {
                        Label("删除下载", systemImage: "trash")
                    }
                }
            }

            if downloads.downloads.isEmpty && activeDownloadSongs.isEmpty {
                ContentUnavailableView(
                    "还没有下载歌曲",
                    systemImage: "arrow.down.circle",
                    description: Text("在歌曲的更多操作菜单中选择“下载歌曲”。")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    private var activeDownloadSongs: [Song] {
        downloads.activeSongs.values.sorted {
            $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    private var downloadManagementValue: String {
        if !downloads.activeDownloads.isEmpty {
            return "\(downloads.activeDownloads.count) 项进行中"
        }
        return downloads.totalByteCount.formatted(.byteCount(style: .file))
    }

    private func songList(
        _ songs: [Song],
        emptyTitle: String,
        hasMore: Bool = false,
        isLoadingMore: Bool = false,
        loadMoreFailure: String? = nil,
        loadMoreToken: Int = 0,
        onLoadMore: @escaping () async -> Void = {}
    ) -> some View {
        List {
            if !songs.isEmpty {
                Button {
                    Task { await player.playAll(songs) }
                } label: {
                    Label("播放全部", systemImage: "play.fill")
                }
            }
            ForEach(songs) { song in
                Button {
                    Task { await player.play(song, in: songs) }
                } label: {
                    TrackRowView(song: song, showsArtwork: true)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    if section == .songs {
                        Button(role: .destructive) {
                            library.toggle(song: song)
                        } label: {
                            Label("取消收藏", systemImage: "heart.slash")
                        }
                    }
                }
            }

            if hasMore {
                MusicCollectionPaginationFooter(
                    isLoading: isLoadingMore,
                    failureMessage: loadMoreFailure,
                    loadToken: loadMoreToken,
                    action: onLoadMore
                )
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await library.refresh(force: true)
        }
        .overlay {
            if songs.isEmpty && !hasMore {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: section == .history ? "clock" : "heart",
                    description: Text(section == .history ? "网易云音乐中的最近播放会显示在这里。" : "在歌曲列表左滑即可收藏到网易云音乐。")
                )
            }
        }
    }

    private var playlistList: some View {
        List(library.favoritePlaylists) { playlist in
            NavigationLink(value: MusicRoute.playlist(playlist)) {
                SearchMediaRowForLibrary(playlist: playlist)
            }
            .musicMatchedTransitionSource(for: MusicRoute.playlist(playlist))
            .swipeActions(edge: .trailing) {
                if library.canUnsubscribe(playlist) {
                    Button(role: .destructive) {
                        library.toggle(playlist: playlist)
                    } label: {
                        Label("取消收藏", systemImage: "heart.slash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await library.refresh(force: true)
        }
        .overlay {
            if library.favoritePlaylists.isEmpty {
                ContentUnavailableView(
                    "还没有收藏歌单",
                    systemImage: "music.note.list",
                    description: Text("打开歌单详情后，轻点收藏按钮。")
                )
            }
        }
    }
}

private struct SearchMediaRowForLibrary: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: playlist.artworkURL, cornerRadius: 7)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .lineLimit(1)
                Text("\(playlist.trackCount) 首歌曲")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
