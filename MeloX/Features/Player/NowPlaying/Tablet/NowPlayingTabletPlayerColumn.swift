import SwiftUI

struct NowPlayingTabletPlayerColumn: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let song: Song
    let layout: NowPlayingTabletLayout

    private var isArtworkExpanded: Bool {
        player.isPlaying || !settings.shrinksPausedArtwork
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NowPlayingPortraitArtwork(song: song, isArtworkPage: true)
                .frame(width: layout.artworkSize, height: layout.artworkSize)
                .scaleEffect(isArtworkExpanded ? 1 / NowPlayingArtworkPage.pausedArtworkScale : 1)
                .frame(maxWidth: .infinity)
                .padding(.top, layout.artworkTopInset)
                .animation(
                    accessibilityReduceMotion ? nil : .smooth(duration: 0.48),
                    value: isArtworkExpanded
                )

            NowPlayingTabletMetadata(song: song)
                .padding(.top, layout.metadataTopInset)

            NowPlayingProgressControl(song: song)
                .padding(.top, 23 * layout.elementScale)

            NowPlayingTransportControls(presentation: .tablet)
                .padding(.top, 22 * layout.elementScale)

            NowPlayingVolumeControl()
                .padding(.top, 12)
        }
        .padding(.bottom, 20)
        .foregroundStyle(.white)
    }
}

private struct NowPlayingTabletMetadata: View {
    let song: Song

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(song.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(
                    [song.artistText, song.album?.name]
                        .compactMap { $0 }
                        .joined(separator: L10n.string("ui.common.title_detail_separator"))
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)

                HStack(spacing: 8) {
                    HeartModeNowPlayingBadge()
                    ListenTogetherNowPlayingBadge()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            NowPlayingSongActions(song: song)
        }
    }
}
