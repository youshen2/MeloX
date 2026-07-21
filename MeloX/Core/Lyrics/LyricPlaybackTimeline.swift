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
        guard let highlightedLyricID,
              let index = lyrics.firstIndex(where: { $0.id == highlightedLyricID }) else {
            return 0.34
        }

        let followingIndex = lyrics.index(after: index)
        let availableDuration = followingIndex < lyrics.endIndex
            ? lyrics[followingIndex].time - lyrics[index].time
            : lyrics[index].duration
        guard let availableDuration,
              availableDuration.isFinite,
              availableDuration > 0 else {
            return 0.34
        }

        return min(max(availableDuration * 0.35, 0.05), 0.34)
    }
}
