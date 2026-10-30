import SwiftUI

struct PlaylistTrackList: View {
    let tracks: [Song]
    let sourceID: Int
    let showsArtwork: Bool
    var onRemoveSong: ((Song) -> Void)?
    var downloadSelection: MusicCollectionDownloadCoordinator?
    var highlightedSongID: Int?

    var body: some View {
        if tracks.isEmpty {
            ContentUnavailableView("ui.songs.empty", systemImage: "music.note.list")
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, song in
                    PlaylistTrackRow(
                        song: song,
                        tracks: tracks,
                        sourceID: sourceID,
                        index: index,
                        showsArtwork: showsArtwork,
                        downloadSelection: downloadSelection,
                        onRemoveSong: onRemoveSong,
                        isHighlighted: highlightedSongID == song.id
                    )
                    .id(song.id)

                    if song.id != tracks.last?.id {
                        Divider()
                            .overlay(Color.primary.opacity(0.12))
                            .padding(
                                .leading,
                                (showsArtwork ? 80 : 66)
                                    + (isSelectingDownloads ? 36 : 0)
                            )
                            .padding(.trailing, 20)
                    }
                }
            }
        }
    }

    private var isSelectingDownloads: Bool {
        downloadSelection?.isSelecting == true
    }
}

private struct PlaylistTrackRow: View {
    let song: Song
    let tracks: [Song]
    let sourceID: Int
    let index: Int
    let showsArtwork: Bool
    let downloadSelection: MusicCollectionDownloadCoordinator?
    let onRemoveSong: ((Song) -> Void)?
    let isHighlighted: Bool

    @Environment(\.openMusicRoute) private var openMusicRoute
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(DownloadStore.self) private var downloads
    @Environment(AppSettings.self) private var settings

    @State private var presentedSheet: PlaylistSongSheet?

    private var isCurrentSong: Bool {
        player.currentSong?.id == song.id
    }

    private var isSelectingDownloads: Bool {
        downloadSelection?.isSelecting == true
    }

    private var isSelectedForDownload: Bool {
        downloadSelection?.selectedSongIDs.contains(song.id) == true
    }

    private var canSelectForDownload: Bool {
        !downloads.contains(songID: song.id)
            && !downloads.isDownloading(songID: song.id)
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: primaryAction) {
                HStack(spacing: 12) {
                    if isSelectingDownloads {
                        Image(
                            systemName: isSelectedForDownload
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            canSelectForDownload ? .primary : .tertiary
                        )
                        .frame(width: 24)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                    }

                    leadingContent

                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.name)
                            .font(.body)
                            .lineLimit(showsArtwork ? 1 : 2)

                        if showsArtwork {
                            Text(song.artistText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isSelectingDownloads && !canSelectForDownload)
            .accessibilityLabel(primaryActionAccessibilityLabel)
            .accessibilityValue(primaryActionAccessibilityValue)

            if settings.isContentFeatureEnabled(.downloads) {
                if downloads.isDownloading(songID: song.id) {
                    ProgressView()
                        .controlSize(.mini)
                        .accessibilityLabel("ui.downloads.downloading")
                } else if downloads.contains(songID: song.id) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("ui.downloads.downloaded")
                }
            }

            if !isSelectingDownloads {
                Menu {
                    Button {
                        Task { await player.playNext(song) }
                    } label: {
                        Label(
                            "ui.player.play_next",
                            systemImage:
                                "text.line.first.and.arrowtriangle.forward"
                        )
                    }

                    if settings.isContentFeatureEnabled(.downloads) {
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
                            Menu {
                                ForEach(MusicQuality.allCases) { quality in
                                    Button(quality.title) {
                                        downloads.start(song, quality: quality)
                                    }
                                }
                            } label: {
                                Label("ui.downloads.download_song", systemImage: "arrow.down.circle")
                            }
                        }
                    }

                    Button {
                        openMusicRoute(.song(song))
                    } label: {
                        Label("ui.song.information", systemImage: "info.circle")
                    }

                    Button {
                        library.toggle(song: song)
                    } label: {
                        Label(
                            library.contains(song: song)
                                ? L10n.string("ui.song.unlike")
                                : L10n.string("ui.song.like"),
                            systemImage: library.contains(song: song) ? "heart.slash" : "heart"
                        )
                    }

                    Button {
                        presentedSheet = .comments(song)
                    } label: {
                        Label("ui.comments.title", systemImage: "bubble.left.and.bubble.right")
                    }

                    Button {
                        presentedSheet = .addToPlaylist(song)
                    } label: {
                        Label("ui.playlists.add_to", systemImage: "text.badge.plus")
                    }

                    if let onRemoveSong {
                        Divider()
                        Button("ui.playlists.remove_song", systemImage: "minus.circle", role: .destructive) {
                            onRemoveSong(song)
                        }
                    }

                    Menu {
                        NeteaseShareMenuContent(resource: .song(song))
                    } label: {
                        Label("ui.common.share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .frame(width: 42, height: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel(L10n.format("ui.song.more_actions", song.name))
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, showsArtwork ? 8 : 11)
        .background(
            isHighlighted ? Color.accentColor.opacity(0.16)
                : isCurrentSong ? Color.primary.opacity(0.10) : .clear
        )
        .musicMatchedTransitionSource(for: .song(song))
        .accessibilityElement(children: .contain)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .comments(let selectedSong):
                SongCommentsSheet(song: selectedSong)
            case .addToPlaylist(let selectedSong):
                AddToPlaylistSheet(song: selectedSong)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private var leadingContent: some View {
        if showsArtwork {
            ArtworkImage(url: song.album?.artworkURL, cornerRadius: 6)
                .frame(width: 48, height: 48)
        } else if isCurrentSong && !isSelectingDownloads {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.60), lineWidth: 1.5)

                if player.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.caption.weight(.bold))
                }
            }
            .frame(width: 32, height: 32)
            .frame(width: 40)
        } else {
            Text(
                (index + 1).formatted(
                    .number.locale(L10n.locale)
                )
            )
                .font(.title3)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 40, alignment: .center)
        }
    }

    private var primaryActionAccessibilityLabel: String {
        L10n.format(
            "ui.accessibility.song_and_artist",
            song.name,
            song.artistText
        )
    }

    private var primaryActionAccessibilityValue: String {
        guard isSelectingDownloads else {
            return isCurrentSong ? L10n.string("ui.player.now_playing") : ""
        }
        if !canSelectForDownload {
            return downloads.contains(songID: song.id)
                ? L10n.string("ui.downloads.downloaded")
                : L10n.string("ui.downloads.downloading")
        }
        return isSelectedForDownload
            ? L10n.string("ui.common.selected")
            : L10n.string("ui.common.not_selected")
    }

    private func primaryAction() {
        if isSelectingDownloads {
            guard canSelectForDownload else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                downloadSelection?.toggleSelection(songID: song.id)
            }
        } else {
            playOrPause()
        }
    }

    private func playOrPause() {
        if isCurrentSong {
            player.togglePlayback()
        } else {
            Task { await player.play(song, in: tracks, sourceID: sourceID) }
        }
    }
}

private enum PlaylistSongSheet: Identifiable {
    case comments(Song)
    case addToPlaylist(Song)

    var id: String {
        switch self {
        case .comments(let song):
            "comments-\(song.id)"
        case .addToPlaylist(let song):
            "add-to-playlist-\(song.id)"
        }
    }
}
