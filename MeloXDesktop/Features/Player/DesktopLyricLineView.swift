import SwiftUI

struct DesktopLyricLineView: View, Equatable {
    private static let annotationSpacing =
        LyricAnnotationMetrics.verticalSpacing

    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    let line: LyricLine
    let isPlaybackLine: Bool
    let isActualPlaybackLine: Bool
    let isScaleFocused: Bool
    let isBlurFocusLine: Bool
    let isPrecedingFocusLine: Bool
    let isFollowingFocusLine: Bool
    let isBrowsingLyrics: Bool
    let actualHighlightedLyricID: LyricLine.ID?
    let visualHighlightedLyricID: LyricLine.ID?
    let focusColorTransition: LyricFocusColorTransition?
    let movementPhase: LyricMovementPhase
    let fontSize: CGFloat
    let layoutWidth: CGFloat
    let visualFocusAnchorY: CGFloat
    let motionProfile: AppleMusicLyricsMotionProfile?
    let compact: Bool
    let allowsLyricBlur: Bool
    let foregroundColor: Color
    let hasSyllableSyncedLyrics: Bool
    let onAnnotationHeightChange: (CGFloat) -> Void
    let onSeek: () -> Void

    var body: some View {
        let isActiveIndependentVocalLine =
            isActualPlaybackLine
            && !isPlaybackLine
            && line.agent?.alignment == .flipped
        let resolvedFontSize = compact
            && motionProfile == nil
            ? min(fontSize, 23)
            : fontSize
        let romanizationFontSize: CGFloat = if let motionProfile {
            // LyricsSpecs wrapper: transliteration font = primary * 0.46
            // (background-vocal pronunciation would use primary * 0.27).
            resolvedFontSize
                * CGFloat(motionProfile.transliterationFontCoefficient)
        } else {
            max(
                resolvedFontSize
                    * CGFloat(model.settings.lyricsRomanizationFontScale),
                compact ? 11 : 13
            )
        }
        let showsTranslation = showsLyricTranslation(
            isFocusedLine: isScaleFocused
        )
        let showsRomanization = showsLyricRomanization(
            isFocusedLine: isScaleFocused
        )
        let reservesAnnotationSpace = (
            model.settings.lyricsRomanizationEnabled
                && line.hasRomanization
        ) || (
            model.settings.lyricsTranslationEnabled
                && line.hasTranslation
        )
        let annotationHeight = lyricAnnotationStrideHeight(
            fontSize: resolvedFontSize,
            romanizationFontSize: romanizationFontSize,
            reservesAnnotationSpace: reservesAnnotationSpace
        )
        let lineSpacing = DesktopLyricsLayoutMetrics.lineSpacing(
            setting:
                motionProfile?.lineSpacing
                    ?? model.settings.lyricsLineSpacing,
            compact: compact,
            usesAppleMusicMotion:
                motionProfile != nil
        )
        let lyricStride = max(
            resolvedFontSize * 1.2
                + annotationHeight
                + lineSpacing,
            1
        )
        let currentLineScale = lyricsCurrentLineScale
        let focusScaleAnimation = DesktopLyricsAnimations
            .focusScaleAnimation(
                settings: model.settings,
                highlightedID: actualHighlightedLyricID,
                lyrics: model.lyrics.lyrics,
                reduceMotion: reduceMotion,
                isFocused: isScaleFocused
            )
        let focusEffectAnimation = DesktopLyricsAnimations
            .focusEffectAnimation(
                settings: model.settings,
                highlightedID: visualHighlightedLyricID,
                lyrics: model.lyrics.lyrics,
                reduceMotion: reduceMotion
            )
        let resolvedAllowsLyricBlur = allowsLyricBlur
            && (motionProfile?.allowsDistanceBlur ?? true)
        let focusBlurRadius = resolvedAllowsLyricBlur
            && !isActiveIndependentVocalLine
            ? self.focusBlurRadius
            : 0
        let clearsBlurWhileBrowsing = motionProfile != nil
            && isBrowsingLyrics
            && model.settings.lyricsUsesUniformDimmingWhileBrowsing
        let blurIntensity = motionProfile == nil
            ? CGFloat(model.settings.lyricsBlurIntensity)
            : clearsBlurWhileBrowsing ? 0 : 1
        let distanceBlurScale = resolvedAllowsLyricBlur
            ? motionProfile == nil
                ? CGFloat(model.settings.lyricsDistanceBlurScale)
                : 1
            : 0
        let dimAmount = min(max(model.settings.lyricsDimAmount, 0), 1)
        let isLineHovered = isHovered

        DesktopTargetDrivenLyricBlur(
            focusRadius: focusBlurRadius,
            focusAnimation: focusEffectAnimation,
            isHovered: isLineHovered
        ) {
            LyricRowPresentationTimeline(
                lyricID: line.id,
                focusedLyricID: visualHighlightedLyricID,
                movementPhase: movementPhase,
                focusTransition: focusColorTransition
            ) { movementOffset, focusProgress in
                Button {
                    if model.settings.lyricsTapToSeek {
                        onSeek()
                        model.player.seek(to: line.time)
                    }
                } label: {
                    SynchronizedLyricText(
                        line: line,
                        isPlaybackLine: isPlaybackLine,
                        isVocalActive: isActualPlaybackLine,
                        playbackFocusProgress: focusProgress.color,
                        usesPseudoTiming:
                            model.settings.lyricsPseudoWordByWord
                            && !hasSyllableSyncedLyrics,
                        allowsUnplayedBlur: resolvedAllowsLyricBlur,
                        fontSize: resolvedFontSize,
                        romanizationFontSize: romanizationFontSize,
                        fontWeight:
                            model.settings
                            .effectiveAppleMusicLyricsFontWeight,
                        alignment: .resolved(
                            for: line,
                            duetLayoutEnabled:
                                model.settings.lyricsDuetLayoutEnabled
                        ),
                        primaryColor: foregroundColor,
                        showsTranslation: showsTranslation,
                        showsRomanization: showsRomanization,
                        includesRomanization: true,
                        reservesAnnotationSpace: reservesAnnotationSpace,
                        // LyricsX's primary, transliteration, and translation
                        // layers all contribute to the selected row's content
                        // geometry. Keep the desktop reservation in layout
                        // too; only their visibility changes on focus.
                        annotationAffectsLayout: true,
                        onAnnotationHeightChange:
                            onAnnotationHeightChange,
                        annotationLayoutAnimation:
                            lyricAnnotationLayoutAnimation(),
                        annotationVisibilityAnimation:
                            lyricAnnotationVisibilityAnimation(
                                focusScaleAnimation: focusScaleAnimation
                            ),
                        visualScale:
                            Self.lyricVisualScale(
                                isFocused: isScaleFocused,
                                focusedScale: currentLineScale,
                                motionProfile: motionProfile
                            ),
                        visualScaleAnimation: focusScaleAnimation,
                        promotedLayoutScale:
                            motionProfile == nil ? currentLineScale : 1,
                        // Duet styling is alignment-only. Measuring vocalist
                        // rows at a narrower width makes them rewrap and
                        // changes the scroll anchor when focus settles.
                        layoutWidth: layoutWidth,
                        motionProfile: motionProfile
                    )
                    .environment(model.player)
                    .environment(model.settings)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(
                    isHovered
                        ? 1
                        : isActiveIndependentVocalLine
                            ? 1
                        : motionProfile == nil
                            ? lyricEmphasis(
                                focusProgress: focusProgress.color,
                                dimAmount: dimAmount
                            )
                            : Self.appleMusicLyricFocusOpacity(
                                focusProgress: focusProgress.color,
                                motionProfile: motionProfile
                            )
                )
                .visualEffect { content, geometry in
                    let frame = geometry.frame(
                        in: .scrollView(axis: .vertical)
                    )
                    let distance = abs(
                        frame.midY
                            + movementOffset
                            - visualFocusAnchorY
                    )
                    let blurRadius = Self.lyricDistanceBlurRadius(
                        forPixelDistance: distance,
                        lyricStride: lyricStride,
                        intensity: blurIntensity * distanceBlurScale,
                        focusProgress: focusProgress.blur,
                        usesNearestAppleMusicBlurRadius:
                            isBlurFocusLine
                                || isPrecedingFocusLine
                                || isFollowingFocusLine,
                        motionProfile: motionProfile
                    )
                    let opacity =
                        isActiveIndependentVocalLine
                            ? 1
                            : motionProfile == nil
                                ? Self.lyricDistanceOpacity(
                                    forPixelDistance: distance,
                                    lyricStride: lyricStride,
                                    dimAmount: dimAmount,
                                    focusProgress: focusProgress.color
                                )
                                : 1
                    return
                        content
                        .blur(
                            radius:
                                isLineHovered
                                    || isActiveIndependentVocalLine
                                    ? 0
                                    : blurRadius
                        )
                        .opacity(isLineHovered ? 1 : opacity)
                    .offset(y: movementOffset)
                }
            }
        }
        .contentShape(.rect)
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovered = true
            case .ended:
                isHovered = false
            }
        }
        .accessibilityLabel(
            line.accessibilityText(
                includingTranslation:
                    model.settings.lyricsTranslationEnabled
                        && showsTranslation,
                includingRomanization:
                    model.settings.lyricsRomanizationEnabled
                        && showsRomanization
            )
        )
        .accessibilityValue(
            isActualPlaybackLine
                ? L10n.string("ui.desktop.lyrics.current_line")
                : ""
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: isHovered
        )
    }

    static func == (
        lhs: DesktopLyricLineView,
        rhs: DesktopLyricLineView
    ) -> Bool {
        lhs.line == rhs.line
            && lhs.isPlaybackLine == rhs.isPlaybackLine
            && lhs.isActualPlaybackLine == rhs.isActualPlaybackLine
            && lhs.isScaleFocused == rhs.isScaleFocused
            && lhs.isBlurFocusLine == rhs.isBlurFocusLine
            && lhs.isPrecedingFocusLine == rhs.isPrecedingFocusLine
            && lhs.isFollowingFocusLine == rhs.isFollowingFocusLine
            && lhs.isBrowsingLyrics == rhs.isBrowsingLyrics
            && lhs.actualHighlightedLyricID
                == rhs.actualHighlightedLyricID
            && lhs.visualHighlightedLyricID
                == rhs.visualHighlightedLyricID
            && lhs.focusColorTransition == rhs.focusColorTransition
            && lhs.movementPhase == rhs.movementPhase
            && lhs.fontSize == rhs.fontSize
            && lhs.layoutWidth == rhs.layoutWidth
            && lhs.visualFocusAnchorY == rhs.visualFocusAnchorY
            && lhs.motionProfile == rhs.motionProfile
            && lhs.compact == rhs.compact
            && lhs.allowsLyricBlur == rhs.allowsLyricBlur
            && lhs.foregroundColor == rhs.foregroundColor
            && lhs.hasSyllableSyncedLyrics
                == rhs.hasSyllableSyncedLyrics
    }

    private var lyricsCurrentLineScale: CGFloat {
        CGFloat(
            min(
                max(
                    model.settings.effectiveAppleMusicLyricsCurrentLineScale,
                    AppSettings.lyricsCurrentLineScaleRange.lowerBound
                ),
                AppSettings.lyricsCurrentLineScaleRange.upperBound
            )
        )
    }

    private var focusBlurRadius: CGFloat {
        guard motionProfile == nil else {
            return 0
        }
        let preceding: CGFloat = isPrecedingFocusLine ? 2.4 : 0
        let following: CGFloat = isFollowingFocusLine ? 0.7 : 0
        return (preceding + following)
            * CGFloat(model.settings.lyricsBlurIntensity)
    }

    private func showsLyricTranslation(
        isFocusedLine: Bool
    ) -> Bool {
        // Music 1.6.6 keeps every line's translation layer mounted and
        // visible regardless of whether that line has played yet
        // (MusicDespacitoContentLayer builds `translationLineLayer` whenever
        // a line has translation text and never keys its opacity on focus).
        // The user-configurable focused/all-lines switch only applies to the
        // legacy renderer.
        if motionProfile != nil {
            return true
        }
        return switch model.settings.lyricsTranslationDisplayMode {
        case .focusedLine: isFocusedLine
        case .allLines: true
        }
    }

    private func showsLyricRomanization(
        isFocusedLine: Bool
    ) -> Bool {
        // Same as translations: Music mounts the transliteration layer for
        // every line that has romanization data, played or not.
        if motionProfile != nil {
            return true
        }
        return switch model.settings.lyricsRomanizationDisplayMode {
        case .focusedLine: isFocusedLine
        case .allLines: true
        }
    }

    private func lyricAnnotationStrideHeight(
        fontSize: CGFloat,
        romanizationFontSize: CGFloat,
        reservesAnnotationSpace: Bool
    ) -> CGFloat {
        guard reservesAnnotationSpace else { return 0 }
        let displaysRomanizations = model.settings.lyricsRomanizationEnabled
            && line.hasRomanization
        let displaysTranslations = model.settings.lyricsTranslationEnabled
            && line.hasTranslation
        let annotationGap = motionProfile.map {
            CGFloat($0.translationSpacing)
        } ?? Self.annotationSpacing
        let romanizationHeight = displaysRomanizations
            ? romanizationFontSize * 1.2 + annotationGap
            : 0
        let translationHeight = displaysTranslations
            ? max(
                fontSize
                    * CGFloat(
                        motionProfile?
                            .translationLargeFontCoefficient
                            ?? model.settings.lyricsTranslationFontScale
                    ),
                compact ? 11 : 13
            ) * 1.2
                + annotationGap
                + (motionProfile.map {
                    CGFloat($0.translationBottomPadding)
                } ?? 0)
            : 0
        return romanizationHeight + translationHeight
    }

    private func lyricAnnotationVisibilityAnimation(
        focusScaleAnimation: Animation?
    ) -> Animation? {
        guard !reduceMotion else { return nil }
        if let appleMusicSpring = appleMusicAnnotationSpring() {
            return appleMusicSpring
        }
        if usesFocusedLineAnnotationMode {
            return focusScaleAnimation
        }
        let duration = min(
            max(model.settings.lyricsFocusCascadeDuration * 0.7, 0.16),
            0.32
        )
        return .smooth(duration: duration)
    }

    private func lyricAnnotationLayoutAnimation() -> Animation? {
        guard !reduceMotion else { return nil }
        if let appleMusicSpring = appleMusicAnnotationSpring() {
            return appleMusicSpring
        }
        let duration = usesFocusedLineAnnotationMode
            ? DesktopLyricsAnimations.focusScaleDuration(
                settings: model.settings,
                highlightedID: actualHighlightedLyricID,
                lyrics: model.lyrics.lyrics
            )
            : min(
                max(model.settings.lyricsFocusCascadeDuration * 0.7, 0.16),
                0.32
            )
        return .smooth(duration: duration)
    }

    private func appleMusicAnnotationSpring() -> Animation? {
        guard let motionProfile else { return nil }
        let spring = isScaleFocused
            ? motionProfile.annotationPresentationSpring
            : motionProfile.annotationDismissalSpring
        return .interpolatingSpring(
            mass: spring.mass,
            stiffness: spring.stiffness,
            damping: spring.damping,
            initialVelocity: 0
        )
    }

    private var usesFocusedLineAnnotationMode: Bool {
        guard motionProfile == nil else {
            return false
        }
        return (
            model.settings.lyricsRomanizationEnabled
                && model.settings.lyricsRomanizationDisplayMode
                    == .focusedLine
        ) || (
            model.settings.lyricsTranslationEnabled
                && model.settings.lyricsTranslationDisplayMode
                    == .focusedLine
        )
    }

    nonisolated private static func lyricDistanceBlurRadius(
        forPixelDistance distance: CGFloat,
        lyricStride: CGFloat,
        intensity: CGFloat,
        focusProgress: CGFloat,
        usesNearestAppleMusicBlurRadius: Bool,
        motionProfile: AppleMusicLyricsMotionProfile?
    ) -> CGFloat {
        let lineDistance = max(distance / max(lyricStride, 1), 0)
        let baseRadius: CGFloat
        if let motionProfile {
            let minimum = max(
                CGFloat(motionProfile.nonFocusedBlurRadius),
                0
            )
            let maximum = max(
                CGFloat(motionProfile.maximumNonFocusedBlurRadius),
                minimum
            )
            baseRadius = usesNearestAppleMusicBlurRadius
                ? minimum
                : maximum
        } else {
            let blurProgress = max(lineDistance - 1.35, 0)
            baseRadius = min(blurProgress * 3.1, 10)
        }
        let normalizedFocusProgress = min(max(focusProgress, 0), 1)
        return baseRadius * intensity * (1 - normalizedFocusProgress)
    }

    nonisolated private static func appleMusicLyricFocusOpacity(
        focusProgress: CGFloat,
        motionProfile: AppleMusicLyricsMotionProfile?
    ) -> Double {
        guard let motionProfile else { return 1 }
        let progress = Double(min(max(focusProgress, 0), 1))
        return motionProfile.deselectedTextOpacity
            + (
                motionProfile.selectedTextOpacity
                    - motionProfile.deselectedTextOpacity
            ) * progress
    }

    nonisolated private static func lyricVisualScale(
        isFocused: Bool,
        focusedScale: CGFloat,
        motionProfile: AppleMusicLyricsMotionProfile?
    ) -> CGFloat {
        guard let motionProfile else {
            return isFocused ? focusedScale : 1
        }
        return isFocused ? 1 : CGFloat(motionProfile.deselectedScale)
    }

    nonisolated private static func lyricDistanceOpacity(
        forPixelDistance distance: CGFloat,
        lyricStride: CGFloat,
        dimAmount: Double,
        focusProgress: CGFloat
    ) -> Double {
        let lineDistance = Double(distance / lyricStride)
        let baseOpacity: Double = switch lineDistance {
        case ...1:
            1 - lineDistance * 0.44
        case ...2:
            0.56 - (lineDistance - 1) * 0.22
        default:
            max(0.12, 0.34 - (lineDistance - 2) * 0.07)
        }
        let distanceOpacity = 1 - (1 - baseOpacity) * dimAmount
        let normalizedFocusProgress = Double(
            min(max(focusProgress, 0), 1)
        )
        return distanceOpacity
            + (1 - distanceOpacity) * normalizedFocusProgress
    }

    private func lyricEmphasis(
        focusProgress: CGFloat,
        dimAmount: Double
    ) -> Double {
        let unfocusedOpacity = 1 - (1 - 0.52) * dimAmount
        let normalizedFocusProgress = Double(
            min(max(focusProgress, 0), 1)
        )
        return unfocusedOpacity
            + (1 - unfocusedOpacity) * normalizedFocusProgress
    }
}
