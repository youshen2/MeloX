import SwiftUI

private enum LibrarySection: String, CaseIterable, Identifiable {
    case songs = "歌曲"
    case playlists = "歌单"
    case history = "播放历史"

    var id: String { rawValue }
}

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @State private var section: LibrarySection = .songs
    @State private var showsLogin = false

    var body: some View {
        Group {
            if !library.isLoggedIn {
                ContentUnavailableView {
                    Label("需要登录", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("登录网易云音乐后，才能读取你的收藏歌曲、歌单和播放记录。")
                } actions: {
                    Button("登录网易云音乐") {
                        showsLogin = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                libraryContent
            }
        }
        .navigationTitle("音乐库")
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
            VStack(spacing: 0) {
                Picker("音乐库分类", selection: $section) {
                    ForEach(LibrarySection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch section {
                case .songs:
                    songList(library.favoriteSongs, emptyTitle: "还没有收藏歌曲")
                case .playlists:
                    playlistList
                case .history:
                    songList(
                        library.recentSongs,
                        emptyTitle: "还没有播放记录"
                    )
                }
            }
        }
    }

    private func songList(_ songs: [Song], emptyTitle: String) -> some View {
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
        }
        .listStyle(.plain)
        .refreshable {
            await library.refresh(force: true)
        }
        .overlay {
            if songs.isEmpty {
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
