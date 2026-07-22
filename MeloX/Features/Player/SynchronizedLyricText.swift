import SwiftUI

enum SynchronizedLyricTextAlignment: Equatable {
    case leading
    case center

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        }
    }

    var scaleAnchor: UnitPoint {
        switch self {
        case .leading: .leading
        case .center: .center
        }
    }
}

struct SynchronizedLyricText: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.effectiveLyricsRefreshRate) private var effectiveLyricsRefreshRate
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let line: LyricLine
    let isPlaybackLine: Bool
    let usesPseudoTiming: Bool
    let fontSize: CGFloat
    let alignment: SynchronizedLyricTextAlignment
    let fontScale: CGFloat
    let primaryColor: Color
    let showsTranslation: Bool
    let visualScale: CGFloat
    let layoutWidth: CGFloat?
    let playbackScaleRange: ClosedRange<CGFloat>?
    let playbackScaleStartDelay: TimeInterval
    private let synchronizedText: Text
    private let pseudoSynchronizedText: Text
    private let hasPseudoSyllables: Bool
    private let timedPlaybackRange: ClosedRange<TimeInterval>?

    init(
        line: LyricLine,
        isPlaybackLine: Bool,
        usesPseudoTiming: Bool,
        fontSize: CGFloat,
        alignment: SynchronizedLyricTextAlignment = .leading,
        fontScale: CGFloat = 1,
        primaryColor: Color = .white,
        showsTranslation: Bool = true,
        visualScale: CGFloat = 1,
        layoutWidth: CGFloat? = nil,
        playbackScaleRange: ClosedRange<CGFloat>? = nil,
        playbackScaleStartDelay: TimeInterval = 0
    ) {
        self.line = line
        self.isPlaybackLine = isPlaybackLine
        self.usesPseudoTiming = usesPseudoTiming
        self.fontSize = fontSize
        self.alignment = alignment
        self.fontScale = fontScale
        self.primaryColor = primaryColor
        self.showsTranslation = showsTranslation
        self.visualScale = visualScale
        self.layoutWidth = layoutWidth
        self.playbackScaleRange = playbackScaleRange
        self.playbackScaleStartDelay = playbackScaleStartDelay

        let pseudoSyllables = usesPseudoTiming
            ? line.makePseudoSyllables()
            : []
        let activeSyllables = usesPseudoTiming
            ? pseudoSyllables
            : line.syllables
        let timedLayoutWidth = layoutWidth.map {
            $0 / max(playbackScaleRange?.upperBound ?? 1, 1)
        }
        synchronizedText = TimedLyricTextBuilder.text(
            from: line.syllables,
            constrainedWidth: timedLayoutWidth,
            fontSize: fontSize
        )
        pseudoSynchronizedText = TimedLyricTextBuilder.text(
            from: pseudoSyllables,
            constrainedWidth: timedLayoutWidth,
            fontSize: fontSize
        )
        hasPseudoSyllables = !pseudoSyllables.isEmpty
        if let firstSyllable = activeSyllables.first,
           let lastSyllable = activeSyllables.last,
           lastSyllable.endTime > firstSyllable.startTime {
            timedPlaybackRange = firstSyllable.startTime...lastSyllable.endTime
        } else {
            timedPlaybackRange = nil
        }
    }

    var body: some View {
        VStack(alignment: alignment.horizontalAlignment, spacing: translationSpacing) {
            primaryLyric
                .animation(
                    accessibilityReduceMotion ? nil : .easeInOut(duration: 0.28),
                    value: usesTimedLyrics
                )

            if showsTranslation,
               settings.lyricsTranslationEnabled,
               let translation = line.translation {
                Text(verbatim: translation)
                    .font(
                        .system(
                            size: translationFontSize,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white.opacity(settings.lyricsTranslationOpacity))
            }
        }
        .multilineTextAlignment(alignment.textAlignment)
        .frame(width: layoutWidth, alignment: alignment.frameAlignment)
        .scaleEffect(visualScale, anchor: alignment.scaleAnchor)
        .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
    }

    @ViewBuilder
    private var primaryLyric: some View {
        if usesTimedLyrics {
            TimelineView(
                .animation(
                    minimumInterval: effectiveLyricsRefreshRate.minimumInterval,
                    paused: !player.isPlaying
                )
            ) { context in
                let playbackTime = player.estimatedProgress(at: context.date)
                    + settings.lyricsAdvanceTime

                activeSynchronizedText
                    .font(primaryFont)
                    .foregroundStyle(primaryColor)
                    .multilineTextAlignment(alignment.textAlignment)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .textRenderer(
                        LyricGlowTextRenderer(
                            playbackTime: playbackTime,
                            style: .init(
                                glowRadius: glowRadius,
                                glowOpacity: glowOpacity,
                                unplayedOpacity: 0.3,
                                maximumUnplayedBlurRadius: maximumUnplayedBlurRadius
                            ),
                            layoutConfiguration: .init(
                                width: timedLayoutWidth,
                                centersLines: alignment == .center
                            )
                        )
                    )
                    .frame(
                        width: timedLayoutWidth,
                        alignment: alignment.frameAlignment
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: alignment.frameAlignment
                    )
                    .scaleEffect(
                        playbackScale(at: playbackTime),
                        anchor: .center
                    )
            }
            .transition(.opacity)
        } else {
            Text(verbatim: line.text)
                .font(primaryFont)
                .foregroundStyle(primaryColor)
                .multilineTextAlignment(alignment.textAlignment)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    width: layoutWidth,
                    alignment: alignment.frameAlignment
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: alignment.frameAlignment
                )
                .transition(.opacity)
        }
    }

    private var usesTimedLyrics: Bool {
        guard isPlaybackLine else { return false }
        return (settings.lyricsWordByWord && line.isSyllableSynced)
            || (usesPseudoTiming && hasPseudoSyllables)
    }

    private var activeSynchronizedText: Text {
        usesPseudoTiming ? pseudoSynchronizedText : synchronizedText
    }

    private var primaryFont: Font {
        .system(size: fontSize, weight: .bold)
    }

    private var translationFontSize: CGFloat {
        max(
            CGFloat(settings.lyricsFontSize * settings.lyricsTranslationFontScale) * fontScale,
            13 * fontScale
        )
    }

    private var translationSpacing: CGFloat {
        showsTranslation
            && settings.lyricsTranslationEnabled
            && line.translation != nil
            ? 5
            : 0
    }

    private var glowRadius: CGFloat {
        guard settings.lyricsGlowEnabled else { return 0 }
        return CGFloat(
            Double(fontSize)
                * 0.34
                * settings.lyricsGlowIntensity
        )
    }

    private var glowOpacity: Double {
        guard settings.lyricsGlowEnabled else { return 0 }
        return min(settings.lyricsGlowIntensity * 0.9, 1)
    }

    private var maximumUnplayedBlurRadius: CGFloat {
        CGFloat(settings.lyricsBlurIntensity) * 0.55 * fontScale
    }

    private var timedLayoutWidth: CGFloat? {
        guard let layoutWidth,
              let maximumScale = playbackScaleRange?.upperBound else {
            return layoutWidth
        }
        return layoutWidth / max(maximumScale, 1)
    }

    private func playbackScale(at playbackTime: TimeInterval) -> CGFloat {
        guard !accessibilityReduceMotion,
              let playbackScaleRange,
              let timedPlaybackRange else {
            return 1
        }

        let glowTailDuration = settings.lyricsGlowEnabled
            ? LyricGlowTextRenderer.glowTailDuration
            : 0
        let playbackScaleEndTime = timedPlaybackRange.upperBound
            + glowTailDuration
        let fullDuration = playbackScaleEndTime
            - timedPlaybackRange.lowerBound
        guard fullDuration > 0 else { return playbackScaleRange.upperBound }

        let minimumContinuationDuration = min(fullDuration * 0.35, 0.25)
        let maximumStartDelay = max(
            fullDuration - minimumContinuationDuration,
            0
        )
        let effectiveStartTime = timedPlaybackRange.lowerBound
            + min(max(playbackScaleStartDelay, 0), maximumStartDelay)
        let continuationDuration = playbackScaleEndTime
            - effectiveStartTime
        guard continuationDuration > 0 else {
            return playbackScaleRange.upperBound
        }

        let rawProgress = (playbackTime - effectiveStartTime)
            / continuationDuration
        let progress = min(max(rawProgress, 0), 1)
        let easedProgress = progress * progress * (3 - 2 * progress)
        return playbackScaleRange.lowerBound
            + (playbackScaleRange.upperBound - playbackScaleRange.lowerBound)
                * CGFloat(easedProgress)
    }
}
