import SwiftUI

struct SongDetailView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(DownloadStore.self) private var downloads
    @Environment(AppSettings.self) private var settings

    @State private var song: Song
    @State private var presentedSheet: SongDetailSheet?

    init(song: Song) {
        _song = State(initialValue: song)
    }

    var body: some View {
        List {
            songHeader
            informationSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ui.song.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if settings.isContentFeatureEnabled(.downloads) {
                    Menu {
                        if downloads.isDownloading(songID: song.id) {
                            Button {
                                downloads.cancel(songID: song.id)
                            } label: {
                                Label("ui.downloads.cancel", systemImage: "xmark.circle")
                            }
                        } else if downloads.contains(songID: song.id) {
                            Button(role: .destructive) {
                                downloads.remove(songID: song.id)
                            } label: {
                                Label("ui.downloads.delete", systemImage: "trash")
                            }
                        } else {
                            Section("ui.downloads.select_quality") {
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
                    .accessibilityLabel(
                        downloads.contains(songID: song.id)
                            ? L10n.string("ui.downloads.downloaded")
                            : L10n.string("ui.common.download")
                    )
                }

                Button {
                    presentedSheet = .comments(song)
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .accessibilityLabel("ui.comments.view")

                Menu {
                    NeteaseShareMenuContent(resource: .song(song))
                } label: {
                    MusicToolbarSymbol(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("ui.song.share")
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .comments(let selectedSong):
                SongCommentsSheet(song: selectedSong)
            case .songWiki(let selectedSong):
                SongWikiSheet(song: selectedSong)
            }
        }
        .task(id: song.id) {
            await loadSongDetails()
        }
        .alert(
            "ui.error.favorite_failed",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { if !$0 { library.clearError() } }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? L10n.string("ui.common.unknown_error"))
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
                            Text(
                                L10n.joined(
                                    song.aliases,
                                    separatorKey:
                                        "ui.common.artist_separator"
                                )
                            )
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
                        Text("ui.common.play")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        library.toggle(song: song)
                    } label: {
                        Label(
                            library.contains(song: song)
                                ? L10n.string("ui.common.favorited")
                                : L10n.string("ui.common.favorite"),
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
        Section("ui.song.information") {
            Button {
                presentedSheet = .songWiki(song)
            } label: {
                Label("ui.song.wiki.title", systemImage: "book.pages")
            }

            ForEach(song.artists) { artist in
                NavigationLink(value: MusicRoute.artist(artist.id)) {
                    LabeledContent(L10n.string("ui.common.artist"), value: artist.name)
                }
                .musicMatchedTransitionSource(for: MusicRoute.artist(artist.id))
            }

            if let album = song.album {
                NavigationLink(value: MusicRoute.album(album)) {
                    LabeledContent(L10n.string("ui.common.album"), value: album.name)
                }
                .musicMatchedTransitionSource(for: MusicRoute.album(album))
            }

            if let publishTime = song.publishTime ?? song.album?.publishTime {
                LabeledContent("ui.song.release_date") {
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

private enum SongDetailSheet: Identifiable {
    case comments(Song)
    case songWiki(Song)

    var id: String {
        switch self {
        case .comments(let song):
            "comments-\(song.id)"
        case .songWiki(let song):
            "song-wiki-\(song.id)"
        }
    }
}
