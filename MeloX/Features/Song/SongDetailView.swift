import SwiftUI

struct SongDetailView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(DownloadStore.self) private var downloads

    @State private var song: Song
    @State private var commentSong: Song?

    init(song: Song) {
        _song = State(initialValue: song)
    }

    var body: some View {
        List {
            songHeader
            informationSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("歌曲详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    if downloads.isDownloading(songID: song.id) {
                        Button {
                            downloads.cancel(songID: song.id)
                        } label: {
                            Label("取消下载", systemImage: "xmark.circle")
                        }
                    } else if downloads.contains(songID: song.id) {
                        Button(role: .destructive) {
                            downloads.remove(songID: song.id)
                        } label: {
                            Label("删除下载", systemImage: "trash")
                        }
                    } else {
                        Section("选择下载音质") {
                            ForEach(MusicQuality.allCases) { quality in
                                Button(quality.title) {
                                    downloads.start(song, quality: quality)
                                }
                            }
                        }
                    }
                } label: {
                    Image(
                        systemName: downloads.contains(songID: song.id)
                            ? "arrow.down.circle.fill"
                            : "arrow.down.circle"
                    )
                }
                .accessibilityLabel(downloads.contains(songID: song.id) ? "已下载" : "下载")

                Button {
                    commentSong = song
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .accessibilityLabel("查看评论")

                Menu {
                    NeteaseShareMenuContent(resource: .song(song))
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("分享歌曲")
            }
        }
        .sheet(item: $commentSong) { selectedSong in
            SongCommentsSheet(song: selectedSong)
        }
        .task(id: song.id) {
            await loadSongDetails()
        }
        .alert(
            "收藏失败",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { if !$0 { library.clearError() } }
            )
        ) {
            Button("好", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? "未知错误")
        }
    }

    private var songHeader: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    ArtworkImage(url: song.album?.artworkURL, cornerRadius: 12)
                        .frame(width: 112, height: 112)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(song.name)
                            .font(.title2.bold())
                            .lineLimit(2)

                        if !song.aliases.isEmpty {
                            Text(song.aliases.joined(separator: " / "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Text(song.artistText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                HStack {
                    Button {
                        Task { await player.play(song, in: [song]) }
                    } label: {
                        Text("播放")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        library.toggle(song: song)
                    } label: {
                        Label(
                            library.contains(song: song) ? "已收藏" : "收藏",
                            systemImage: library.contains(song: song) ? "heart.fill" : "heart"
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var informationSection: some View {
        Section("歌曲资料") {
            ForEach(song.artists) { artist in
                NavigationLink(value: MusicRoute.artist(artist.id)) {
                    LabeledContent("歌手", value: artist.name)
                }
                .musicMatchedTransitionSource(for: MusicRoute.artist(artist.id))
            }

            if let album = song.album {
                NavigationLink(value: MusicRoute.album(album)) {
                    LabeledContent("专辑", value: album.name)
                }
                .musicMatchedTransitionSource(for: MusicRoute.album(album))
            }

            if let publishTime = song.publishTime ?? song.album?.publishTime {
                LabeledContent("发行日期") {
                    Text(
                        Date(timeIntervalSince1970: publishTime / 1_000),
                        format: .dateTime.year().month().day()
                    )
                }
            }

        }
    }

    private func loadSongDetails() async {
        do {
            let details = try await api.songDetails(ids: [song.id])
            try Task.checkCancellation()
            if let detail = details.first {
                song = detail
            }
        } catch {
            // 列表传入的歌曲数据仍可完整展示基础资料。
        }
    }
}
