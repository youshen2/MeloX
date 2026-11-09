import SwiftUI

struct AlbumDetailContent: View {
    let album: Album
    let songs: [Song]
    let palette: ArtworkDetailPalette
    let blurredBackdropImage: CGImage?
    let usesTabletBackdrop: Bool
    let searchQuery: String
    let isLoading: Bool
    let failureMessage: String?
    let isSubscribed: Bool
    let downloadCoordinator: MusicCollectionDownloadCoordinator?
    let onToggleSubscription: () -> Void
    let onRetry: () -> Void
    let onRefresh: () async -> Void
    var highlightedSongID: Int?

    var body: some View {
        ZStack {
            MusicCollectionArtworkBackdrop(
                blurredArtworkImage: blurredBackdropImage,
                palette: palette,
                usesTabletBackdrop: usesTabletBackdrop
            )

            ScrollView {
                MusicCollectionDetailLayout { artworkSize in
                    StandardMusicCollectionDetailHero(
                        artworkURL: album.artworkURL,
                        title: album.name,
                        subtitle: album.artistText,
                        metadataText: metadataText,
                        tracks: songs,
                        sourceID: album.id,
                        isSaved: isSubscribed,
                        onToggleSaved: onToggleSubscription,
                        wideArtworkSize: artworkSize
                    )
                } tracks: { wideArtistColumnWidth in
                    MusicCollectionTrackContent(
                        tracks: filteredTracks,
                        sourceID: album.id,
                        showsArtwork: false,
                        loadingTitle: L10n.string("ui.album.loading"),
                        isLoading: isLoading,
                        failureMessage: failureMessage,
                        downloadSelection: downloadCoordinator,
                        onRetry: onRetry,
                        highlightedSongID: highlightedSongID,
                        wideArtistColumnWidth: wideArtistColumnWidth
                    )
                }
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await onRefresh()
            }
        }
        .foregroundStyle(.primary)
    }

    private var metadataText: String {
        var components = [album.type?.nonemptyAlbumMetadata ?? L10n.string("ui.common.album")]
        if let publishTime = album.publishTime {
            let date = Date(timeIntervalSince1970: publishTime / 1_000)
            let year = Calendar.current.component(.year, from: date)
            components.append(L10n.format("ui.common.year", year))
        }
        let count = songs.isEmpty ? (album.size ?? 0) : songs.count
        components.append(L10n.format("ui.common.song_count", count))
        return L10n.joined(
            components,
            separatorKey: "ui.common.metadata_separator"
        )
    }

    private var filteredTracks: [Song] {
        filterMusicCollectionTracks(songs, query: searchQuery)
    }
}

private extension String {
    var nonemptyAlbumMetadata: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
