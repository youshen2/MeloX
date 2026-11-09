import SwiftUI

struct TrackRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openMusicRoute) private var openMusicRoute
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(DownloadStore.self) private var downloads

    let song: Song
    var index: Int?
    var showsArtwork = false
    var secondaryMetadata: String?

    @ScaledMetric(relativeTo: .caption) private var indexWidth: CGFloat = 26
    @State private var presentedSheet: TrackRowSheet?

    var body: some View {
        HStack(spacing: 12) {
            if let indexText {
                Text(indexText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: indexWidth, alignment: .trailing)
            }
            if showsArtwork {
                ArtworkImage(url: song.album?.artworkURL, cornerRadius: 6)
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.body)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(
                        secondaryMetadata != nil || dynamicTypeSize.isAccessibilitySize ? 2 : 1
                    )
            }
            Spacer(minLength: 8)
            if AppFeatureAvailability.downloads {
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
            if song.durationMS > 0 {
                Text(song.durationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
        .musicMatchedTransitionSource(for: .song(song))
        .contextMenu {
            Button {
                Task { await player.playNext(song) }
            } label: {
                Label(
                    "ui.player.play_next",
                    systemImage:
                        "text.line.first.and.arrowtriangle.forward"
                )
            }

            Button {
                presentedSheet = .addToPlaylist(song)
            } label: {
                Label("ui.playlists.add_to", systemImage: "text.badge.plus")
            }

            if !song.isPodcastProgram {
                Button {
                    library.toggle(song: song)
                } label: {
                    Label(
                        favoriteActionTitle,
                        systemImage: favoriteActionSystemImage
                    )
                }
            }

            if AppFeatureAvailability.downloads {
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
                presentedSheet = .comments(song)
            } label: {
                Label("ui.comments.title", systemImage: "bubble.left.and.bubble.right")
            }

            Menu {
                NeteaseShareMenuContent(resource: .song(song))
            } label: {
                Label("ui.common.share", systemImage: "square.and.arrow.up")
            }
        }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAction(named: L10n.string("ui.song.view_information")) {
            openMusicRoute(.song(song))
        }
        .accessibilityAction(named: L10n.string("ui.player.play_next")) {
            Task { await player.playNext(song) }
        }
        .accessibilityAction(named: L10n.string("ui.playlists.add_to")) {
            presentedSheet = .addToPlaylist(song)
        }
        .songFavoriteAccessibilityAction(
            song: song,
            library: library
        )
        .accessibilityAction(named: L10n.string("ui.comments.view")) {
            presentedSheet = .comments(song)
        }
    }

    private var favoriteActionTitle: String {
        library.contains(song: song)
            ? L10n.string("ui.song.unlike")
            : L10n.string("ui.song.like")
    }

    private var indexText: String? {
        index.map { L10n.integer($0 + 1) }
    }

    private var subtitleText: String {
        [song.artistText, secondaryMetadata]
            .compactMap { value in
                guard let value else { return nil }
                let normalized = value.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                return normalized.isEmpty ? nil : normalized
            }
            .joined(
                separator: L10n.string("ui.common.metadata_separator")
            )
    }

    private var accessibilityText: String {
        let trackLabel = subtitleText.isEmpty
            ? song.name
            : L10n.format(
                "ui.accessibility.track_title_and_subtitle",
                song.name,
                subtitleText
            )
        return L10n.joined(
            [indexText, trackLabel].compactMap { $0 },
            separatorKey: "ui.common.spoken_separator"
        )
    }

    private var favoriteActionSystemImage: String {
        library.contains(song: song) ? "heart.slash" : "heart"
    }
}

private enum TrackRowSheet: Identifiable {
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

private extension View {
    @ViewBuilder
    func songFavoriteAccessibilityAction(
        song: Song,
        library: LibraryStore
    ) -> some View {
        if song.isPodcastProgram {
            self
        } else {
            accessibilityAction(
                named:
                    library.contains(song: song)
                        ? L10n.string("ui.song.unlike")
                        : L10n.string("ui.song.like")
            ) {
                library.toggle(song: song)
            }
        }
    }
}
