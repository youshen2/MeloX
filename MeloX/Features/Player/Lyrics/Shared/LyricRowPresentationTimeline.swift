import SwiftUI

/// Samples movement and focus at the same display timestamp. Keeping this
/// container mounted also preserves the text's in-flight scale and layout.
struct LyricRowPresentationTimeline<Content: View>: View {
    @Environment(\.effectiveLyricsRefreshRate)
    private var effectiveLyricsRefreshRate

    let lyricID: LyricLine.ID
    let focusedLyricID: LyricLine.ID?
    let movementPhase: LyricMovementPhase
    let focusTransition: LyricFocusColorTransition?
    let isActive: Bool
    @ViewBuilder let content: (CGFloat, LyricFocusVisualProgress) -> Content

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: effectiveLyricsRefreshRate.minimumInterval,
                paused: !requiresContinuousUpdates || !isActive
            )
        ) { context in
            content(
                movementPhase.presentation(at: context.date).offset,
                focusProgress(at: context.date)
            )
        }
    }

    private var requiresContinuousUpdates: Bool {
        movementPhase.isAnimated || focusTransition?.includes(lyricID) == true
    }

    private func focusProgress(at date: Date) -> LyricFocusVisualProgress {
        guard let focusTransition, focusTransition.includes(lyricID) else {
            let value: CGFloat = lyricID == focusedLyricID ? 1 : 0
            return LyricFocusVisualProgress(color: value, blur: value)
        }
        return LyricFocusVisualProgress(
            color: focusTransition.colorProgress(for: lyricID, at: date),
            blur: focusTransition.blurProgress(for: lyricID, at: date)
        )
    }
}
