import SwiftUI

/// Drives a lyric row's position and focus presentation from one display
/// clock. Music's LyricsX renderer owns one display-link-backed animator set;
/// keeping both values on one SwiftUI timeline avoids nested per-frame updates
/// of the full lyric text subtree.
struct LyricRowPresentationTimeline<Content: View>: View {
    @Environment(\.lyricsRenderingIsActive)
    private var lyricsRenderingIsActive
    @Environment(\.effectiveLyricsRefreshRate)
    private var effectiveLyricsRefreshRate

    let lyricID: LyricLine.ID
    let focusedLyricID: LyricLine.ID?
    let movementPhase: LyricMovementPhase
    let focusTransition: LyricFocusColorTransition?
    @ViewBuilder let content: (
        CGFloat,
        LyricFocusVisualProgress
    ) -> Content

    var body: some View {
        // Pausing the existing timeline preserves the text's scale, hover,
        // and annotation animation state when a transition starts or settles.
        TimelineView(
            .animation(
                minimumInterval: effectiveLyricsRefreshRate.minimumInterval,
                paused: !requiresContinuousUpdates || !lyricsRenderingIsActive
            )
        ) { context in
            content(
                movementPhase.presentation(at: context.date).offset,
                focusProgress(at: context.date)
            )
        }
    }

    private var requiresContinuousUpdates: Bool {
        movementPhase.isAnimated
            || focusTransition?.includes(lyricID) == true
    }

    private var stationaryFocusProgress: LyricFocusVisualProgress {
        let value: CGFloat = lyricID == focusedLyricID ? 1 : 0
        return LyricFocusVisualProgress(color: value, blur: value)
    }

    private func focusProgress(at date: Date) -> LyricFocusVisualProgress {
        guard let focusTransition,
              focusTransition.includes(lyricID) else {
            return stationaryFocusProgress
        }
        return LyricFocusVisualProgress(
            color: focusTransition.colorProgress(for: lyricID, at: date),
            blur: focusTransition.blurProgress(for: lyricID, at: date)
        )
    }
}
