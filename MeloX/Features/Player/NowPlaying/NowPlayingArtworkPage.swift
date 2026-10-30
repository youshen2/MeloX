import SwiftUI

struct NowPlayingArtworkPage: View {
    static let pausedArtworkScale: CGFloat = 0.74

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let song: Song
    let artworkNamespace: Namespace.ID
    let usesArtworkTransition: Bool
    let showsArtwork: Bool
    let onArtworkFrameChange: (CGRect) -> Void

    @State private var artworkBounceScale: CGFloat = 1

    init(
        song: Song,
        artworkNamespace: Namespace.ID,
        usesArtworkTransition: Bool = true,
        showsArtwork: Bool = true,
        onArtworkFrameChange:
            @escaping (CGRect) -> Void = { _ in }
    ) {
        self.song = song
        self.artworkNamespace = artworkNamespace
        self.usesArtworkTransition = usesArtworkTransition
        self.showsArtwork = showsArtwork
        self.onArtworkFrameChange = onArtworkFrameChange
    }

    private var isArtworkExpanded: Bool {
        player.isPlaying || !settings.shrinksPausedArtwork
    }

    var body: some View {
        GeometryReader { proxy in
            let artworkSize = max(
                1,
                min(
                    proxy.size.width + 16,
                    max(
                        170,
                        proxy.size.height
                            - NowPlayingBottomControls.coreHeight
                            - 92
                    )
                )
            )
            let displayedArtworkSize =
                artworkSize
                * (
                    isArtworkExpanded
                        ? 1
                        : Self.pausedArtworkScale
                )

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                ZStack {
                    if showsArtwork {
                        ArtworkImage(
                            url: song.album?.artworkURL,
                            cornerRadius: 12
                        )
                        .frame(
                            width: displayedArtworkSize,
                            height: displayedArtworkSize
                        )
                        .scaleEffect(artworkBounceScale)
                        .nowPlayingArtworkTransition(
                            id: song.id,
                            in: artworkNamespace,
                            isEnabled: usesArtworkTransition,
                            isSource: true
                        )
                        .shadow(
                            color: .black.opacity(
                                player.isPlaying ? 0.34 : 0.18
                            ),
                            radius: player.isPlaying ? 26 : 14,
                            y: player.isPlaying ? 15 : 8
                        )
                    } else {
                        Color.clear
                            .frame(
                                width: artworkSize,
                                height: artworkSize
                            )
                            .onGeometryChange(
                                for: CGRect.self
                            ) { geometry in
                                geometry.frame(
                                    in: .named(
                                        NowPlayingPortraitCoordinateSpace
                                            .name
                                    )
                                )
                            } action: { newFrame in
                                onArtworkFrameChange(newFrame)
                            }
                    }
                }
                .frame(width: artworkSize, height: artworkSize)
                .animation(
                    accessibilityReduceMotion
                        ? nil
                        : .smooth(duration: 0.48),
                    value: isArtworkExpanded
                )
                .animation(
                    accessibilityReduceMotion
                        ? nil
                        : .easeInOut(duration: 0.3),
                    value: player.isPlaying
                )
                .accessibilityElement()
                .accessibilityLabel(L10n.format("ui.song.artwork_accessibility", song.name))
                .accessibilityHidden(!showsArtwork)
                .task(id: player.isPlaying) {
                    await animateArtworkBounce(
                        whenPlaying: player.isPlaying
                    )
                }

                Spacer(minLength: 22)

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(song.name)
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)
                                .layoutPriority(1)

                            HeartModeNowPlayingBadge()
                            ListenTogetherNowPlayingBadge()
                        }

                        Text(song.artistText)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    NowPlayingSongActions(
                        song: song,
                        showsFavoriteButton: false
                    )
                }
            }
            .padding(.bottom, NowPlayingBottomControls.coreHeight)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func animateArtworkBounce(
        whenPlaying isPlaying: Bool
    ) async {
        artworkBounceScale = 1
        guard showsArtwork,
              isPlaying,
              !accessibilityReduceMotion else {
            return
        }

        await Task.yield()
        withAnimation(.easeOut(duration: 0.17)) {
            artworkBounceScale = 1.055
        }

        do {
            try await Task.sleep(for: .milliseconds(170))
        } catch {
            return
        }

        withAnimation(.spring(duration: 0.42, bounce: 0.24)) {
            artworkBounceScale = 1
        }
    }
}
