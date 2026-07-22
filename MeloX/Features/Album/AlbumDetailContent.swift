import SwiftUI

struct AlbumDetailContent: View {
    let album: Album
    let songs: [Song]
    let palette: ArtworkDetailPalette
    let blurredBackdropImage: CGImage?
    let searchQuery: String
    let isLoading: Bool
    let failureMessage: String?
    let isSubscribed: Bool
    let onToggleSubscription: () -> Void
    let onRetry: () -> Void
    let onRefresh: () async -> Void

    var body: some View {
        ZStack {
            MusicCollectionArtworkBackdrop(
                blurredArtworkImage: blurredBackdropImage,
                palette: palette
            )

            ScrollView {
                LazyVStack(spacing: 0) {
                    StandardMusicCollectionDetailHero(
                        artworkURL: album.artworkURL,
                        title: album.name,
                        subtitle: album.artistText,
                        metadataText: metadataText,
                        tracks: songs,
                        sourceID: album.id,
                        isSaved: isSubscribed,
                        onToggleSaved: onToggleSubscription
                    )

                    MusicCollectionTrackContent(
                        tracks: filteredTracks,
                        sourceID: album.id,
                        showsArtwork: false,
                        loadingTitle: "正在载入专辑",
                        isLoading: isLoading,
                        failureMessage: failureMessage,
                        onRetry: onRetry
                    )
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await onRefresh()
            }
        }
        .foregroundStyle(.primary)
    }

    private var metadataText: String {
        var components = [album.type?.nonemptyAlbumMetadata ?? "专辑"]
        if let publishTime = album.publishTime {
            let date = Date(timeIntervalSince1970: publishTime / 1_000)
            let year = Calendar.current.component(.year, from: date)
            components.append("\(year)年")
        }
        let count = songs.isEmpty ? (album.size ?? 0) : songs.count
        components.append("\(count) 首歌曲")
        return components.joined(separator: " · ")
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
