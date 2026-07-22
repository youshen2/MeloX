import Foundation

struct LyricPlaybackPosition: Equatable {
    let highlightedLyricID: LyricLine.ID?
    let nextTransitionTime: TimeInterval?
}

enum LyricPlaybackTimeline {
    static func position(
        at playbackTime: TimeInterval,
        in lyrics: [LyricLine]
    ) -> LyricPlaybackPosition {
        guard !lyrics.isEmpty else {
            return LyricPlaybackPosition(
                highlightedLyricID: nil,
                nextTransitionTime: nil
            )
        }

        var lowerBound = lyrics.startIndex
        var upperBound = lyrics.endIndex
        while lowerBound < upperBound {
            let middleIndex = lowerBound + (upperBound - lowerBound) / 2
            if lyrics[middleIndex].time <= playbackTime {
                lowerBound = middleIndex + 1
            } else {
                upperBound = middleIndex
            }
        }

        let highlightedLyricID = lowerBound > lyrics.startIndex
            ? lyrics[lyrics.index(before: lowerBound)].id
            : nil
        let nextTransitionTime = lowerBound < lyrics.endIndex
            ? lyrics[lowerBound].time
            : nil
        return LyricPlaybackPosition(
            highlightedLyricID: highlightedLyricID,
            nextTransitionTime: nextTransitionTime
        )
    }

    static func focusAnimationDuration(
        for highlightedLyricID: LyricLine.ID?,
        in lyrics: [LyricLine]
    ) -> TimeInterval {
        guard let availableDuration = availableFocusDuration(
            for: highlightedLyricID,
            in: lyrics
        ) else {
            return 0.34
        }

        return min(max(availableDuration * 0.35, 0.05), 0.34)
    }

    static func focusCascadeAnimationDuration(
        baseDuration: TimeInterval,
        bounceEnabled: Bool
    ) -> TimeInterval {
        let duration = max(baseDuration, 0)
        return bounceEnabled ? max(duration, 0.56) : duration
    }

    static func focusCascadeDelay(
        visibleOrder: Int,
        visibleLineCount: Int,
        preferredDelayPerLine: TimeInterval,
        highlightedLyricID: LyricLine.ID?,
        in lyrics: [LyricLine]
    ) -> TimeInterval {
        guard visibleOrder > 0,
              visibleLineCount > 1,
              preferredDelayPerLine > 0 else {
            return 0
        }

        let lastVisibleOrder = visibleLineCount - 1
        let maximumTotalDelay = availableFocusDuration(
            for: highlightedLyricID,
            in: lyrics
        ).map { min($0 * 0.45, 0.8) } ?? 0.4
        let effectiveDelayPerLine = min(
            preferredDelayPerLine,
            maximumTotalDelay / Double(lastVisibleOrder)
        )
        return Double(min(visibleOrder, lastVisibleOrder))
            * effectiveDelayPerLine
    }

    static func shouldUseFocusCascade(
        visibleLineCount: Int,
        preferredDelayPerLine: TimeInterval,
        focusColorLeadTime: TimeInterval,
        animationDuration: TimeInterval,
        remainingDuration: TimeInterval?,
        highlightedLyricID: LyricLine.ID?,
        in lyrics: [LyricLine]
    ) -> Bool {
        guard visibleLineCount > 1,
              preferredDelayPerLine > 0 else {
            return false
        }
        guard let remainingDuration else {
            return true
        }
        let finalLaunchDelay = focusCascadeDelay(
            visibleOrder: visibleLineCount - 1,
            visibleLineCount: visibleLineCount,
            preferredDelayPerLine: preferredDelayPerLine,
            highlightedLyricID: highlightedLyricID,
            in: lyrics
        )
        let schedulingMargin: TimeInterval = 1.0 / 60.0
        return max(focusColorLeadTime, 0)
            + finalLaunchDelay
            + animationDuration
            + schedulingMargin
            < remainingDuration
    }

    static func remainingFocusDuration(
        for highlightedLyricID: LyricLine.ID?,
        at playbackTime: TimeInterval,
        in lyrics: [LyricLine]
    ) -> TimeInterval? {
        guard let highlightedLyricID,
              playbackTime.isFinite,
              let index = lyrics.firstIndex(where: { $0.id == highlightedLyricID }) else {
            return nil
        }
        let followingIndex = lyrics.index(after: index)
        guard followingIndex < lyrics.endIndex else { return nil }

        let remainingDuration = lyrics[followingIndex].time - playbackTime
        guard remainingDuration.isFinite else { return nil }
        return max(remainingDuration, 0)
    }

    private static func availableFocusDuration(
        for highlightedLyricID: LyricLine.ID?,
        in lyrics: [LyricLine]
    ) -> TimeInterval? {
        guard let highlightedLyricID,
              let index = lyrics.firstIndex(where: { $0.id == highlightedLyricID }) else {
            return nil
        }

        let followingIndex = lyrics.index(after: index)
        let availableDuration = followingIndex < lyrics.endIndex
            ? lyrics[followingIndex].time - lyrics[index].time
            : lyrics[index].duration
        guard let availableDuration,
              availableDuration.isFinite,
              availableDuration > 0 else {
            return nil
        }
        return availableDuration
    }
}
