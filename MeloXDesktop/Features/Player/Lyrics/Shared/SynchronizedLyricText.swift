import SwiftUI

enum SynchronizedLyricTextAlignment: Equatable {
    case leading
    case center
    case trailing

    var textAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var scaleAnchor: UnitPoint {
        switch self {
        case .leading: .topLeading
        case .center: .top
        case .trailing: .topTrailing
        }
    }

    static func resolved(
        for line: LyricLine,
        duetLayoutEnabled: Bool
    ) -> SynchronizedLyricTextAlignment {
        guard duetLayoutEnabled,
              line.agent?.alignment == .flipped else {
            return .leading
        }
        return .trailing
    }
}

struct SynchronizedLyricText: View {
    static let interactionBackgroundVisualOverflow: CGFloat = 16

    private static let interactionBackgroundCornerRadius: CGFloat = 16

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.effectiveLyricsRefreshRate) private var effectiveLyricsRefreshRate
    @Environment(\.lyricsRenderingIsActive) private var lyricsRenderingIsActive
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let line: LyricLine
    let isPlaybackLine: Bool
    let isVocalActive: Bool
    let playbackFocusProgress: CGFloat?
    let usesPseudoTiming: Bool
    let allowsUnplayedBlur: Bool
    let fontSize: CGFloat
    let romanizationFontSize: CGFloat
    let fontWeight: LyricsFontWeight
    let alignment: SynchronizedLyricTextAlignment
    let fontScale: CGFloat
    let primaryColor: Color
    let showsTranslation: Bool
    let showsRomanization: Bool
    let includesTranslation: Bool
    let includesRomanization: Bool
    let reservesAnnotationSpace: Bool
    let annotationAffectsLayout: Bool
    let onAnnotationHeightChange: ((CGFloat) -> Void)?
    let annotationLayoutAnimation: Animation?
    let annotationVisibilityAnimation: Animation?
    let interactionBackgroundOpacity: Double
    let visualScale: CGFloat
    let visualScaleAnimation: Animation?
    let promotedLayoutScale: CGFloat
    let layoutWidth: CGFloat?
    let motionProfile: AppleMusicLyricsMotionProfile?
    let isBackgroundVocalPresentation: Bool
    let playbackScaleRange: ClosedRange<CGFloat>?
    let playbackScaleStartDelay: TimeInterval
    private let synchronizedText: Text
    private let pseudoSynchronizedText: Text
    private let layoutStableText: Text
    private let hasPseudoSyllables: Bool
    private let timedPlaybackRange: ClosedRange<TimeInterval>?
    private let romanizationRows: [LyricRubyRow]

    init(
        line: LyricLine,
        isPlaybackLine: Bool,
        isVocalActive: Bool? = nil,
        playbackFocusProgress: CGFloat? = nil,
        usesPseudoTiming: Bool,
        allowsUnplayedBlur: Bool = true,
        fontSize: CGFloat,
        romanizationFontSize: CGFloat? = nil,
        fontWeight: LyricsFontWeight = .bold,
        alignment: SynchronizedLyricTextAlignment = .leading,
        fontScale: CGFloat = 1,
        primaryColor: Color = .white,
        showsTranslation: Bool = true,
        showsRomanization: Bool = true,
        includesTranslation: Bool = true,
        includesRomanization: Bool = false,
        reservesAnnotationSpace: Bool = true,
        annotationAffectsLayout: Bool = true,
        onAnnotationHeightChange: ((CGFloat) -> Void)? = nil,
        annotationLayoutAnimation: Animation? = nil,
        annotationVisibilityAnimation: Animation? = nil,
        interactionBackgroundOpacity: Double = 0,
        visualScale: CGFloat = 1,
        visualScaleAnimation: Animation? = nil,
        promotedLayoutScale: CGFloat = 1,
        layoutWidth: CGFloat? = nil,
        motionProfile: AppleMusicLyricsMotionProfile? = nil,
        isBackgroundVocalPresentation: Bool = false,
        playbackScaleRange: ClosedRange<CGFloat>? = nil,
        playbackScaleStartDelay: TimeInterval = 0
    ) {
        self.line = line
        self.isPlaybackLine = isPlaybackLine
        self.isVocalActive = isVocalActive ?? isPlaybackLine
        self.playbackFocusProgress = playbackFocusProgress
        self.usesPseudoTiming = usesPseudoTiming
        self.allowsUnplayedBlur = allowsUnplayedBlur
        self.fontSize = fontSize
        self.romanizationFontSize = romanizationFontSize
            ?? max(fontSize * 0.55, 13 * fontScale)
        self.fontWeight = fontWeight
        self.alignment = alignment
        self.fontScale = fontScale
        self.primaryColor = primaryColor
        self.showsTranslation = showsTranslation
        self.showsRomanization = showsRomanization
        self.includesTranslation = includesTranslation
        self.includesRomanization = includesRomanization
        self.reservesAnnotationSpace = reservesAnnotationSpace
        self.annotationAffectsLayout = annotationAffectsLayout
        self.onAnnotationHeightChange = onAnnotationHeightChange
        self.annotationLayoutAnimation = annotationLayoutAnimation
        self.annotationVisibilityAnimation = annotationVisibilityAnimation
        self.interactionBackgroundOpacity =
            interactionBackgroundOpacity
        self.visualScale = visualScale
        self.visualScaleAnimation = visualScaleAnimation
        self.promotedLayoutScale = promotedLayoutScale
        self.layoutWidth = layoutWidth
        self.motionProfile = motionProfile
        self.isBackgroundVocalPresentation =
            isBackgroundVocalPresentation
        self.playbackScaleRange = playbackScaleRange
        self.playbackScaleStartDelay = playbackScaleStartDelay

        let layout = SynchronizedLyricTextLayout.resolve(
            line: line,
            usesPseudoTiming: usesPseudoTiming,
            fontSize: fontSize,
            romanizationFontSize: self.romanizationFontSize,
            fontWeight: fontWeight,
            includesRomanization: includesRomanization,
            showsRomanization: showsRomanization,
            layoutWidth: layoutWidth,
            promotedLayoutScale: promotedLayoutScale,
            playbackScaleRange: playbackScaleRange
        )
        synchronizedText = layout.synchronizedText
        pseudoSynchronizedText = layout.pseudoSynchronizedText
        layoutStableText = layout.layoutStableText
        hasPseudoSyllables = layout.hasPseudoSyllables
        timedPlaybackRange = layout.timedPlaybackRange
        romanizationRows = layout.romanizationRows
    }

    var body: some View {
        VStack(alignment: alignment.horizontalAlignment, spacing: 0) {
            if line.backgroundVocal?.position == .beforePrimary {
                backgroundVocalContent
                    .padding(.bottom, backgroundVocalSpacing)
            }

            primaryContent

            if line.backgroundVocal?.position == .afterPrimary {
                backgroundVocalContent
                    .padding(.top, backgroundVocalSpacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
    }

    private var primaryContent: some View {
        LyricAnnotationLayout(
            expansion:
                annotationAffectsLayout
                    && reservesAnnotationSpace
                    && hasIncludedTranslation
                    ? 1
                    : 0,
            spacing: annotationSpacing,
            constrainedWidth: normalizedLayoutWidth
        ) {
            primaryLyric
                .animation(
                    accessibilityReduceMotion ? nil : .easeInOut(duration: 0.28),
                    value: legacyTimedLyricAnimationValue
                )

            annotationStack
        }
        .animation(
            accessibilityReduceMotion ? nil : annotationLayoutAnimation,
            value: displaysAnnotations
        )
        .animation(
            accessibilityReduceMotion ? nil : annotationLayoutAnimation,
            value: displaysRomanization
        )
        .animation(
            accessibilityReduceMotion
                ? nil
                : annotationVisibilityAnimation,
            value: displaysRomanization
        )
        .animation(
            accessibilityReduceMotion ? nil : annotationLayoutAnimation,
            value: displaysTranslation
        )
        .multilineTextAlignment(alignment.textAlignment)
        .frame(
            width: normalizedLayoutWidth,
            alignment: alignment.frameAlignment
        )
        .background(alignment: .topLeading) {
            if interactionBackgroundOpacity > 0 {
                RoundedRectangle(
                    cornerRadius:
                        Self.interactionBackgroundCornerRadius
                            / effectiveVisualScale,
                    style: .continuous
                )
                .fill(
                    .white.opacity(
                        min(
                            max(interactionBackgroundOpacity, 0),
                            1
                        )
                    )
                )
                .padding(
                    -Self.interactionBackgroundVisualOverflow
                        / effectiveVisualScale
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .scaleEffect(
            visualScale,
            anchor: alignment.scaleAnchor
        )
        .animation(
            accessibilityReduceMotion ? nil : visualScaleAnimation,
            value: visualScale
        )
        .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
    }

    @ViewBuilder
    private var backgroundVocalContent: some View {
        if let backgroundVocal = line.backgroundVocal {
            SynchronizedLyricText(
                line: backgroundVocal.lyricLine(agent: line.agent),
                isPlaybackLine: false,
                isVocalActive: isVocalActive,
                playbackFocusProgress: nil,
                usesPseudoTiming: false,
                allowsUnplayedBlur: allowsUnplayedBlur,
                fontSize: backgroundVocalFontSize,
                romanizationFontSize:
                    backgroundVocalRomanizationFontSize,
                fontWeight: fontWeight,
                alignment: alignment,
                fontScale: fontScale,
                primaryColor: primaryColor,
                showsTranslation: showsTranslation,
                showsRomanization: false,
                includesTranslation: includesTranslation,
                includesRomanization: false,
                reservesAnnotationSpace: false,
                annotationAffectsLayout: true,
                visualScale: backgroundVocalScale,
                visualScaleAnimation: visualScaleAnimation,
                promotedLayoutScale: promotedLayoutScale,
                layoutWidth: layoutWidth,
                motionProfile: motionProfile,
                isBackgroundVocalPresentation: true
            )
        }
    }

    private var annotationStack: some View {
        VStack(
            alignment: alignment.horizontalAlignment,
            spacing: 0
        ) {
            // Keep the hidden translation mounted so its reveal starts from
            // an already measured height instead of invalidating the row.
            if hasIncludedTranslation,
               let translation = line.translation {
                annotationText(
                    translation,
                    fontSize: translationFontSize,
                    opacity: settings.lyricsTranslationOpacity
                )
            }
        }
        .onGeometryChange(for: CGFloat.self) { geometry in
            Self.quantizedAnnotationHeight(geometry.size.height)
        } action: { height in
            onAnnotationHeightChange?(height)
        }
        .opacity(displaysTranslation ? 1 : 0)
        .animation(
            accessibilityReduceMotion
                ? nil
                : annotationVisibilityAnimation,
            value: displaysTranslation
        )
        .frame(
            width: normalizedLayoutWidth,
            alignment: alignment.frameAlignment
        )
    }

    nonisolated private static func quantizedAnnotationHeight(
        _ height: CGFloat
    ) -> CGFloat {
        (height * 2).rounded() / 2
    }

    private func annotationText(
        _ text: String,
        fontSize: CGFloat,
        opacity: Double
    ) -> some View {
        Text(verbatim: text)
            .font(
                .system(
                    size: fontSize,
                    weight: fontWeight.swiftUIWeight
                )
            )
            .foregroundStyle(.white.opacity(opacity))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                width: normalizedLayoutWidth,
                alignment: alignment.frameAlignment
            )
            .padding(
                .bottom,
                motionProfile.map {
                    CGFloat($0.translationBottomPadding)
                } ?? 0
            )
    }

    private var primaryLyric: some View {
        stablePrimaryLyric
            .opacity(presentsTimedLyrics ? 0 : 1)
            .overlay(alignment: alignment.frameAlignment) {
                if presentsTimedLyrics {
                    synchronizedPrimaryLyric
                }
            }
    }

    private var stablePrimaryLyric: some View {
        Group {
            if usesRubyLayout {
                rubyText(
                    at: timedPlaybackRange?.lowerBound ?? 0,
                    appliesTimingEffects: false
                )
            } else {
                stablePrimaryContent
                    .font(primaryFont)
                    .foregroundStyle(primaryColor)
                    .multilineTextAlignment(alignment.textAlignment)
                    .lineLimit(nil)
                    .fixedSize(
                        horizontal:
                            primaryLayoutWidth != nil
                                && alignment == .leading,
                        vertical: true
                    )
                    .textRenderer(
                        lyricTextRenderer(
                            at: timedPlaybackRange?.lowerBound ?? 0,
                            appliesTimingEffects: false
                        )
                    )
            }
        }
            .frame(
                width: primaryLayoutWidth,
                alignment: alignment.frameAlignment
            )
            .frame(
                maxWidth: .infinity,
                alignment: alignment.frameAlignment
            )
    }

    private var synchronizedPrimaryLyric: some View {
        TimelineView(
            .animation(
                minimumInterval: effectiveLyricsRefreshRate.minimumInterval,
                paused: !player.isPlaying || !lyricsRenderingIsActive
            )
        ) { context in
            let playbackTime = player.estimatedProgress(at: context.date)
                + settings.wordByWordLyricsAdvanceTime
                + (motionProfile?.animationHeadstart ?? 0)

            // Keep timing effects tied to the focus transition. A finished
            // line fades its played lift back to the baseline as it becomes
            // the previous line; a hardcoded strength would make that lift
            // disappear instantly and the lyric visibly jump downward.
            Group {
                if usesRubyLayout {
                    rubyText(
                        at: playbackTime,
                        appliesTimingEffects: true,
                        timingEffectsStrength:
                            timedLyricPresentationProgress
                    )
                } else {
                    activeSynchronizedText
                        .font(primaryFont)
                        .foregroundStyle(primaryColor)
                        .multilineTextAlignment(alignment.textAlignment)
                        .lineLimit(nil)
                        .fixedSize(
                            horizontal: alignment == .leading,
                            vertical: true
                        )
                        .textRenderer(
                            lyricTextRenderer(
                                at: playbackTime,
                                timingEffectsStrength:
                                    timedLyricPresentationProgress
                            )
                        )
                }
            }
                .frame(
                    width: timedLayoutWidth,
                    alignment: alignment.frameAlignment
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: alignment.frameAlignment
                )
                .scaleEffect(
                    playbackPresentationScale(at: playbackTime),
                    anchor: .center
                )
        }
    }

    private var stablePrimaryContent: Text {
        supportsTimedLyrics
            ? activeSynchronizedText
            : layoutStableText
    }

    private func lyricTextRenderer(
        at playbackTime: TimeInterval,
        appliesTimingEffects: Bool = true,
        timingEffectsStrength: Double = 1
    ) -> LyricGlowTextRenderer {
        LyricGlowTextRenderer(
            playbackTime: playbackTime,
            style: lyricRendererStyle,
            layoutConfiguration: .init(
                width: rendererLayoutWidth,
                centersLines: alignment == .center
            ),
            appliesTimingEffects: appliesTimingEffects,
            timingEffectsStrength: timingEffectsStrength
        )
    }

    private var lyricRendererStyle: LyricGlowTextRenderer.Style {
        .init(
            glowRadius: glowRadius,
            glowOpacity: glowOpacity,
            glowsLongSyllablesOnly:
                motionProfile == nil
                    ? settings.lyricsGlowLongSyllablesOnly
                    : false,
            longSyllableDetectionMode:
                settings.lyricsLongSyllableDetectionMode,
            longSyllableDurationThreshold:
                settings.lyricsLongSyllableDurationThreshold,
            unplayedOpacity: unplayedOpacity,
            focusOpacityEndpoints: focusOpacityEndpoints,
            maximumUnplayedBlurRadius: maximumUnplayedBlurRadius,
            playedRise: playedRise,
            maximumLongSyllableScale: maximumLongSyllableScale,
            longSyllableExpansionPadding: longSyllableExpansionPadding,
            highlightGradientWidth: CGFloat(
                motionProfile == nil
                    ? settings.lyricsHighlightGradientWidth
                    : 1
            ),
            lineProgressionGradientFeather:
                motionProfile.map {
                    CGFloat($0.lineProgressionGradientFeather)
                },
            highlightGradientReduction: CGFloat(
                motionProfile == nil
                    ? settings.lyricsHighlightGradientReduction
                    : 0
            ),
            lineFinishProgressAnimationDuration:
                motionProfile?.lineFinishProgressAnimationDuration,
            liftMode: motionProfile == nil ? settings.lyricsLiftMode : .character
        )
    }

    private func rubyText(
        at playbackTime: TimeInterval,
        appliesTimingEffects: Bool,
        timingEffectsStrength: Double = 1
    ) -> some View {
        LyricRubyText(
            rows: romanizationRows,
            fontSize: fontSize,
            romanizationFontSize: romanizationFontSize,
            fontWeight: fontWeight,
            primaryColor: primaryColor,
            romanizationOpacity:
                settings.lyricsRomanizationOpacity,
            alignment: alignment,
            annotationSpacing: annotationSpacing,
            annotationLayoutExpansion:
                reservesAnnotationSpace && hasIncludedRomanization ? 1 : 0,
            annotationVisibility:
                displaysRomanization ? 1 : 0,
            playbackTime: playbackTime,
            rendererStyle: lyricRendererStyle,
            appliesTimingEffects: appliesTimingEffects,
            timingEffectsStrength: timingEffectsStrength
        )
    }

    private var primaryLayoutWidth: CGFloat? {
        supportsTimedLyrics ? timedLayoutWidth : normalizedLayoutWidth
    }

    private var rendererLayoutWidth: CGFloat? {
        supportsTimedLyrics ? timedLayoutWidth : normalizedLayoutWidth
    }

    private var supportsTimedLyrics: Bool {
        (settings.lyricsWordByWord && line.isSyllableSynced)
            || (usesPseudoTiming && hasPseudoSyllables)
    }

    private var usesTimedLyrics: Bool {
        isVocalActive && supportsTimedLyrics
    }

    private var timedLyricPresentationProgress: Double {
        guard supportsTimedLyrics else { return 0 }
        if isVocalActive { return 1 }
        guard let playbackFocusProgress else {
            return usesTimedLyrics ? 1 : 0
        }
        return Double(min(max(playbackFocusProgress, 0), 1))
    }

    private var presentsTimedLyrics: Bool {
        supportsTimedLyrics
            && (isVocalActive || timedLyricPresentationProgress > 0)
    }

    private var legacyTimedLyricAnimationValue: Bool {
        playbackFocusProgress == nil && usesTimedLyrics
    }

    private var activeSynchronizedText: Text {
        line.isSyllableSynced
            ? synchronizedText
            : pseudoSynchronizedText
    }

    private var primaryFont: Font {
        .system(size: fontSize, weight: fontWeight.swiftUIWeight)
    }

    /// Keep translations optically stable across focus changes. The row
    /// reservation in `DesktopLyricLineView` already uses the large
    /// coefficient for every mounted line, so rendering the same size avoids
    /// focused/non-focused font jumps without changing row geometry.
    private var translationFontSize: CGFloat {
        if let motionProfile {
            if isBackgroundVocalPresentation {
                return fontSize
                    * CGFloat(
                        motionProfile
                            .translationBackgroundVocalsFontCoefficient
                            / motionProfile.backgroundVocalsFontCoefficient
                    )
            }
            return fontSize
                * CGFloat(motionProfile.translationLargeFontCoefficient)
        }
        return max(
            CGFloat(settings.lyricsFontSize * settings.lyricsTranslationFontScale) * fontScale,
            13 * fontScale
        )
    }

    private var backgroundVocalSpacing: CGFloat {
        CGFloat(motionProfile?.backgroundVocalsTopSpacing ?? 10)
    }

    private var backgroundVocalFontSize: CGFloat {
        fontSize
            * CGFloat(motionProfile?.backgroundVocalsFontCoefficient ?? 0.63)
    }

    private var backgroundVocalRomanizationFontSize: CGFloat {
        fontSize
            * CGFloat(
                motionProfile?
                    .transliterationBackgroundVocalsFontCoefficient
                    ?? 0.27
            )
    }

    private var backgroundVocalScale: CGFloat {
        let relativeScale = isPlaybackLine
            ? 1
            : CGFloat(
                motionProfile?.backgroundVocalsDeselectedScale ?? 0.9
            )
        return visualScale * relativeScale
    }

    /// Generic LyricsSpecs builder sets `translationSpacing = 7`; the legacy
    /// editable layout keeps its 4pt annotation gap.
    private var annotationSpacing: CGFloat {
        if let motionProfile {
            return CGFloat(motionProfile.translationSpacing)
        }
        return LyricAnnotationMetrics.verticalSpacing
    }

    private var hasIncludedTranslation: Bool {
        includesTranslation
            && settings.lyricsTranslationEnabled
            && line.translation != nil
    }

    private var hasIncludedRomanization: Bool {
        includesRomanization
            && settings.lyricsRomanizationEnabled
            && line.romanization != nil
    }

    private var displaysTranslation: Bool {
        showsTranslation && hasIncludedTranslation
    }

    private var displaysRomanization: Bool {
        showsRomanization && hasIncludedRomanization
    }

    private var displaysAnnotations: Bool {
        displaysRomanization || displaysTranslation
    }

    private var usesRubyLayout: Bool {
        hasIncludedRomanization
            && !romanizationRows.isEmpty
    }

    private var glowRadius: CGFloat {
        if let motionProfile {
            return CGFloat(motionProfile.glowRadius)
        }
        guard settings.lyricsGlowEnabled else { return 0 }
        return CGFloat(
            Double(fontSize)
                * 0.2
                * settings.lyricsGlowIntensity
        )
    }

    private var glowOpacity: Double {
        if motionProfile != nil { return 0.4 }
        guard settings.lyricsGlowEnabled else { return 0 }
        return min(settings.lyricsGlowIntensity, 1)
    }

    private var maximumUnplayedBlurRadius: CGFloat {
        guard allowsUnplayedBlur else { return 0 }
        guard motionProfile == nil else { return 0 }
        return CGFloat(settings.lyricsBlurIntensity) * 0.55 * fontScale
    }

    private var playedRise: CGFloat {
        guard !accessibilityReduceMotion else { return 0 }
        if let motionProfile {
            return CGFloat(motionProfile.syllableLift)
        }
        return min(max(fontSize * 0.1, 1.5), 6)
    }

    private var maximumLongSyllableScale: CGFloat {
        guard !accessibilityReduceMotion else { return 1 }
        if let motionProfile {
            return CGFloat(motionProfile.emphasisScaleRange.upperBound)
        }
        return 1 + CGFloat(settings.lyricsLongToneExpansionAmount)
    }

    private var unplayedOpacity: Double {
        motionProfile?.selectedUpcomingTextOpacity ?? 0.3
    }

    private var focusOpacityEndpoints: LyricFocusOpacityEndpoints? {
        guard let motionProfile else { return nil }
        return LyricFocusOpacityEndpoints(
            deselected: motionProfile.deselectedTextOpacity,
            selected: motionProfile.selectedTextOpacity,
            selectedUpcoming: motionProfile.selectedUpcomingTextOpacity
        )
    }

    private var longSyllableExpansionPadding: CGFloat {
        fontSize
            * (maximumLongSyllableScale - 1)
            * CGFloat(1.2)
    }

    private var effectivePromotedLayoutScale: CGFloat {
        guard promotedLayoutScale.isFinite else { return 1 }
        return max(promotedLayoutScale, 1)
    }

    private var effectiveVisualScale: CGFloat {
        guard visualScale.isFinite else { return 1 }
        return max(visualScale, 1)
    }

    private var timedLayoutWidth: CGFloat? {
        guard let normalizedLayoutWidth,
              let maximumScale = playbackScaleRange?.upperBound else {
            return normalizedLayoutWidth
        }
        return normalizedLayoutWidth / max(maximumScale, 1)
    }

    private var normalizedLayoutWidth: CGFloat? {
        layoutWidth.map {
            $0 / effectivePromotedLayoutScale
        }
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

    private func playbackPresentationScale(
        at playbackTime: TimeInterval
    ) -> CGFloat {
        let activeScale = playbackScale(at: playbackTime)
        return 1
            + (activeScale - 1)
                * CGFloat(timedLyricPresentationProgress)
    }
}
