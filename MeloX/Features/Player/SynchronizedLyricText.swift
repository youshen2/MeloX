import SwiftUI

enum SynchronizedLyricTextAlignment {
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
}

struct SynchronizedLyricText: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let line: LyricLine
    let isPlaybackLine: Bool
    let usesPseudoTiming: Bool
    let alignment: SynchronizedLyricTextAlignment
    let fontScale: CGFloat
    let primaryColor: Color
    let showsTranslation: Bool
    private let synchronizedText: Text
    private let pseudoSynchronizedText: Text
    private let hasPseudoSyllables: Bool

    init(
        line: LyricLine,
        isPlaybackLine: Bool,
        usesPseudoTiming: Bool,
        alignment: SynchronizedLyricTextAlignment = .leading,
        fontScale: CGFloat = 1,
        primaryColor: Color = .white,
        showsTranslation: Bool = true
    ) {
        self.line = line
        self.isPlaybackLine = isPlaybackLine
        self.usesPseudoTiming = usesPseudoTiming
        self.alignment = alignment
        self.fontScale = fontScale
        self.primaryColor = primaryColor
        self.showsTranslation = showsTranslation

        let pseudoSyllables = usesPseudoTiming
            ? line.makePseudoSyllables()
            : []
        synchronizedText = Self.makeTimedText(from: line.syllables)
        pseudoSynchronizedText = Self.makeTimedText(from: pseudoSyllables)
        hasPseudoSyllables = !pseudoSyllables.isEmpty
    }

    private static func makeTimedText(from syllables: [LyricSyllable]) -> Text {
        syllables.reduce(Text(verbatim: "")) { text, syllable in
            let fragment = Text(verbatim: syllable.text).customAttribute(
                LyricTimingTextAttribute(
                    startTime: syllable.startTime,
                    endTime: syllable.endTime
                )
            )
            return Text("\(text)\(fragment)")
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
        .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
    }

    @ViewBuilder
    private var primaryLyric: some View {
        if usesTimedLyrics {
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 30.0,
                    paused: !player.isPlaying
                )
            ) { context in
                activeSynchronizedText
                    .font(primaryFont)
                    .foregroundStyle(primaryColor)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        maxWidth: .infinity,
                        alignment: alignment.frameAlignment
                    )
                    .textRenderer(
                        LyricGlowTextRenderer(
                            playbackTime: player.estimatedProgress(at: context.date)
                                + settings.lyricsAdvanceTime,
                            glowRadius: glowRadius,
                            glowOpacity: glowOpacity,
                            unplayedOpacity: 0.3,
                            maximumUnplayedBlurRadius: maximumUnplayedBlurRadius
                        )
                    )
            }
            .transition(.opacity)
        } else {
            Text(verbatim: line.text)
                .font(primaryFont)
                .foregroundStyle(primaryColor)
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
        .system(
            size: CGFloat(settings.lyricsFontSize) * fontScale,
            weight: .bold
        )
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
            settings.lyricsFontSize
                * Double(fontScale)
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
}
