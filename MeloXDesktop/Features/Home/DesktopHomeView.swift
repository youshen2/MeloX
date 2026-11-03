import SwiftUI

struct DesktopHomeView: View {
    @Environment(DesktopAppModel.self) private var model

    private enum Metrics {
        static let horizontalPadding: CGFloat = 52
        static let heroMinimumCardWidth: CGFloat = 200
        static let heroSpacing: CGFloat = 20
        static let mediaMinimumCardWidth: CGFloat = 145
        static let mediaSpacing: CGFloat = 24

        struct ShelfLayout {
            let cardWidth: CGFloat
            let visibleItemCount: Int
        }

        static func shelfLayout(
            containerWidth: CGFloat,
            minimumCardWidth: CGFloat,
            spacing: CGFloat
        ) -> ShelfLayout {
            let usableWidth = max(
                containerWidth - horizontalPadding * 2,
                0
            )
            let columnCount = max(
                Int(
                    (usableWidth + spacing)
                        / (minimumCardWidth + spacing)
                ),
                1
            )
            let totalSpacing = spacing * CGFloat(columnCount - 1)
            let rawWidth = (usableWidth - totalSpacing)
                / CGFloat(columnCount)
            return ShelfLayout(
                cardWidth: max(rawWidth.rounded(.down), 1),
                visibleItemCount: columnCount
            )
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let heroLayout = Metrics.shelfLayout(
                containerWidth: proxy.size.width,
                minimumCardWidth: Metrics.heroMinimumCardWidth,
                spacing: Metrics.heroSpacing
            )
            let mediaLayout = Metrics.shelfLayout(
                containerWidth: proxy.size.width,
                minimumCardWidth: Metrics.mediaMinimumCardWidth,
                spacing: Metrics.mediaSpacing
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    Text("ui.navigation.home")
                        .font(.system(size: 46, weight: .bold))

                    DesktopHomeQuickActionsView(
                        cardWidth: heroLayout.cardWidth,
                        spacing: Metrics.heroSpacing,
                        visibleItemCount: heroLayout.visibleItemCount
                    )

                    heroSection(layout: heroLayout)

                    if model.settings.isContentFeatureEnabled(
                        .listeningHistory
                    ), !recentSongs.isEmpty {
                        songCardSection(
                            title: L10n.string("ui.navigation.library.history"),
                            songs: Array(recentSongs.prefix(8)),
                            layout: mediaLayout
                        )
                    }

                    if !model.home.recommendedPlaylists.isEmpty {
                        playlistSection(layout: mediaLayout)
                    }

                    if !model.home.newAlbums.isEmpty {
                        albumSection(layout: mediaLayout)
                    }

                    if model.settings.isContentFeatureEnabled(.podcasts),
                       !model.home.podcastPrograms.isEmpty {
                        podcastProgramSection(layout: mediaLayout)
                    }

                    if case .failed(let message) = model.home.phase {
                        ContentUnavailableView(
                            "ui.error.home.load_failed",
                            systemImage: "wifi.exclamationmark",
                            description: Text(message)
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    }
                }
                .padding(.horizontal, Metrics.horizontalPadding)
                .padding(.top, 22)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle("")
        .task { await model.home.load() }
    }

    @ViewBuilder
    private func heroSection(
        layout: Metrics.ShelfLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(title: L10n.string("ui.home.section.recommended_playlists"))

            if model.home.recommendedPlaylists.isEmpty {
                if model.home.phase == .loading {
                    Color.clear
                    .frame(height: 270)
                }
            } else {
                DesktopHomePagingShelf(
                    items: Array(model.home.recommendedPlaylists.prefix(7)),
                    cardWidth: layout.cardWidth,
                    spacing: Metrics.heroSpacing,
                    visibleItemCount: layout.visibleItemCount
                ) { playlist in
                    DesktopHeroCard(
                        title: playlist.name,
                        subtitle: playlist.creator?.nickname,
                        eyebrow: playlist.copywriter ?? L10n.string("ui.home.section.tailored"),
                        artworkURL: playlist.artworkURL,
                        playCount: playlist.playCount,
                        showsPlayCount: model.settings.showPlayCount
                    ) {
                        model.ui.navigate(to: .playlist(playlist.id))
                    }
                }
            }
        }
    }

    private var recentSongs: [Song] {
        model.library.recentSongs.isEmpty
            ? model.home.newSongs
            : model.library.recentSongs
    }

    private func songCardSection(
        title: String,
        songs: [Song],
        layout: Metrics.ShelfLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(title: title)
            DesktopHomePagingShelf(
                items: songs,
                cardWidth: layout.cardWidth,
                spacing: Metrics.mediaSpacing,
                visibleItemCount: layout.visibleItemCount,
            ) { song in
                DesktopMediaCard(
                    title: song.name,
                    subtitle: song.artistText,
                    artworkURL: song.album?.artworkURL,
                    action: { model.ui.navigate(to: .song(song.id)) },
                    playAction: {
                        Task { await model.player.play(song, in: songs) }
                    }
                )
            }
        }
    }

    private func playlistSection(
        layout: Metrics.ShelfLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(
                title: L10n.string("ui.home.section.tailored"),
                trailingTitle: L10n.string("ui.common.view_all")
            ) {
                model.ui.selection = .playlists
            }
            DesktopHomePagingShelf(
                items: Array(model.home.recommendedPlaylists.prefix(12)),
                cardWidth: layout.cardWidth,
                spacing: Metrics.mediaSpacing,
                visibleItemCount: layout.visibleItemCount,
            ) { playlist in
                DesktopMediaCard(
                    title: playlist.name,
                    subtitle: playlist.creator?.nickname ?? playlist.copywriter,
                    artworkURL: playlist.artworkURL,
                    playCount: playlist.playCount,
                    showsPlayCount: model.settings.showPlayCount,
                    action: { model.ui.navigate(to: .playlist(playlist.id)) },
                    playAction: { play(playlist) }
                )
            }
        }
    }

    private func albumSection(
        layout: Metrics.ShelfLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(
                title: L10n.string("ui.albums.new.title"),
                trailingTitle: L10n.string("ui.common.view_all")
            ) {
                model.ui.selection = .discovery
            }
            DesktopHomePagingShelf(
                items: Array(model.home.newAlbums.prefix(12)),
                cardWidth: layout.cardWidth,
                spacing: Metrics.mediaSpacing,
                visibleItemCount: layout.visibleItemCount,
            ) { album in
                DesktopMediaCard(
                    title: album.name,
                    subtitle: album.artistText,
                    artworkURL: album.artworkURL,
                    action: { model.ui.navigate(to: .album(album.id)) },
                    playAction: { play(album) }
                )
            }
        }
    }

    private func podcastProgramSection(
        layout: Metrics.ShelfLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(
                title: L10n.string("ui.home.section.podcast_recommendations"),
                trailingTitle: L10n.string("ui.navigation.podcasts")
            ) {
                model.ui.selection = .radio
            }
            DesktopHomePagingShelf(
                items: Array(model.home.podcastPrograms.prefix(8)),
                cardWidth: layout.cardWidth,
                spacing: Metrics.mediaSpacing,
                visibleItemCount: layout.visibleItemCount,
            ) { program in
                DesktopMediaCard(
                    title: program.name,
                    subtitle: program.radio.name,
                    artworkURL: program.artworkURL,
                    action: { model.ui.navigate(to: .podcast(program.radio.id)) },
                    playAction: program.playbackSong.map { song in
                        { Task { await model.player.play(song) } }
                    }
                )
            }
        }
    }

    private func play(_ playlist: Playlist) {
        Task {
            guard let detail = try? await model.api.playlist(
                id: playlist.id,
                trackLimit: nil
            ) else { return }
            await model.player.playAll(detail.tracks, sourceID: detail.id)
        }
    }

    private func play(_ album: Album) {
        Task {
            guard let detail = try? await model.api.album(id: album.id) else { return }
            await model.player.playAll(detail.1, sourceID: album.id)
        }
    }
}
