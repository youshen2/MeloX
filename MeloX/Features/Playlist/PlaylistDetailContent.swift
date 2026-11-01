import SwiftUI
import UIKit

struct PlaylistDetailContent: View {
    let playlist: Playlist
    let toplistSummary: Playlist?
    let palette: ArtworkDetailPalette
    let blurredBackdropImage: CGImage?
    let searchQuery: String
    let isLoading: Bool
    let failureMessage: String?
    let hasMoreTracks: Bool
    let loadedTrackOffset: Int
    let isLoadingMoreTracks: Bool
    let loadMoreTracksError: String?
    let isPreparingPlayback: Bool
    let downloadCoordinator: MusicCollectionDownloadCoordinator?
    let onRetry: () -> Void
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    let onPlayAll: (Bool) async -> Void
    var onRemoveSong: ((Song) -> Void)?
    var highlightedSongID: Int?

    @Environment(LibraryStore.self) private var library
    private var usesToplistLayout: Bool {
        toplistSummary != nil || playlist.isOfficialToplist
    }

    private var artworkURL: URL? {
        playlist.artworkURL ?? toplistSummary?.artworkURL
    }

    var body: some View {
        MusicCollectionDetailLayoutView(
            palette: palette,
            blurredBackdropImage: blurredBackdropImage,
            extendsPhoneHeaderUnderToolbar: usesToplistLayout,
            onRefresh: onRefresh
        ) {
            if usesToplistLayout {
                ToplistDetailHero(
                    playlist: playlist,
                    summary: toplistSummary,
                    artworkURL: artworkURL,
                    palette: palette,
                    isPreparingPlayback: isPreparingPlayback,
                    onPlayAll: onPlayAll
                )
            } else {
                StandardMusicCollectionDetailHero(
                    artworkURL: playlist.artworkURL,
                    title: playlist.name,
                    subtitle: playlist.creator?.nickname ?? L10n.string("ui.service.netease_cloud_music"),
                    metadataText: standardMetadata,
                    descriptionText: playlist.nonemptyDescription,
                    tracks: playlist.tracks,
                    sourceID: playlist.id,
                    isSaved: library.contains(playlist: playlist),
                    isPreparingPlayback: isPreparingPlayback,
                    onToggleSaved: {
                        library.toggle(playlist: playlist)
                    },
                    onPlayAll: onPlayAll
                )
            }

        } tracks: {
            MusicCollectionTrackContent(
                tracks: filteredTracks,
                sourceID: playlist.id,
                showsArtwork: usesToplistLayout || UIDevice.current.userInterfaceIdiom == .pad,
                loadingTitle: usesToplistLayout
                    ? L10n.string("ui.toplists.loading")
                    : L10n.string("ui.playlists.loading"),
                isLoading: isLoading,
                failureMessage: failureMessage,
                hasMoreTracks: hasMoreTracks,
                loadedTrackOffset: loadedTrackOffset,
                isLoadingMoreTracks: isLoadingMoreTracks,
                loadMoreTracksError: loadMoreTracksError,
                downloadSelection: downloadCoordinator,
                onRetry: onRetry,
                onLoadMore: onLoadMore,
                onRemoveSong: onRemoveSong,
                highlightedSongID: highlightedSongID
            )
        }
        .foregroundStyle(.primary)
    }

    private var standardMetadata: String {
        let count = playlist.trackCount > 0
            ? playlist.trackCount
            : playlist.tracks.count
        return L10n.format(
            "ui.playlists.metadata",
            count,
            playlist.playCount.compactPlayCount
        )
    }

    private var filteredTracks: [Song] {
        filterMusicCollectionTracks(playlist.tracks, query: searchQuery)
    }
}

struct MusicCollectionTrackContent: View {
    let tracks: [Song]
    let sourceID: Int
    let showsArtwork: Bool
    let loadingTitle: String
    let isLoading: Bool
    let failureMessage: String?
    var hasMoreTracks = false
    var loadedTrackOffset = 0
    var isLoadingMoreTracks = false
    var loadMoreTracksError: String?
    var downloadSelection: MusicCollectionDownloadCoordinator? = nil
    let onRetry: () -> Void
    var onLoadMore: () async -> Void = {}
    var onRemoveSong: ((Song) -> Void)?
    var highlightedSongID: Int?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(loadingTitle)
                    .tint(.primary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else if let failureMessage {
                ConnectionUnavailableView(
                    message: failureMessage,
                    retry: onRetry
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                VStack(spacing: 0) {
                    PlaylistTrackList(
                        tracks: tracks,
                        sourceID: sourceID,
                        showsArtwork: showsArtwork,
                        onRemoveSong: onRemoveSong,
                        downloadSelection: downloadSelection,
                        highlightedSongID: highlightedSongID
                    )

                    if hasMoreTracks {
                        MusicCollectionPaginationFooter(
                            isLoading: isLoadingMoreTracks,
                            failureMessage: loadMoreTracksError,
                            loadToken: loadedTrackOffset,
                            action: onLoadMore
                        )
                    }
                }
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: failureMessage)
    }
}

struct StandardMusicCollectionDetailHero: View {
    @Environment(\.musicCollectionDetailMetrics) private var detailMetrics
    let artworkURL: URL?
    let title: String
    let subtitle: String
    let metadataText: String
    var descriptionText: String? = nil
    let tracks: [Song]
    let sourceID: Int
    let isSaved: Bool
    var isPreparingPlayback = false
    let onToggleSaved: () -> Void
    var onPlayAll: ((Bool) async -> Void)? = nil

    @ViewBuilder
    var body: some View {
        if detailMetrics.usesAdaptiveHeader {
            AdaptiveMusicCollectionHero(
                artworkURL: artworkURL,
                title: title,
                subtitle: subtitle,
                metadataText: metadataText,
                descriptionText: descriptionText,
                tracks: tracks,
                sourceID: sourceID,
                isSaved: isSaved,
                isPreparingPlayback: isPreparingPlayback,
                onToggleSaved: onToggleSaved,
                onPlayAll: onPlayAll
            )
        } else {
            standardHero
        }
    }

    private var standardHero: some View {
        VStack(spacing: 0) {
            ArtworkImage(url: artworkURL, cornerRadius: 12)
                .containerRelativeFrame(.horizontal) { width, _ in
                    min(width * 0.68, 300)
                }
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)

            Text(title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 24)
                .padding(.horizontal, 24)

            Text(subtitle)
                .font(.title3)
                .lineLimit(1)
                .padding(.top, 8)

            Text(metadataText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 7)

            MusicCollectionPrimaryActions(
                tracks: tracks,
                sourceID: sourceID,
                isSaved: isSaved,
                isPreparingPlayback: isPreparingPlayback,
                onToggleSaved: onToggleSaved,
                onPlayAll: onPlayAll
            )
                .padding(.top, 17)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.bottom, 22)
    }
}

private struct ToplistDetailHero: View {
    let playlist: Playlist
    let summary: Playlist?
    let artworkURL: URL?
    let palette: ArtworkDetailPalette
    let isPreparingPlayback: Bool
    let onPlayAll: (Bool) async -> Void

    @Environment(LibraryStore.self) private var library
    @Environment(\.musicCollectionDetailMetrics) private var detailMetrics

    @ViewBuilder
    var body: some View {
        if detailMetrics.usesAdaptiveHeader {
            AdaptiveMusicCollectionHero(
                artworkURL: artworkURL,
                title: playlist.name,
                subtitle: creatorName,
                metadataText: [updateText, L10n.format("ui.common.song_count", playlist.trackCount)].compactMap { $0 }.joined(separator: " · "),
                descriptionText: descriptionText,
                tracks: playlist.tracks,
                sourceID: playlist.id,
                isSaved: library.contains(playlist: playlist),
                isPreparingPlayback: isPreparingPlayback,
                onToggleSaved: { library.toggle(playlist: playlist) },
                onPlayAll: onPlayAll
            )
        } else {
            standardHero
        }
    }

    private var standardHero: some View {
        VStack(spacing: 0) {
            ArtworkImage(url: artworkURL, cornerRadius: 0)
                .containerRelativeFrame(.horizontal)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            .clear,
                            palette.backgroundColor.opacity(0.34),
                            palette.backgroundColor,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 126)
                }

            Text(playlist.name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)
                .padding(.top, 17)

            Text(creatorName)
                .font(.title3)
                .lineLimit(1)
                .padding(.top, 6)

            if let updateText {
                Text(updateText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            MusicCollectionPrimaryActions(
                tracks: playlist.tracks,
                sourceID: playlist.id,
                isSaved: library.contains(playlist: playlist),
                isPreparingPlayback: isPreparingPlayback,
                onToggleSaved: {
                    library.toggle(playlist: playlist)
                },
                onPlayAll: onPlayAll
            )
                .padding(.top, 17)

            if let descriptionText {
                ExpandablePlaylistDescription(description: descriptionText)
                    .padding(.top, 27)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
    }

    private var creatorName: String {
        playlist.creator?.nickname
            ?? summary?.creator?.nickname
            ?? L10n.string("ui.service.netease_cloud_music")
    }

    private var updateText: String? {
        playlist.updateFrequency?.nonempty
            ?? summary?.updateFrequency?.nonempty
    }

    private var descriptionText: String? {
        playlist.nonemptyDescription
            ?? summary?.nonemptyDescription
            ?? playlist.copywriter?.nonempty
            ?? summary?.copywriter?.nonempty
    }
}

struct MusicCollectionPrimaryActions: View {
    let tracks: [Song]
    let sourceID: Int
    let isSaved: Bool
    let isPreparingPlayback: Bool
    let onToggleSaved: () -> Void
    let onPlayAll: ((Bool) async -> Void)?

    @Environment(PlayerStore.self) private var player
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.musicCollectionDetailMetrics) private var detailMetrics

    var body: some View {
        GlassEffectContainer(spacing: detailMetrics.usesAdaptiveHeader ? 10 : 14) {
            HStack(spacing: detailMetrics.usesAdaptiveHeader ? 10 : 14) {
                Button {
                    Task {
                        if let onPlayAll {
                            await onPlayAll(true)
                        } else {
                            await player.playAll(
                                tracks.shuffled(),
                                sourceID: sourceID
                            )
                        }
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title2.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(detailMetrics.usesAdaptiveHeader ? .regular : .large)
                .disabled(tracks.isEmpty || isPreparingPlayback)
                .accessibilityLabel("ui.player.shuffle")

                Button {
                    Task {
                        if let onPlayAll {
                            await onPlayAll(false)
                        } else {
                            await player.playAll(
                                tracks,
                                sourceID: sourceID
                            )
                        }
                    }
                } label: {
                    Group {
                        if isPreparingPlayback {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("ui.downloads.preparing")
                            }
                        } else {
                            Label("ui.common.play", systemImage: "play.fill")
                        }
                    }
                    .font(detailMetrics.usesAdaptiveHeader ? .body.weight(.semibold) : .title3.weight(.bold))
                    .frame(minWidth: detailMetrics.usesAdaptiveHeader ? 76 : 116, minHeight: 30)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(detailMetrics.usesAdaptiveHeader ? .regular : .large)
                .tint(primaryActionBackground)
                .foregroundStyle(primaryActionForeground)
                .disabled(tracks.isEmpty || isPreparingPlayback)

                Button(action: onToggleSaved) {
                    Image(
                        systemName: isSaved ? "checkmark" : "plus"
                    )
                    .font(.title2.weight(.semibold))
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(detailMetrics.usesAdaptiveHeader ? .regular : .large)
                .accessibilityLabel(
                    isSaved
                        ? L10n.string("ui.common.unfavorite")
                        : L10n.string("ui.common.favorite")
                )
            }
        }
    }

    private var primaryActionBackground: Color {
        if detailMetrics.usesAdaptiveHeader { return .red }
        return colorScheme == .dark ? .white : .black
    }

    private var primaryActionForeground: Color {
        if detailMetrics.usesAdaptiveHeader { return .white }
        return colorScheme == .dark ? .black : .white
    }
}

struct ExpandablePlaylistDescription: View {
    let description: String
    var horizontalPadding: CGFloat = 20

    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            Text(
                "\(description)  \(Text(isExpanded ? L10n.string("ui.common.collapse") : L10n.string("ui.common.more")).bold())"
            )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(isExpanded ? nil : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, horizontalPadding)
        .accessibilityLabel(
            isExpanded
                ? L10n.string("ui.playlists.collapse_description")
                : L10n.string("ui.playlists.expand_description")
        )
    }
}

struct MusicCollectionArtworkBackdrop: View {
    let blurredArtworkImage: CGImage?
    let palette: ArtworkDetailPalette

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                palette.backgroundColor

                if let blurredArtworkImage {
                    Image(decorative: blurredArtworkImage, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .opacity(0.22)
                        .transition(.opacity)
                }

                LinearGradient(
                    colors: backdropOverlayColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var backdropOverlayColors: [Color] {
        if palette.prefersDarkAppearance {
            return [
                .black.opacity(0.08),
                .black.opacity(0.24),
                .black.opacity(0.40),
            ]
        }
        return [
            .white.opacity(0.06),
            .white.opacity(0.16),
            .white.opacity(0.30),
        ]
    }
}

private extension Playlist {
    var nonemptyDescription: String? {
        playlistDescription?.nonempty
    }
}

private extension String {
    var nonempty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension Int {
    var compactPlayCount: String {
        formatted(
            .number
                .notation(.compactName)
                .locale(L10n.locale)
        )
    }
}
