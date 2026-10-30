import SwiftUI

struct NowPlayingTabletPanels: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(AppSettings.self) private var settings

    let pageTransition: NowPlayingTransitionCoordinator
    let song: Song
    let lyrics: [LyricLine]
    let lyricError: String?
    let highlightedLyricID: LyricLine.ID?
    let artworkNamespace: Namespace.ID
    let focusAnchorOffset: CGFloat
    let onLyricsContentPrepared: () -> Void

    private var page: NowPlayingPage { pageTransition.page }
    private var motion: NowPlayingMotionSpec.PageMotion { NowPlayingPageTransition.motion }

    var body: some View {
        ZStack {
            NowPlayingQueuePage(
                song: song,
                presentation: .tablet,
                artworkNamespace: artworkNamespace,
                usesArtworkTransition: false,
                showsSongHeader: false
            )
            .nowPlayingQueuePagePresentation(
                visualState: motion.residentQueueState(
                    selectedPage: page,
                    transition: pageTransition.transition
                ),
                opacityTransition: pageTransition.queueOpacityTransition,
                spatialTransition: pageTransition.queueSpatialTransition,
                opacitySpec: pageTransition.queueOpacityTransition.targetProgress >= 1
                    ? motion.queueOpacityPresentation
                    : motion.queueOpacityDismissal,
                presentationScale: motion.queuePresentationScale,
                reducesMotion: accessibilityReduceMotion
            )
            .allowsHitTesting(page == .queue)
            .accessibilityHidden(page != .queue)

            if settings.lyricsStyle == .appleMusic {
                lyricsPage
                    .nowPlayingLyricsPagePresentation(
                        visualState: motion.residentLyricsState(
                            selectedPage: page,
                            transition: pageTransition.transition,
                            isEntrancePresented: pageTransition.isLyricsEntrancePresented
                        ),
                        opacityTransition: pageTransition.lyricsOpacityTransition,
                        spatialTransition: pageTransition.lyricsSpatialTransition,
                        opacitySpec: pageTransition.lyricsOpacityTransition.targetProgress >= 1
                            ? motion.lyricsOpacityPresentation
                            : motion.lyricsOpacityDismissal,
                        presentationScale: motion.lyricsPresentationScale,
                        reducesMotion: accessibilityReduceMotion
                    )
                    .allowsHitTesting(page == .lyrics)
                    .accessibilityHidden(page != .lyrics)
            } else if page == .lyrics {
                lyricsPage
                    .transition(.opacity)
            }
        }
        .clipped()
    }

    private var lyricsPage: some View {
        NowPlayingLyricsPage(
            song: song,
            lyrics: lyrics,
            errorMessage: lyricError,
            highlightedLyricID: highlightedLyricID,
            isActive: page == .lyrics,
            presentation: .tablet,
            artworkNamespace: artworkNamespace,
            usesArtworkTransition: false,
            showsSongHeader: false,
            focusAnchorOffset: focusAnchorOffset,
            onInitialFocusPrepared: onLyricsContentPrepared
        )
        .id(song.id)
        .padding(.top, NowPlayingTabletLayout.lyricsTopPadding)
    }
}
