import SwiftUI
import UIKit

struct AppleMusicLyricsView: View {
    private typealias RetainedCascadeLyric =
        AppleMusicRetainedViewportPlanner.RetainedLyric<LyricLine.ID>

    private static let customBottomPreloadLineCount = 2
    private static let customFutureCascadeSafetyLineCount = 6
    private static let annotationSpacing =
        LyricAnnotationMetrics.verticalSpacing
    private static let cascadeSettlementGraceDuration: TimeInterval =
        1.0 / 60.0
    nonisolated private static let expandedBottomDistanceScale: CGFloat = 0.68

    nonisolated private enum PositionCascadeLineID: Hashable {
        case lyric(LyricLine.ID)
        case interlude(LyricInterlude.ID)
    }

    private struct LyricRowVisualContext {
        let activePlaybackLyricIDs: Set<LyricLine.ID>
        let visualScaleFocusLyricID: LyricLine.ID?
        let precedingFocusLyricID: LyricLine.ID?
        let followingFocusLyricID: LyricLine.ID?
        let retainedCascadeLyricIDs: Set<LyricLine.ID>
        let usesPseudoTiming: Bool
        let romanizationFontSize: CGFloat
        let reservesAnnotationSpace: Bool
        let currentLineScale: CGFloat
        let lyricLayoutWidth: CGFloat
        let focusAnchorY: CGFloat
        let hiddenInterfaceProgress: CGFloat
        let distanceBlurScale: CGFloat
        let hiddenInterfaceBlurScale: CGFloat
        let viewportHeight: CGFloat
        let lyricStride: CGFloat
        let activeBlurIntensity: CGFloat
        let motionProfile: AppleMusicLyricsMotionProfile?
        let distanceDimAmount: Double
        let dimAmount: Double
        let focusEffectAnimation: Animation?
    }

    private struct LyricScrollPresentationContext {
        let viewportSize: CGSize
        let focusPosition: CGFloat
        let maskTopOpaque: CGFloat
        let maskBottomOpaque: CGFloat
        let maskBottomClear: CGFloat
        let horizontalVisualOverflow: CGFloat
        let row: LyricRowVisualContext
    }

    private struct LyricLayoutSettingsSignature: Equatable {
        let translationDisplayMode: String
        let romanizationDisplayMode: String
        let translationEnabled: Bool
        let romanizationEnabled: Bool
        let duetLayoutEnabled: Bool
        let translationFontScale: Double
        let romanizationFontScale: Double
        let fontSize: Double
        let currentLineScale: Double
        let motionPreset: String
        let interludeMode: String
        let minimumInferredGapDuration: TimeInterval
    }

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let lyrics: [LyricLine]
    let errorMessage: String?
    let highlightedLyricID: LyricLine.ID?
    let isActive: Bool
    let isInterfaceHidden: Bool
    let bottomOverlayHeight: CGFloat
    let onInterfaceInteraction: (() -> Void)?
    let onInterfaceVisibilityChange: ((Bool) -> Void)?
    let onInitialFocusPrepared: (() -> Void)?
    private let lyricIndexByID: [LyricLine.ID: Int]
    private let hasSyllableSyncedLyrics: Bool
    private let hasTranslations: Bool
    private let hasRomanizations: Bool
    private let interludeCandidates: [LyricInterlude]

    // The coordinator publishes only vocal-boundary changes, keeping the
    // scrolling hierarchy independent of the player's progress ticks.
    @State private var activePlaybackLyricIDs: Set<LyricLine.ID> = []

    @State private var scrollPositionID: LyricLine.ID?
    @State private var isBrowsingLyrics = false
    @State private var browsingGeneration = 0
    @State private var followRequest: LyricFollowRequest?
    @State private var playbackFocusRequestGeneration = 0
    @State private var isPreparingInitialFocus = true
    @State private var visualHighlightedLyricID: LyricLine.ID?
    @State private var lyricFocusColorTransition:
        LyricFocusColorTransition?
    @State private var visualCascadeFocusLyricID: LyricLine.ID?
    @State private var lyricGeometryCache =
        AppleMusicLyricsGeometryCache()
    @State private var lyricLayoutRevision = 0
    @State private var lyricMovementOffsetByID: [LyricLine.ID: CGFloat] = [:]
    @State private var lyricMovementTransition: LyricMovementTransition?
    @State private var retainedCascadeLyrics: [RetainedCascadeLyric] = []
    @State private var retainedInterlude:
        AppleMusicRetainedInterludePresentation?
    @State private var playbackFocus: AppleMusicLyricsPlaybackFocus?
    @State private var visibleInterludeID: LyricInterlude.ID?
    @State private var isManuallyScrolling = false
    @State private var interfaceVisibilityTracker =
        LyricsScrollInterfaceVisibilityTracker()
    @State private var hiddenInterfaceProgress: CGFloat
    @State private var lyricSharePresentation: LyricSharePresentation?
    @State private var seekFeedback: LyricSeekFeedback?

    init(
        lyrics: [LyricLine],
        errorMessage: String?,
        highlightedLyricID: LyricLine.ID?,
        isActive: Bool = true,
        isInterfaceHidden: Bool = false,
        bottomOverlayHeight: CGFloat = 0,
        onInterfaceInteraction: (() -> Void)? = nil,
        onInterfaceVisibilityChange: ((Bool) -> Void)? = nil,
        onInitialFocusPrepared: (() -> Void)? = nil
    ) {
        self.lyrics = lyrics
        self.errorMessage = errorMessage
        self.highlightedLyricID = highlightedLyricID
        self.isActive = isActive
        self.isInterfaceHidden = isInterfaceHidden
        self.bottomOverlayHeight = bottomOverlayHeight
        self.onInterfaceInteraction = onInterfaceInteraction
        self.onInterfaceVisibilityChange = onInterfaceVisibilityChange
        self.onInitialFocusPrepared = onInitialFocusPrepared
        lyricIndexByID = Dictionary(
            uniqueKeysWithValues: lyrics.enumerated().map { index, line in
                (line.id, index)
            }
        )
        hasSyllableSyncedLyrics = lyrics.contains {
            $0.isSyllableSynced
        }
        hasTranslations = lyrics.contains { $0.hasTranslation }
        hasRomanizations = lyrics.contains { $0.hasRomanization }
        interludeCandidates = LyricInterludeTimeline.candidates(in: lyrics)
        _scrollPositionID = State(initialValue: highlightedLyricID)
        _visualHighlightedLyricID = State(initialValue: highlightedLyricID)
        _visualCascadeFocusLyricID = State(initialValue: highlightedLyricID)
        _playbackFocus = State(
            initialValue: highlightedLyricID.map {
                AppleMusicLyricsPlaybackFocus.lyric($0)
            }
        )
        _hiddenInterfaceProgress = State(
            initialValue: isInterfaceHidden ? 1 : 0
        )
    }

    var body: some View {
        lyricsContent
            .background {
                AppleMusicLyricsFocusCoordinator(
                    lyrics: lyrics,
                    interludes: interludes,
                    isActive: isActive,
                    playbackFocus: $playbackFocus,
                    visibleInterludeID: $visibleInterludeID,
                    activePlaybackLyricIDs: $activePlaybackLyricIDs
                )
            }
            .onChange(of: isInterfaceHidden) { _, isHidden in
                guard isActive else { return }
                withAnimation(
                    NowPlayingInterfaceTransition.interfaceAnimation(
                        isVisible: !isHidden,
                        reducesMotion: accessibilityReduceMotion
                    )
                ) {
                    hiddenInterfaceProgress = isHidden ? 1 : 0
                }
            }
            .onChange(of: isActive) { _, isActive in
                guard isActive else {
                    settleMovementForInactivePage()
                    return
                }
                synchronizeInterfaceVisibility()
                synchronizeFocusWithPlayback()
            }
            .sheet(item: $lyricSharePresentation) { presentation in
                LyricsShareExperienceView(presentation: presentation)
                    .presentationDetents([.large])
            }
    }

    private func synchronizeInterfaceVisibility() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            hiddenInterfaceProgress = isInterfaceHidden ? 1 : 0
        }
    }

    @ViewBuilder
    private var lyricsContent: some View {
        if lyrics.isEmpty {
            if let errorMessage {
                ContentUnavailableView(
                    "ui.lyrics.empty",
                    systemImage: "quote.bubble",
                    description: Text(errorMessage)
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .onTapGesture {
                    onInterfaceInteraction?()
                }
            } else {
                ProgressView("ui.lyrics.loading")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
                    .onTapGesture {
                        onInterfaceInteraction?()
                    }
            }
        } else {
            let blurFocusLyricID =
                visualCascadeFocusLyricID
                ?? highlightedLyricID
            let _ = lyricLayoutRevision
            let focusNeighborIDs = lyricNeighborIDs(around: blurFocusLyricID)
            let focusEffectAnimation = lyricFocusEffectAnimation(
                for: visualHighlightedLyricID
            )
            let visualScaleFocusLyricID =
                seekFeedback?.previousFocusLyricID
                ?? visualCascadeFocusLyricID
            let usesPseudoTiming = settings.lyricsPseudoWordByWord
                && !hasSyllableSyncedLyrics
            let appleMusicMotionProfile =
                settings.appleMusicLyrics.usesAppleMusic26Motion
                    ? AppleMusicLyricsMotionProfile.iOS26_6
                    : nil
            let showsTranslations = settings.lyricsTranslationEnabled
                && hasTranslations
            let showsRomanizations =
                settings.lyricsRomanizationEnabled
                && hasRomanizations
            let showsAnnotations =
                showsRomanizations || showsTranslations
            let retainedCascadeLyricIDs = Set(
                retainedCascadeLyrics.map(\.id)
            )
            let reservesAnnotationSpace = showsAnnotations
            let lineSpacing = CGFloat(
                settings.effectiveAppleMusicLyricsLineSpacing
            )
            let supplementalTextProfile =
                appleMusicMotionProfile == nil
                    ? nil
                    : AppleMusicLyricsSupplementalTextProfile.iOS26_6
            let title3Font = UIFont.systemFont(
                ofSize: UIFont.preferredFont(
                    forTextStyle: .title3
                ).pointSize,
                weight: .bold
            )
            let calloutFont = UIFont.systemFont(
                ofSize: UIFont.preferredFont(
                    forTextStyle: .callout
                ).pointSize,
                weight: .bold
            )
            let romanizationFontSize =
                supplementalTextProfile == nil
                    ? max(
                        CGFloat(
                            resolvedLyricsFontSize
                                * settings.lyricsRomanizationFontScale
                        ),
                        13
                    )
                    : title3Font.pointSize
            let romanizationHeight = showsRomanizations
                ? supplementalTextProfile == nil
                    ? romanizationFontSize * 1.2
                    : title3Font.lineHeight
                : 0
            let translationHeight = showsTranslations
                ? supplementalTextProfile == nil
                    ? CGFloat(
                        resolvedLyricsFontSize
                            * settings.lyricsTranslationFontScale
                            * 1.2
                    )
                    : showsRomanizations
                        ? calloutFont.lineHeight
                        : title3Font.lineHeight
                : 0
            let annotationHeight =
                romanizationHeight
                + translationHeight
                + (
                    showsRomanizations
                        ? CGFloat(
                            supplementalTextProfile?
                                .transliterationSpacing
                                ?? Double(Self.annotationSpacing)
                        )
                        : 0
                )
                + (
                    showsTranslations
                        ? CGFloat(
                            (supplementalTextProfile?
                                .translationSpacing
                                ?? Double(Self.annotationSpacing))
                                + (supplementalTextProfile?
                                    .translationBottomPadding ?? 0)
                        )
                        : 0
                )
            let fallbackLyricStride = max(
                CGFloat(resolvedLyricsFontSize) * 1.2
                    + annotationHeight
                    + lineSpacing,
                1
            )
            let lyricStride = measuredLyricAnchorStride(
                around: blurFocusLyricID,
                lineSpacing: lineSpacing,
                fallback: fallbackLyricStride
            )
            let blurIntensity = appleMusicMotionProfile == nil
                ? CGFloat(settings.lyricsBlurIntensity)
                : 1
            let usesUniformBrowsingDimming =
                isBrowsingLyrics
                    && settings
                        .lyricsUsesUniformDimmingWhileBrowsing
            let bypassesPresetBlurForIncreasedContrast =
                appleMusicMotionProfile != nil
                    && colorSchemeContrast == .increased
            let activeBlurIntensity =
                usesUniformBrowsingDimming
                    || bypassesPresetBlurForIncreasedContrast
                ? 0
                : blurIntensity
            let distanceBlurScale = appleMusicMotionProfile == nil
                ? CGFloat(settings.lyricsDistanceBlurScale)
                : 1
            let hiddenInterfaceBlurScale = appleMusicMotionProfile == nil
                ? CGFloat(settings.lyricsHiddenInterfaceBlurScale)
                : 1
            let activeHiddenInterfaceProgress = min(
                max(hiddenInterfaceProgress, 0),
                1
            )
            let dimAmount = settings.lyricsDimAmount
            let distanceDimAmount = usesUniformBrowsingDimming
                ? 0
                : dimAmount
            let currentLineScale = lyricsCurrentLineScale
            let usesPresetGlow = appleMusicMotionProfile != nil
            let glowOverflow = Self.lyricGlowOverflow(
                isEnabled: (usesPresetGlow || settings.lyricsGlowEnabled)
                    && (
                        (settings.lyricsWordByWord && hasSyllableSyncedLyrics)
                            || usesPseudoTiming
                    ),
                fontSize: resolvedLyricsFontSize,
                intensity:
                    usesPresetGlow
                        ? 1
                        : settings.lyricsGlowIntensity
            )
            let horizontalVisualOverflow = max(
                glowOverflow,
                SynchronizedLyricText
                    .interactionBackgroundVisualOverflow
            )

            GeometryReader { proxy in
                let focusPosition = lyricsFocusPosition(
                    for: proxy.size.height
                )
                let focusAnchorY = proxy.size.height * focusPosition
                let visibleViewportHeight = visibleLyricsViewportHeight(
                    for: proxy.size.height
                )
                let maskLocations = lyricsMaskLocations(
                    for: proxy.size.height
                )
                let lyricLayoutWidth = max(proxy.size.width, 1)
                let bottomContentPadding = max(
                    proxy.size.height * (1 - focusPosition),
                    40
                )
                let topContentPadding = appleMusicMotionProfile.map {
                    CGFloat($0.firstLineStartOffset)
                } ?? max(proxy.size.height * focusPosition, 40)
                let lyricRowContext = LyricRowVisualContext(
                    activePlaybackLyricIDs: activePlaybackLyricIDs,
                    visualScaleFocusLyricID: visualScaleFocusLyricID,
                    precedingFocusLyricID: focusNeighborIDs.preceding,
                    followingFocusLyricID: focusNeighborIDs.following,
                    retainedCascadeLyricIDs: retainedCascadeLyricIDs,
                    usesPseudoTiming: usesPseudoTiming,
                    romanizationFontSize: romanizationFontSize,
                    reservesAnnotationSpace: reservesAnnotationSpace,
                    currentLineScale: currentLineScale,
                    lyricLayoutWidth: lyricLayoutWidth,
                    focusAnchorY: focusAnchorY,
                    hiddenInterfaceProgress: activeHiddenInterfaceProgress,
                    distanceBlurScale: distanceBlurScale,
                    hiddenInterfaceBlurScale: hiddenInterfaceBlurScale,
                    viewportHeight: proxy.size.height,
                    lyricStride: lyricStride,
                    activeBlurIntensity: activeBlurIntensity,
                    motionProfile: appleMusicMotionProfile,
                    distanceDimAmount: distanceDimAmount,
                    dimAmount: dimAmount,
                    focusEffectAnimation: focusEffectAnimation
                )
                let scrollPresentationContext =
                    LyricScrollPresentationContext(
                        viewportSize: proxy.size,
                        focusPosition: focusPosition,
                        maskTopOpaque: maskLocations.topOpaque,
                        maskBottomOpaque: maskLocations.bottomOpaque,
                        maskBottomClear: maskLocations.bottomClear,
                        horizontalVisualOverflow:
                            horizontalVisualOverflow,
                        row: lyricRowContext
                    )

                let baseScrollView = ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: lineSpacing
                    ) {
                        ForEach(displayItems) { item in
                            if case let .interlude(interlude) = item {
                                AppleMusicLyricInterludeView(
                                    interlude: interlude,
                                    isVisible:
                                        visibleInterludeID == interlude.id
                                        && retainedInterlude?.interlude.id
                                            != interlude.id,
                                    isAnimationActive: isActive,
                                    advanceTime:
                                        effectiveLyricsAdvanceTime,
                                    onInterfaceInteraction:
                                        onInterfaceInteraction
                                )
                                .id(interlude.id)
                                .onGeometryChange(for: CGRect.self) {
                                    geometry in
                                    geometry.frame(
                                        in: .scrollView(axis: .vertical)
                                    )
                                } action: { frame in
                                    recordInterludeGeometry(
                                        frame,
                                        for: interlude.id
                                    )
                                }
                                .onDisappear {
                                    lyricGeometryCache.removeInterlude(
                                        interlude.id
                                    )
                                }
                            }

                            if case let .lyric(line) = item {
                                lyricRow(
                                    line,
                                    context: lyricRowContext
                                )
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.top, topContentPadding)
                    .padding(.bottom, bottomContentPadding)
                    .overlay(alignment: .bottom) {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: bottomContentPadding)
                            .contentShape(.rect)
                            .onTapGesture {
                                onInterfaceInteraction?()
                            }
                            .accessibilityHidden(true)
                    }
                    .overlay(alignment: .top) {
                        hiddenControlsTapTarget(
                            viewportHeight: proxy.size.height
                        )
                    }
                }
                let presentedScrollView = lyricScrollPresentation(
                    baseScrollView,
                    context: scrollPresentationContext
                )
                let interactiveScrollView = lyricScrollInteractions(
                    presentedScrollView
                )
                lyricScrollLifecycle(
                    interactiveScrollView,
                    viewportWidth: proxy.size.width,
                    viewportHeight: proxy.size.height,
                    visibleViewportHeight: visibleViewportHeight
                )
            }
        }
    }

    private func lyricRow(
        _ line: LyricLine,
        context: LyricRowVisualContext
    ) -> some View {
        let isPlaybackLine = line.id == visualHighlightedLyricID
        let isCascadeFocusLine = line.id == visualCascadeFocusLyricID
        let isVisualScaleFocusLine =
            line.id == context.visualScaleFocusLyricID
        let isActualPlaybackLine =
            context.activePlaybackLyricIDs.contains(line.id)
        let isActiveIndependentVocalLine =
            isActualPlaybackLine
            && !isPlaybackLine
            && line.agent?.alignment == .flipped
        let isRetainedCascadeLine =
            context.retainedCascadeLyricIDs.contains(line.id)
        let showsTranslation = showsLyricTranslation(
            isFocusedLine: isCascadeFocusLine
        )
        let showsRomanization = showsLyricRomanization(
            isFocusedLine: isCascadeFocusLine
        )
        let movementPhase = lyricMovementPhase(for: line.id)
        let focusBlurRadius = Self.lyricFocusBlurRadius(
            intensity: context.activeBlurIntensity,
            isPrecedingFocusLine:
                line.id == context.precedingFocusLyricID,
            isFollowingFocusLine:
                line.id == context.followingFocusLyricID,
            motionProfile: context.motionProfile
        )
        let focusScaleAnimation = lyricFocusScaleAnimation(
            isFocused: isVisualScaleFocusLine
        )

        return LyricRowPresentationTimeline(
            lyricID: line.id,
            focusedLyricID: visualHighlightedLyricID,
            movementPhase: movementPhase,
            focusTransition: lyricFocusColorTransition,
            isActive: isActive
        ) { movementOffset, focusProgress in
            LyricPressInteraction(
                isSelected:
                    seekFeedback?.lyricID == line.id
                    || lyricSharePresentation?.initialLyricID
                        == line.id,
                allowsTap: settings.lyricsTapToSeek,
                allowsLongPress:
                    settings.lyricsLongPressToShare
                    && line.text.count
                        <= LyricsSelectionManager
                            .defaultCharacterLimit,
                onTap: {
                    if !isInterfaceHidden {
                        onInterfaceInteraction?()
                    }
                    seek(to: line)
                },
                onLongPress: {
                    presentShare(for: line)
                }
            ) { interactionBackgroundProgress in
                SynchronizedLyricText(
                    line: line,
                    isPlaybackLine: isPlaybackLine,
                    isVocalActive: isActualPlaybackLine,
                    isAnimationActive: isActive,
                    playbackFocusProgress: focusProgress.color,
                    usesPseudoTiming: context.usesPseudoTiming,
                    fontSize: CGFloat(resolvedLyricsFontSize),
                    romanizationFontSize:
                        context.romanizationFontSize,
                    fontWeight: resolvedLyricsFontWeight,
                    alignment: .resolved(
                        for: line,
                        duetLayoutEnabled:
                            settings.lyricsDuetLayoutEnabled
                    ),
                    primaryColor: .white,
                    showsTranslation: showsTranslation,
                    showsRomanization:
                        settings.lyricsRomanizationEnabled
                        && showsRomanization,
                    includesRomanization: true,
                    reservesAnnotationSpace:
                        context.reservesAnnotationSpace,
                    onAnnotationHeightChange: { height in
                        recordAnnotationHeight(height, for: line.id)
                    },
                    annotationLayoutAnimation:
                        lyricAnnotationLayoutAnimation(),
                    annotationVisibilityAnimation:
                        lyricAnnotationVisibilityAnimation(
                            focusScaleAnimation: focusScaleAnimation
                        ),
                    interactionBackgroundOpacity:
                        0.12 * interactionBackgroundProgress,
                    visualScale: lyricVisualScale(
                        isFocused: isVisualScaleFocusLine,
                        focusedScale: context.currentLineScale,
                        motionProfile: context.motionProfile
                    ),
                    visualScaleAnimation: focusScaleAnimation,
                    promotedLayoutScale:
                        context.motionProfile == nil
                            ? context.currentLineScale
                            : 1,
                    layoutWidth: context.lyricLayoutWidth,
                    motionProfile: context.motionProfile,
                    suppressesTimedGlyphBlur:
                        context.motionProfile != nil
                            && colorSchemeContrast == .increased
                )
            }
            .opacity(
                isRetainedCascadeLine
                    ? 0
                    : isActiveIndependentVocalLine
                        ? 1
                    : context.motionProfile == nil
                        ? Self.lyricEmphasis(
                            focusProgress: focusProgress.color,
                            isBrowsingFocus: false,
                            dimAmount: context.dimAmount
                        )
                        : Self.appleMusicLyricFocusOpacity(
                            focusProgress: focusProgress.color,
                            motionProfile: context.motionProfile,
                            usesIncreasedContrast:
                                colorSchemeContrast == .increased
                        )
            )
            .contentShape(.rect)
            .visualEffect { content, geometry in
                let frame = geometry.frame(
                    in: .scrollView(axis: .vertical)
                )
                let visualMidY = frame.midY + movementOffset
                let distance = Self.lyricVisualDistance(
                    visualMidY: visualMidY,
                    focusAnchorY: context.focusAnchorY,
                    expandedBottomProgress:
                        context.hiddenInterfaceProgress
                )
                let activeDistanceBlurScale =
                    context.distanceBlurScale
                    + (
                        context.hiddenInterfaceBlurScale
                            - context.distanceBlurScale
                    ) * context.hiddenInterfaceProgress
                let bottomRevealOpacity =
                    Self.lyricBottomRevealOpacity(
                        frame: frame,
                        movementOffset: movementOffset,
                        viewportHeight: context.viewportHeight
                    )
                let distanceOpacity: CGFloat =
                    if isActiveIndependentVocalLine {
                        1
                    } else if context.motionProfile == nil {
                        Self.lyricOpacity(
                            forPixelDistance: distance,
                            lyricStride: context.lyricStride,
                            dimAmount: context.distanceDimAmount,
                            focusProgress: focusProgress.color
                        )
                    } else {
                        1
                    }
                return content
                    .blur(
                        radius: isActiveIndependentVocalLine
                            ? 0
                            : Self.lyricDistanceBlurRadius(
                                forPixelDistance: distance,
                                lyricStride: context.lyricStride,
                                intensity:
                                    context.activeBlurIntensity
                                    * activeDistanceBlurScale,
                                focusProgress: focusProgress.blur,
                                motionProfile: context.motionProfile
                            )
                    )
                    .opacity(
                        distanceOpacity * bottomRevealOpacity
                    )
                    .offset(y: movementOffset)
            }
            .blur(
                radius:
                    isActiveIndependentVocalLine
                        ? 0
                        : focusBlurRadius
            )
            .animation(
                context.focusEffectAnimation,
                value: focusBlurRadius
            )
        }
        .onGeometryChange(for: LyricGeometryMeasurement.self) { geometry in
            LyricGeometryMeasurement(
                frame: geometry.frame(
                    in: .scrollView(axis: .vertical)
                ),
                layoutHeight: geometry.size.height
            )
        } action: { measurement in
            recordLyricGeometry(measurement, for: line.id)
        }
        .id(line.id)
        .onDisappear {
            lyricGeometryCache.remove(line.id)
        }
        .accessibilityLabel(
            line.accessibilityText(
                includingTranslation:
                    settings.lyricsTranslationEnabled
                    && showsLyricTranslation(
                        isFocusedLine: isActualPlaybackLine
                    ),
                includingRomanization:
                    settings.lyricsRomanizationEnabled
                    && showsLyricRomanization(
                        isFocusedLine: isActualPlaybackLine
                    )
            )
        )
        .accessibilityValue(
            lyricAccessibilityValue(
                isPlaybackLine: isActualPlaybackLine,
                isBrowsingFocus: false
            )
        )
        .accessibilityHint(
            lyricInteractionAccessibilityHint(
                allowsShare:
                    line.text.count
                    <= LyricsSelectionManager.defaultCharacterLimit
            )
        )
        .accessibilityAddTraits(
            settings.lyricsTapToSeek ? .isButton : []
        )
        .accessibilityAction {
            seek(to: line)
        }
    }

    private func lyricScrollPresentation<Content: View>(
        _ content: Content,
        context: LyricScrollPresentationContext
    ) -> some View {
        content
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollPosition(
                id: $scrollPositionID,
                anchor: UnitPoint(x: 0.5, y: context.focusPosition)
            )
            .transaction { transaction in
                if isPreparingInitialFocus {
                    transaction.animation = nil
                }
            }
            .overlay(alignment: .topLeading) {
                retainedCascadeLyricsOverlay(
                    viewportSize: context.viewportSize,
                    lyricLayoutWidth: context.row.lyricLayoutWidth,
                    focusPosition: context.focusPosition,
                    lyricStride: context.row.lyricStride,
                    blurIntensity: context.row.activeBlurIntensity,
                    distanceBlurScale: context.row.distanceBlurScale,
                    hiddenInterfaceBlurScale:
                        context.row.hiddenInterfaceBlurScale,
                    dimAmount: context.row.dimAmount,
                    distanceDimAmount: context.row.distanceDimAmount,
                    currentLineScale: context.row.currentLineScale,
                    usesPseudoTiming: context.row.usesPseudoTiming,
                    motionProfile: context.row.motionProfile,
                    focusEffectAnimation:
                        context.row.focusEffectAnimation
                )
            }
            .overlay(alignment: .topLeading) {
                if let retainedInterlude {
                    AppleMusicRetainedInterludeOverlay(
                        presentation: retainedInterlude,
                        isAnimationActive: isActive,
                        advanceTime: effectiveLyricsAdvanceTime,
                        onFinished: finishRetainedInterlude
                    )
                }
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(
                            color: .black,
                            location: context.maskTopOpaque
                        ),
                        .init(
                            color: .black,
                            location: context.maskBottomOpaque
                        ),
                        .init(
                            color: .clear,
                            location: context.maskBottomClear
                        ),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(
                    width:
                        context.viewportSize.width
                        + context.horizontalVisualOverflow * 2
                )
            }
    }

    private func lyricScrollInteractions<Content: View>(
        _ content: Content
    ) -> some View {
        content
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                    Self.normalizedScrollOffset(for: geometry)
                }
            ) { oldOffset, newOffset in
                handleManualScrollOffsetChange(
                    from: oldOffset,
                    to: newOffset
                )
            }
            .onScrollPhaseChange { _, newPhase in
                handleLyricsScrollPhase(newPhase)
            }
            .onChange(of: highlightedLyricID) { _, newValue in
                handleHighlightedLyricChange(newValue)
            }
            .onChange(of: lyricLayoutSettingsSignature) {
                oldSignature,
                newSignature in
                handleLyricLayoutSettingsChange(
                    from: oldSignature,
                    to: newSignature
                )
            }
            .onChange(of: settings.lyricsAutoFollow) { _, isEnabled in
                handleAutoFollowSettingChange(isEnabled)
            }
            .onChange(of: settings.lyricsFollowDelay) { _, _ in
                handleFollowDelayChange()
            }
            .onChange(of: player.seekRevision) { _, newRevision in
                handleSeekRevisionChange(newRevision)
            }
            .onChange(of: player.isPlaying) { wasPlaying, isPlaying in
                handlePlaybackStateChange(
                    wasPlaying: wasPlaying,
                    isPlaying: isPlaying
                )
            }
    }

    private func lyricScrollLifecycle<Content: View>(
        _ content: Content,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat,
        visibleViewportHeight: CGFloat
    ) -> some View {
        content
            .onAppear {
                synchronizeFocusWithPlayback()
            }
            .task(id: focusMovementTrigger) {
                await performFocusMovement(
                    viewportWidth: viewportWidth,
                    viewportHeight: viewportHeight,
                    visibleViewportHeight: visibleViewportHeight
                )
            }
            .task(id: seekFeedback) {
                await holdSeekFeedbackUntilFocusCompletes(
                    viewportHeight: viewportHeight
                )
            }
            .task(id: followRequest) {
                await performPlaybackFollowingRequest()
            }
            .task(id: lyricFocusColorTransition?.id) {
                await finishPendingFocusColorTransition()
            }
            .onDisappear {
                handleLyricsDisappear()
            }
    }

    private static func normalizedScrollOffset(
        for geometry: ScrollGeometry
    ) -> CGFloat {
        let normalizedOffset =
            geometry.contentOffset.y + geometry.contentInsets.top
        let maximumOffset = max(
            geometry.contentSize.height
                + geometry.contentInsets.top
                + geometry.contentInsets.bottom
                - geometry.containerSize.height,
            0
        )
        return min(max(normalizedOffset, 0), maximumOffset)
    }

    private var lyricLayoutSettingsSignature:
        LyricLayoutSettingsSignature {
        let usesExactSupplementalLayout =
            settings.appleMusicLyricsMotionProfile != nil
        return LyricLayoutSettingsSignature(
            translationDisplayMode:
                usesExactSupplementalLayout
                    ? LyricsTranslationDisplayMode.allLines.rawValue
                    : settings.lyricsTranslationDisplayMode.rawValue,
            romanizationDisplayMode:
                usesExactSupplementalLayout
                    ? LyricsTranslationDisplayMode.allLines.rawValue
                    : settings.lyricsRomanizationDisplayMode.rawValue,
            translationEnabled: settings.lyricsTranslationEnabled,
            romanizationEnabled: settings.lyricsRomanizationEnabled,
            duetLayoutEnabled: settings.lyricsDuetLayoutEnabled,
            translationFontScale:
                usesExactSupplementalLayout
                    ? 1
                    : settings.lyricsTranslationFontScale,
            romanizationFontScale:
                usesExactSupplementalLayout
                    ? 1
                    : settings.lyricsRomanizationFontScale,
            fontSize: resolvedLyricsFontSize,
            currentLineScale: settings.lyricsCurrentLineScale,
            motionPreset:
                settings.appleMusicLyrics.motionPreset.rawValue,
            interludeMode: settings.lyricsInterlude.mode.rawValue,
            minimumInferredGapDuration:
                settings.lyricsInterlude.minimumInferredGapDuration
        )
    }

    private func handleLyricsScrollPhase(_ phase: ScrollPhase) {
        switch phase {
        case .tracking, .interacting:
            followRequest = nil
            if let seekFeedback {
                completeSeekFeedback(seekFeedback)
            }
            if !isManuallyScrolling {
                isManuallyScrolling = true
                interfaceVisibilityTracker.begin(
                    isInterfaceVisible: !isInterfaceHidden
                )
            }
            browsingGeneration += 1
            resetMovementOffsets()
            isBrowsingLyrics = true
        case .idle:
            isManuallyScrolling = false
            interfaceVisibilityTracker.end()
            schedulePlaybackFollowing()
        case .decelerating, .animating:
            break
        }
    }

    private func handleLyricLayoutSettingsChange(
        from oldSignature: LyricLayoutSettingsSignature,
        to newSignature: LyricLayoutSettingsSignature
    ) {
        resetMovementOffsets()
        let interludeLayoutChanged =
            oldSignature.interludeMode != newSignature.interludeMode
            || oldSignature.minimumInferredGapDuration
                != newSignature.minimumInferredGapDuration
        guard interludeLayoutChanged else { return }

        lyricGeometryCache.removeAll()
        lyricLayoutRevision += 1
        if visibleInterludeID.flatMap({ interludeByID[$0] }) == nil {
            visibleInterludeID = nil
        }
        if retainedInterlude.flatMap({
            interludeByID[$0.interlude.id]
        }) == nil {
            retainedInterlude = nil
        }
        requestPlaybackFocus()
    }

    private func handleHighlightedLyricChange(
        _ highlightedLyricID: LyricLine.ID?
    ) {
        guard highlightedLyricID == nil else { return }
        startFocusColorTransition(to: nil)
        visualCascadeFocusLyricID = nil
        lyricMovementOffsetByID.removeAll()
        lyricMovementTransition = nil
        retainedCascadeLyrics.removeAll()
    }

    private func handleAutoFollowSettingChange(_ isEnabled: Bool) {
        if isEnabled, isBrowsingLyrics, !isManuallyScrolling {
            schedulePlaybackFollowing()
        } else {
            followRequest = nil
        }
    }

    private func handleFollowDelayChange() {
        if isBrowsingLyrics, !isManuallyScrolling {
            schedulePlaybackFollowing()
        }
    }

    private func handleSeekRevisionChange(_ revision: Int) {
        guard seekFeedback?.playerSeekRevision != revision else { return }
        requestPlaybackFocus()
    }

    private func handlePlaybackStateChange(
        wasPlaying: Bool,
        isPlaying: Bool
    ) {
        guard !wasPlaying, isPlaying else { return }
        requestPlaybackFocus()
    }

    private func performFocusMovement(
        viewportWidth: CGFloat,
        viewportHeight: CGFloat,
        visibleViewportHeight: CGFloat
    ) async {
        guard isActive else { return }
        let preparesInitialFocus = isPreparingInitialFocus
        await cascadeMoveFocus(
            to: requestedFocusLyricID,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            visibleViewportHeight: visibleViewportHeight,
            customPreloadLineCount: Self.customBottomPreloadLineCount
        )
        guard !Task.isCancelled else { return }
        isPreparingInitialFocus = false
        if preparesInitialFocus {
            onInitialFocusPrepared?()
        }
    }

    private func handleLyricsDisappear() {
        browsingGeneration += 1
        followRequest = nil
        isManuallyScrolling = false
        interfaceVisibilityTracker.end()
        seekFeedback = nil
        lyricGeometryCache.removeAll()
        lyricMovementOffsetByID.removeAll()
        lyricMovementTransition = nil
        lyricFocusColorTransition = nil
        retainedCascadeLyrics.removeAll()
        visibleInterludeID = nil
    }

    private func settleMovementForInactivePage() {
        let focusID = playbackFocus?.lyricID
            ?? highlightedLyricID
            ?? visualCascadeFocusLyricID
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visualCascadeFocusLyricID = focusID
            lyricMovementOffsetByID = focusedLineFollowingOffsets(
                for: focusID
            )
            lyricMovementTransition = nil
            retainedCascadeLyrics.removeAll()
        }
    }

    private func finishPendingFocusColorTransition() async {
        guard let transition = lyricFocusColorTransition else { return }
        await finishFocusColorTransition(transition)
    }

    @ViewBuilder
    private func hiddenControlsTapTarget(
        viewportHeight: CGFloat
    ) -> some View {
        let tapHeight = min(
            max(bottomOverlayHeight, 0),
            max(viewportHeight, 0)
        )

        if isInterfaceHidden, tapHeight > 0 {
            GeometryReader { geometry in
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: tapHeight)
                    .contentShape(.rect)
                    .offset(
                        y:
                            -geometry.frame(
                                in: .scrollView(axis: .vertical)
                            ).minY
                            + max(viewportHeight - tapHeight, 0)
                    )
                    .onTapGesture {
                        onInterfaceInteraction?()
                    }
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func retainedCascadeLyricsOverlay(
        viewportSize: CGSize,
        lyricLayoutWidth: CGFloat,
        focusPosition: CGFloat,
        lyricStride: CGFloat,
        blurIntensity: CGFloat,
        distanceBlurScale: CGFloat,
        hiddenInterfaceBlurScale: CGFloat,
        dimAmount: Double,
        distanceDimAmount: Double,
        currentLineScale: CGFloat,
        usesPseudoTiming: Bool,
        motionProfile: AppleMusicLyricsMotionProfile?,
        focusEffectAnimation: Animation?
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(retainedCascadeLyrics) { retainedLyric in
                if let lineIndex = lyricIndexByID[retainedLyric.id],
                   lyrics.indices.contains(lineIndex) {
                    let line = lyrics[lineIndex]
                    let isPlaybackLine = line.id == visualHighlightedLyricID
                    let isCascadeFocusLine = line.id == visualCascadeFocusLyricID
                    let visualScaleFocusLyricID =
                        seekFeedback?.previousFocusLyricID
                        ?? visualCascadeFocusLyricID
                    let isVisualScaleFocusLine =
                        line.id == visualScaleFocusLyricID
                    let showsTranslation = showsLyricTranslation(
                        isFocusedLine: isCascadeFocusLine
                    )
                    let showsRomanization = showsLyricRomanization(
                        isFocusedLine: isCascadeFocusLine
                    )
                    let blurFocusLyricID =
                        visualCascadeFocusLyricID
                        ?? highlightedLyricID
                    let focusNeighborIDs = lyricNeighborIDs(around: blurFocusLyricID)
                    let movementPhase = lyricMovementPhase(for: line.id)
                    let focusBlurRadius = Self.lyricFocusBlurRadius(
                        intensity: blurIntensity,
                        isPrecedingFocusLine: line.id == focusNeighborIDs.preceding,
                        isFollowingFocusLine: line.id == focusNeighborIDs.following,
                        motionProfile: motionProfile
                    )
                    let focusScaleAnimation = lyricFocusScaleAnimation(
                        isFocused: isVisualScaleFocusLine
                    )

                    LyricRowPresentationTimeline(
                        lyricID: line.id,
                        focusedLyricID: visualHighlightedLyricID,
                        movementPhase: movementPhase,
                        focusTransition: lyricFocusColorTransition,
                        isActive: isActive
                    ) { movementOffset, focusProgress in
                        let visualOffset =
                            movementOffset
                            - retainedLyric.movementDistance
                        let visualMidY =
                            retainedLyric.frame.midY + visualOffset
                        let focusAnchorY =
                            viewportSize.height * focusPosition
                        let distance = Self.lyricVisualDistance(
                            visualMidY: visualMidY,
                            focusAnchorY: focusAnchorY,
                            expandedBottomProgress:
                                hiddenInterfaceProgress
                        )
                        let activeDistanceBlurScale =
                            distanceBlurScale
                            + (
                                hiddenInterfaceBlurScale
                                    - distanceBlurScale
                            ) * hiddenInterfaceProgress

                        SynchronizedLyricText(
                            line: line,
                            isPlaybackLine: isPlaybackLine,
                            isAnimationActive: isActive,
                            playbackFocusProgress:
                                focusProgress.color,
                            usesPseudoTiming: usesPseudoTiming,
                            fontSize: CGFloat(
                                resolvedLyricsFontSize
                            ),
                            romanizationFontSize:
                                lyricRomanizationFontSize,
                            fontWeight: resolvedLyricsFontWeight,
                            alignment: .resolved(
                                for: line,
                                duetLayoutEnabled:
                                    settings.lyricsDuetLayoutEnabled
                            ),
                            showsTranslation: showsTranslation,
                            showsRomanization:
                                settings.lyricsRomanizationEnabled
                                && showsRomanization,
                            includesRomanization: true,
                            reservesAnnotationSpace:
                                (
                                    settings
                                        .lyricsRomanizationEnabled
                                        && hasRomanizations
                                ) || (
                                    settings
                                        .lyricsTranslationEnabled
                                        && hasTranslations
                                ),
                            annotationLayoutAnimation:
                                lyricAnnotationLayoutAnimation(),
                            annotationVisibilityAnimation:
                                lyricAnnotationVisibilityAnimation(
                                    focusScaleAnimation:
                                        focusScaleAnimation
                                ),
                            visualScale:
                                lyricVisualScale(
                                    isFocused:
                                        isVisualScaleFocusLine,
                                    focusedScale:
                                        currentLineScale,
                                    motionProfile:
                                        motionProfile
                                ),
                            visualScaleAnimation:
                                focusScaleAnimation,
                            promotedLayoutScale:
                                motionProfile == nil
                                    ? currentLineScale
                                    : 1,
                            layoutWidth: lyricLayoutWidth,
                            motionProfile: motionProfile,
                            suppressesTimedGlyphBlur:
                                motionProfile != nil
                                    && colorSchemeContrast
                                        == .increased
                        )
                        .opacity(
                            motionProfile == nil
                                ? Self.lyricEmphasis(
                                    focusProgress:
                                        focusProgress.color,
                                    isBrowsingFocus: false,
                                    dimAmount: dimAmount
                                )
                                : Self.appleMusicLyricFocusOpacity(
                                    focusProgress:
                                        focusProgress.color,
                                    motionProfile: motionProfile,
                                    usesIncreasedContrast:
                                        colorSchemeContrast
                                            == .increased
                                )
                        )
                        .blur(
                            radius:
                                Self.lyricDistanceBlurRadius(
                                    forPixelDistance: distance,
                                    lyricStride: lyricStride,
                                    intensity:
                                        blurIntensity
                                            * activeDistanceBlurScale,
                                    focusProgress:
                                        focusProgress.blur,
                                    motionProfile: motionProfile
                                )
                        )
                        .opacity(
                            (
                                motionProfile == nil
                                    ? Self.lyricOpacity(
                                        forPixelDistance: distance,
                                        lyricStride: lyricStride,
                                        dimAmount:
                                            distanceDimAmount,
                                        focusProgress:
                                            focusProgress.color
                                    )
                                    : 1
                            ) * Self.lyricBottomRevealOpacity(
                                frame: retainedLyric.frame,
                                movementOffset: visualOffset,
                                viewportHeight: viewportSize.height
                            )
                        )
                        .blur(radius: focusBlurRadius)
                        .animation(
                            focusEffectAnimation,
                            value: focusBlurRadius
                        )
                        .frame(
                            width: viewportSize.width,
                            alignment: .leading
                        )
                        .offset(
                            y:
                                retainedLyric.frame.minY
                                + visualOffset
                        )
                    }

                }
            }
        }
        .frame(
            width: viewportSize.width,
            height: viewportSize.height,
            alignment: .topLeading
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var preferredLyricsFocusPosition: CGFloat {
        if let profile = settings.appleMusicLyricsMotionProfile {
            return CGFloat(
                profile.selectedLineTopRelativePercent / 100
            )
        }
        return CGFloat(
            min(
                max(
                    settings.lyricsFocusPosition,
                    AppSettings.lyricsFocusPositionRange.lowerBound
                ),
                AppSettings.lyricsFocusPositionRange.upperBound
            )
        )
    }

    private var resolvedLyricsFontSize: Double {
        settings.effectiveAppleMusicLyricsPrimaryFontSize
    }

    private var resolvedLyricsFontWeight: LyricsFontWeight {
        settings.appleMusicLyricsTypographyProfile == nil
            ? settings.lyricsFontWeight
            : .bold
    }

    private var interludeDetectionPolicy: LyricInterludeDetectionPolicy? {
        switch settings.lyricsInterlude.mode {
        case .hidden:
            nil
        case .preciseTiming:
            .preciseTiming
        case .automatic:
            .automatic(
                minimumInferredGapDuration:
                    settings.lyricsInterlude.minimumInferredGapDuration
            )
        }
    }

    private var interludes: [LyricInterlude] {
        guard let interludeDetectionPolicy else { return [] }
        return LyricInterludeTimeline.interludes(
            from: interludeCandidates,
            detectionPolicy: interludeDetectionPolicy
        )
    }

    private var interludeByID: [LyricInterlude.ID: LyricInterlude] {
        Dictionary(uniqueKeysWithValues: interludes.map { ($0.id, $0) })
    }

    private var displayItems: [AppleMusicLyricsDisplayItem] {
        let interludeByDisplayLyricID = interludes.reduce(into: [:]) {
            result,
            interlude in
            result[interlude.displayBeforeLyricID] = interlude
        }
        return lyrics.flatMap { line -> [AppleMusicLyricsDisplayItem] in
            guard let interlude = interludeByDisplayLyricID[line.id] else {
                return [.lyric(line)]
            }
            return [.interlude(interlude), .lyric(line)]
        }
    }

    private var playbackInterlude: LyricInterlude? {
        guard let interludeID = playbackFocus?.interludeID else {
            return nil
        }
        return interludeByID[interludeID]
    }

    private var focusedInterlude: LyricInterlude? {
        guard seekFeedback == nil else { return nil }
        return playbackInterlude
    }

    private func lyricsFocusPosition(for viewportHeight: CGFloat) -> CGFloat {
        guard viewportHeight > 0 else { return preferredLyricsFocusPosition }
        let referenceHeight = referenceLyricsViewportHeight(
            for: viewportHeight
        )
        guard let profile = settings.appleMusicLyricsMotionProfile else {
            return preferredLyricsFocusPosition
                * referenceHeight
                / viewportHeight
        }

        // Native LyricsSpecs.topRelative(12) first derives the scroll inset
        // from the complete lyrics viewport, then subtracts the lyric ascender.
        // SwiftUI's scrollPosition anchor aligns the same unit point in the
        // row and viewport, so solve that alignment for the row's top edge.
        let font = UIFont.systemFont(
            ofSize: CGFloat(resolvedLyricsFontSize),
            weight: resolvedLyricsFontWeight.uiKitWeight
        )
        let focusedID = requestedFocusLyricID
            ?? visualCascadeFocusLyricID
            ?? highlightedLyricID
        let focusedHeight = focusedID.flatMap {
            lyricGeometryCache.frames[$0]?.height
                ?? lyricGeometryCache.layoutHeights[$0]
        } ?? font.lineHeight
        let targetTop = viewportHeight
            * CGFloat(profile.selectedLineTopRelativePercent / 100)
            - font.ascender
        let availableAnchorTravel = max(
            viewportHeight - max(focusedHeight, 0),
            1
        )
        return min(max(targetTop / availableAnchorTravel, 0), 1)
    }

    private func referenceLyricsViewportHeight(
        for viewportHeight: CGFloat
    ) -> CGFloat {
        let overlayHeight = min(
            max(bottomOverlayHeight, 0),
            max(viewportHeight - 1, 0)
        )
        return max(viewportHeight - overlayHeight, 1)
    }

    private func visibleLyricsViewportHeight(
        for viewportHeight: CGFloat
    ) -> CGFloat {
        isInterfaceHidden
            ? viewportHeight
            : referenceLyricsViewportHeight(for: viewportHeight)
    }

    private func lyricsMaskLocations(
        for viewportHeight: CGFloat
    ) -> (
        topOpaque: CGFloat,
        bottomOpaque: CGFloat,
        bottomClear: CGFloat
    ) {
        guard viewportHeight > 0 else { return (0.08, 0.84, 1) }
        let referenceRatio = referenceLyricsViewportHeight(for: viewportHeight)
            / viewportHeight
        let progress = min(max(hiddenInterfaceProgress, 0), 1)
        let collapseStart: CGFloat = 0.68
        let normalizedCollapse = min(
            max(
                (progress - collapseStart)
                    / (1 - collapseStart),
                0
            ),
            1
        )
        let collapseProgress =
            normalizedCollapse
            * normalizedCollapse
            * (3 - 2 * normalizedCollapse)
        let bottomClear =
            referenceRatio
            + (1 - referenceRatio) * collapseProgress
        let shownFadeHeight = 0.16 * referenceRatio
        let hiddenFadeHeight: CGFloat = 0.08
        let fadeHeight =
            shownFadeHeight
            + (hiddenFadeHeight - shownFadeHeight)
                * collapseProgress
        return (
            topOpaque: 0.08 * referenceRatio,
            bottomOpaque: bottomClear - fadeHeight,
            bottomClear: bottomClear
        )
    }

    private var lyricsCurrentLineScale: CGFloat {
        CGFloat(
            min(
                max(
                    settings.effectiveAppleMusicLyricsCurrentLineScale,
                    AppSettings.lyricsCurrentLineScaleRange.lowerBound
                ),
                AppSettings.lyricsCurrentLineScaleRange.upperBound
            )
        )
    }

    private func lyricVisualScale(
        isFocused: Bool,
        focusedScale: CGFloat,
        motionProfile: AppleMusicLyricsMotionProfile?
    ) -> CGFloat {
        guard let motionProfile else {
            return isFocused ? focusedScale : 1
        }
        return isFocused
            ? 1
            : CGFloat(motionProfile.deselectedScale)
    }

    private func lyricFocusScaleAnimation(
        isFocused: Bool
    ) -> Animation? {
        guard !accessibilityReduceMotion else { return nil }

        if let spring = settings.appleMusicLyricsMotionProfile?
            .lineChangeSpring {
            return lyricPhysicalSpringAnimation(spring)
        }

        let duration = lyricFocusScaleDuration()
        guard isFocused, settings.lyricsFocusScaleBounceEnabled else {
            return .smooth(duration: duration)
        }

        let bounce = min(
            max(
                settings.lyricsFocusScaleBounce,
                AppSettings.lyricsFocusScaleBounceRange.lowerBound
            ),
            AppSettings.lyricsFocusScaleBounceRange.upperBound
        )
        return lyricSpringAnimation(
            duration: duration,
            bounce: bounce
        )
    }

    private func showsLyricTranslation(
        isFocusedLine: Bool
    ) -> Bool {
        if settings.appleMusicLyricsMotionProfile != nil {
            return true
        }
        return switch settings.lyricsTranslationDisplayMode {
        case .focusedLine:
            isFocusedLine
        case .allLines:
            true
        }
    }

    private func showsLyricRomanization(
        isFocusedLine: Bool
    ) -> Bool {
        if settings.appleMusicLyricsMotionProfile != nil {
            return true
        }
        return switch settings.lyricsRomanizationDisplayMode {
        case .focusedLine:
            isFocusedLine
        case .allLines:
            true
        }
    }

    private var lyricRomanizationFontSize: CGFloat {
        if settings.appleMusicLyricsMotionProfile != nil {
            return UIFont.preferredFont(
                forTextStyle: .title3
            ).pointSize
        }
        return max(
            CGFloat(
                resolvedLyricsFontSize
                    * settings.lyricsRomanizationFontScale
            ),
            13
        )
    }

    private func recordLyricGeometry(
        _ measurement: LyricGeometryMeasurement,
        for id: LyricLine.ID
    ) {
        let frame = measurement.frame
        let layoutHeight = measurement.layoutHeight
        guard Self.isValidLyricFrame(frame),
              layoutHeight.isFinite,
              layoutHeight > 0 else {
            if lyricGeometryCache.frames[id] != nil {
                lyricGeometryCache.frames.removeValue(forKey: id)
            }
            if lyricGeometryCache.layoutHeights[id] != nil {
                lyricGeometryCache.layoutHeights.removeValue(forKey: id)
                lyricLayoutRevision &+= 1
            }
            return
        }

        let previousFrame = lyricGeometryCache.frames[id]
        let previousLayoutHeight = lyricGeometryCache.layoutHeights[id]
        let frameChanged = previousFrame == nil
            || !Self.isApproximatelyEqual(
                previousFrame ?? .zero,
                frame
            )
        let layoutHeightChanged = previousLayoutHeight == nil
            || abs((previousLayoutHeight ?? 0) - layoutHeight) > 0.5
        guard frameChanged || layoutHeightChanged else {
            return
        }

        lyricGeometryCache.frames[id] = frame
        lyricGeometryCache.layoutHeights[id] = layoutHeight
        if layoutHeightChanged {
            lyricLayoutRevision &+= 1
        }
        guard id == visualCascadeFocusLyricID,
              lyricMovementTransition == nil,
              layoutHeightChanged else {
            return
        }
        synchronizeStationaryFollowingOffsets()
    }

    private func recordInterludeGeometry(
        _ frame: CGRect,
        for id: LyricInterlude.ID
    ) {
        guard Self.isValidLyricFrame(frame) else {
            lyricGeometryCache.removeInterlude(id)
            return
        }
        lyricGeometryCache.interludeFrames[id] = frame
    }

    private func recordAnnotationHeight(
        _ height: CGFloat,
        for id: LyricLine.ID
    ) {
        guard height.isFinite, height > 0 else { return }
        let normalizedHeight = max(height, 0)
        let previousHeight = lyricGeometryCache.annotationHeights[id]
        guard previousHeight == nil
                || abs((previousHeight ?? 0) - normalizedHeight) > 0.5 else {
            return
        }

        lyricGeometryCache.annotationHeights[id] = normalizedHeight
        lyricLayoutRevision &+= 1
        guard id == visualCascadeFocusLyricID,
              lyricMovementTransition == nil else {
            return
        }
        synchronizeStationaryFollowingOffsets()
    }

    private static func isApproximatelyEqual(
        _ lhs: CGRect,
        _ rhs: CGRect
    ) -> Bool {
        let tolerance: CGFloat = 0.5
        return abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    private func synchronizeStationaryFollowingOffsets() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementOffsetByID = focusedLineFollowingOffsets(
                for:
                    visualCascadeFocusLyricID
                    ?? playbackFocus?.lyricID
                    ?? highlightedLyricID
            )
        }
    }

    private func focusedLineFollowingOffsets(
        for focusedLyricID: LyricLine.ID?
    ) -> [LyricLine.ID: CGFloat] {
        guard let focusedLyricID,
              let focusedIndex = lyricIndexByID[focusedLyricID],
              focusedIndex + 1 < lyrics.endIndex else {
            return [:]
        }

        let scale = lyricsCurrentLineScale
        let fallbackPrimaryHeight = CGFloat(resolvedLyricsFontSize) * 1.2
        var focusedLayoutHeight =
            lyricGeometryCache.layoutHeights[focusedLyricID]
            ?? fallbackPrimaryHeight
        let focusedLine = lyrics[focusedIndex]
        let hasFocusedRomanization =
            settings.lyricsRomanizationEnabled
            && focusedLine.hasRomanization
        let hasFocusedTranslation =
            settings.lyricsTranslationEnabled
            && focusedLine.hasTranslation
        let expandsFocusedRomanization =
            settings.appleMusicLyricsMotionProfile == nil
            &&
            hasFocusedRomanization
            && settings.lyricsRomanizationDisplayMode == .focusedLine
        let expandsFocusedTranslation =
            settings.appleMusicLyricsMotionProfile == nil
            &&
            hasFocusedTranslation
            && settings.lyricsTranslationDisplayMode == .focusedLine
        if expandsFocusedRomanization || expandsFocusedTranslation,
           focusedLyricID != visualCascadeFocusLyricID {
            let fallbackRomanizationHeight = expandsFocusedRomanization
                ? max(
                    CGFloat(
                        resolvedLyricsFontSize
                            * settings.lyricsRomanizationFontScale
                    ),
                    13
                ) * 1.2
                : 0
            let fallbackTranslationHeight = expandsFocusedTranslation
                ? max(
                    CGFloat(
                        resolvedLyricsFontSize
                            * settings.lyricsTranslationFontScale
                    ),
                    13
                ) * 1.2
                : 0
            focusedLayoutHeight +=
                fallbackRomanizationHeight
                + (
                    expandsFocusedRomanization
                        ? Self.annotationSpacing
                        : 0
                )
                + (
                    expandsFocusedTranslation
                        ? (
                            lyricGeometryCache.annotationHeights[focusedLyricID]
                                ?? fallbackTranslationHeight
                        ) + Self.annotationSpacing
                        : 0
                )
        }
        let scaleOverflow = max(
            focusedLayoutHeight * (scale - 1),
            0
        )

        let followingOffset = scaleOverflow
        guard followingOffset > 0.5 else { return [:] }
        return Dictionary(
            uniqueKeysWithValues:
                lyrics[(focusedIndex + 1)...].map { line in
                    (line.id, followingOffset)
                }
        )
    }

    private func lyricAnnotationVisibilityAnimation(
        focusScaleAnimation: Animation?
    ) -> Animation? {
        guard !accessibilityReduceMotion else { return nil }
        if usesFocusedLineAnnotationMode {
            return focusScaleAnimation
        }
        let duration = min(
            max(
                settings.effectiveAppleMusicLyricsCascadeDuration
                    * 0.7,
                0.16
            ),
            0.32
        )
        return .smooth(duration: duration)
    }

    private func lyricAnnotationLayoutAnimation() -> Animation? {
        guard !accessibilityReduceMotion else { return nil }
        let duration: TimeInterval
        if usesFocusedLineAnnotationMode {
            duration = lyricFocusScaleDuration()
        } else {
            duration = min(
                max(
                    settings.effectiveAppleMusicLyricsCascadeDuration
                        * 0.7,
                    0.16
                ),
                0.32
            )
        }
        return .smooth(duration: duration)
    }

    private var usesFocusedLineAnnotationMode: Bool {
        guard settings.appleMusicLyricsMotionProfile == nil else {
            return false
        }
        return (
            settings.lyricsRomanizationEnabled
                && settings.lyricsRomanizationDisplayMode
                    == .focusedLine
        ) || (
            settings.lyricsTranslationEnabled
                && settings.lyricsTranslationDisplayMode
                    == .focusedLine
        )
    }

    private func lyricFocusScaleDuration() -> TimeInterval {
        if settings.lyricsFocusScaleBounceEnabled {
            return min(
                max(
                    settings.lyricsFocusScaleBounceDuration,
                    AppSettings.lyricsFocusScaleBounceDurationRange.lowerBound
                ),
                AppSettings.lyricsFocusScaleBounceDurationRange.upperBound
            )
        }
        return min(
            max(
                LyricPlaybackTimeline.focusAnimationDuration(
                    for: highlightedLyricID,
                    in: lyrics
                ),
                0.28
            ),
            0.42
        )
    }

    private func lyricSpringAnimation(
        duration: TimeInterval,
        bounce: Double
    ) -> Animation {
        .spring(
            duration: duration,
            bounce: bounce,
            blendDuration: min(max(duration * 0.22, 0.06), 0.14)
        )
    }

    private func lyricPhysicalSpringAnimation(
        _ spring: LyricPhysicalSpringParameters
    ) -> Animation {
        .interpolatingSpring(
            mass: spring.mass,
            stiffness: spring.stiffness,
            damping: spring.damping,
            initialVelocity: 0
        )
    }

    private var focusMovementTrigger: LyricFocusMovementTrigger {
        LyricFocusMovementTrigger(
            highlightedLyricID: requestedFocusLyricID,
            interludeID: focusedInterlude?.id,
            visibleInterludeID: visibleInterludeID,
            isActive: isActive,
            isBrowsingLyrics: isBrowsingLyrics,
            playbackFocusRequestGeneration: playbackFocusRequestGeneration
        )
    }

    private var requestedFocusLyricID: LyricLine.ID? {
        seekFeedback?.lyricID
            ?? playbackFocus?.lyricID
            ?? highlightedLyricID
    }

    private func lyricFocusEffectAnimation(
        for highlightedLyricID: LyricLine.ID?
    ) -> Animation? {
        guard !accessibilityReduceMotion else { return nil }
        let movementDuration = LyricPlaybackTimeline.focusAnimationDuration(
            for: highlightedLyricID,
            in: lyrics
        )
        return .easeInOut(duration: max(movementDuration, 0.2))
    }

    private var lyricsFocusColorLeadTime: TimeInterval {
        min(
            max(
                settings.effectiveAppleMusicLyricsFocusColorLeadTime,
                AppSettings.lyricsFocusColorLeadTimeRange.lowerBound
            ),
            AppSettings.lyricsFocusColorLeadTimeRange.upperBound
        )
    }

    private var effectiveLyricsAdvanceTime: TimeInterval {
        settings.effectiveLyricsAdvanceTime(
            hasSyllableSyncedLyrics: hasSyllableSyncedLyrics
        )
    }

    private func remainingFocusDuration(
        for highlightedLyricID: LyricLine.ID
    ) -> TimeInterval? {
        guard player.isPlaying else { return nil }
        return LyricPlaybackTimeline.remainingFocusDuration(
            for: highlightedLyricID,
            at: player.estimatedProgress()
                + effectiveLyricsAdvanceTime,
            in: lyrics
        )
    }

    private func waitForLyricFrame(
        for id: LyricLine.ID
    ) async -> CGRect? {
        for attempt in 0..<30 {
            if let frame = lyricGeometryCache.frames[id] {
                return frame
            }
            guard !Task.isCancelled, attempt < 29 else { return nil }
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return nil
            }
        }
        return nil
    }

    private func waitForPreparedFocus(
        id: LyricLine.ID,
        viewportAnchorY: CGFloat,
        focusPosition: CGFloat
    ) async -> Bool {
        for attempt in 0..<30 {
            if let frame = lyricGeometryCache.frames[id] {
                let preparedAnchorY = frame.minY
                    + frame.height * focusPosition
                if abs(preparedAnchorY - viewportAnchorY) <= 2 {
                    return true
                }
            }
            guard !Task.isCancelled, attempt < 29 else { return false }
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return false
            }
        }
        return false
    }

    private func cascadeMoveFocus(
        to highlightedLyricID: LyricLine.ID?,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat,
        visibleViewportHeight: CGFloat,
        customPreloadLineCount: Int
    ) async {
        guard !isBrowsingLyrics else {
            resetMovementOffsets()
            startFocusColorTransition(to: highlightedLyricID)
            visualCascadeFocusLyricID = highlightedLyricID
            return
        }

        if let interlude = focusedInterlude {
            moveFocusToInterlude(
                interlude,
                animated: !isPreparingInitialFocus
            )
            return
        }

        guard let highlightedLyricID else {
            resetMovementOffsets()
            guard let firstLyricID = lyrics.first?.id else { return }
            await ensureFocusAlignment(
                to: firstLyricID,
                viewportHeight: viewportHeight,
                animated: false
            )
            return
        }
        let isInterludeHandoff = visibleInterludeID.flatMap {
            interludeByID[$0]
        }?.followingLyricID == highlightedLyricID
        if isInterludeHandoff {
            await moveFocusFromInterlude(
                to: highlightedLyricID,
                viewportWidth: viewportWidth,
                viewportHeight: viewportHeight
            )
            return
        }
        let movementFocusLyricID = lyricMovementTransition?.focusID
            ?? visualCascadeFocusLyricID
            ?? scrollPositionID
        let isManualSeekTransition =
            seekFeedback?.lyricID == highlightedLyricID
        // Apple's manual/forced (kind 1) caller supplies a zero curve input
        // and resolves to the fixed line-change spring.
        let timedWordTransitionSourceDuration = isManualSeekTransition
            ? nil
            : appleMusicTimedWordTransitionSourceDuration(
                from: movementFocusLyricID,
                to: highlightedLyricID
            )
        guard movementFocusLyricID != highlightedLyricID else {
            if lyricMovementTransition != nil {
                completeCascadeMovement(to: highlightedLyricID)
            } else {
                startFocusColorTransition(to: highlightedLyricID)
                visualCascadeFocusLyricID = highlightedLyricID
            }
            await ensureFocusAlignment(
                to: highlightedLyricID,
                viewportHeight: viewportHeight,
                animated: !isPreparingInitialFocus
            )
            return
        }
        guard settings.appleMusicLyricsMotionProfile != nil
                || !isReverseFocusTransition(
                    from: movementFocusLyricID,
                    to: highlightedLyricID
                ) else {
            await moveFocusWithoutCascade(
                to: highlightedLyricID,
                viewportHeight: viewportHeight
            )
            return
        }
        guard settings.appleMusicLyricsMotionProfile != nil
                || isManualSeekTransition
                || isAdjacentFocusTransition(
                    from: movementFocusLyricID,
                    to: highlightedLyricID
                ) else {
            await moveFocusWithoutCascade(
                to: highlightedLyricID,
                viewportHeight: viewportHeight
            )
            return
        }

        // The editable scheme's following-row base delay is independent of
        // both per-line delay controls, so it can create a real stagger alone.
        let hasCascadeStagger =
            settings.effectiveAppleMusicLyricsCascadeDelay > 0
            || settings.effectiveAppleMusicLyricsCascadeDelayIncrease > 0
            || settings.effectiveAppleMusicLyricsFollowingDelay > 0
        guard !accessibilityReduceMotion, hasCascadeStagger else {
            await moveFocusWithoutCascade(
                to: highlightedLyricID,
                viewportHeight: viewportHeight
            )
            return
        }
        let remainingDurationAtTransition = remainingFocusDuration(
            for: highlightedLyricID
        )
        guard let nextFocusFrame = await waitForLyricFrame(
            for: highlightedLyricID
        ) else {
            guard !Task.isCancelled else { return }
            await moveFocusWithoutCascade(
                to: highlightedLyricID,
                viewportHeight: viewportHeight
            )
            return
        }

        let focusPosition = lyricsFocusPosition(for: viewportHeight)
        let viewportAnchorY = viewportHeight * focusPosition
        let nextFocusAnchorY = nextFocusFrame.minY
            + nextFocusFrame.height * focusPosition
        let movementDistance = nextFocusAnchorY - viewportAnchorY
        let hasPositionChange = settings.appleMusicLyricsMotionProfile != nil
            ? movementDistance != 0
            : abs(movementDistance) > 0.5
        guard hasPositionChange else {
            completeCascadeMovement(to: highlightedLyricID)
            return
        }

        var carriedMovementOffsets = lyricMovementOffsetByID
        var carriedMovementVelocities: [LyricLine.ID: CGFloat] = [:]
        if let presentationStates = lyricMovementTransition?
            .presentationStates(at: .now) {
            carriedMovementOffsets.merge(
                presentationStates.mapValues(\.offset),
                uniquingKeysWith: { _, presentationState in
                    presentationState
                }
            )
            carriedMovementVelocities = presentationStates.mapValues(
                \.velocity
            )
        }
        let cascadeViewportHeight = settings.appleMusicLyricsMotionProfile
            != nil
            ? viewportHeight
            : visibleViewportHeight
        let initialMountedIDSet = Set(lyricGeometryCache.frames.keys)
        let initialMountedInterludeIDSet = Set(
            lyricGeometryCache.interludeFrames.keys
        )
        let initialVisibleIDs = lyricGeometryCache.frames
            .filter { entry in
                let frame = entry.value
                let carriedOffset = carriedMovementOffsets[
                    entry.key,
                    default: 0
                ]
                return Self.isLyricFrameVisible(
                    frame,
                    movementOffset: carriedOffset,
                    viewportHeight: cascadeViewportHeight
                )
            }
            .sorted { left, right in
                let leftMinY = left.value.minY
                    + carriedMovementOffsets[left.key, default: 0]
                let rightMinY = right.value.minY
                    + carriedMovementOffsets[right.key, default: 0]
                return leftMinY < rightMinY
            }
            .map(\.key)
        let initialVisibleInterludeIDs = lyricGeometryCache.interludeFrames
            .filter { entry in
                Self.isLyricFrameVisible(
                    entry.value,
                    viewportHeight: cascadeViewportHeight
                )
            }
            .map(\.key)
        let baseAnimationDuration = LyricPlaybackTimeline.focusAnimationDuration(
            for: highlightedLyricID,
            in: lyrics
        )
        let cascadeAnimationDuration = LyricPlaybackTimeline.focusCascadeAnimationDuration(
            baseDuration: baseAnimationDuration,
            preferredDuration:
                settings.effectiveAppleMusicLyricsCascadeDuration
        )
        let prefersCascadeBounce = settings.lyricsFocusCascadeBounceEnabled
        let focusColorLeadTime = lyricsFocusColorLeadTime
        let destinationOffsets = focusedLineFollowingOffsets(
            for: highlightedLyricID
        )
        let retainedLyrics =
            AppleMusicRetainedViewportPlanner.retainedLyrics(
                isNonAdjacentTransition: isNonAdjacentFocusTransition(
                    from: movementFocusLyricID,
                    to: highlightedLyricID
                ),
                initialVisibleIDs: initialVisibleIDs,
                framesByID: lyricGeometryCache.frames,
                movementDistance: movementDistance,
                destinationOffsetsByID: destinationOffsets,
                viewportHeight: cascadeViewportHeight
            )
        let preparedMovementOffsets = Dictionary(
            uniqueKeysWithValues: lyrics.map { line in
                (
                    line.id,
                    movementDistance
                        + carriedMovementOffsets[line.id, default: 0]
                )
            }
        )
        let preparedMovementTransition = LyricMovementTransition(
            focusID: highlightedLyricID,
            initialOffsetsByID: preparedMovementOffsets,
            destinationOffsetsByID: destinationOffsets
        )

        var preparationTransaction = Transaction(animation: nil)
        preparationTransaction.disablesAnimations = true
        withTransaction(preparationTransaction) {
            retainedCascadeLyrics = retainedLyrics
            lyricMovementOffsetByID = preparedMovementOffsets
            lyricMovementTransition = preparedMovementTransition
            scrollPositionID = highlightedLyricID
        }

        let destinationIsPrepared = await waitForPreparedFocus(
            id: highlightedLyricID,
            viewportAnchorY: viewportAnchorY,
            focusPosition: focusPosition
        )
        guard !Task.isCancelled else { return }
        guard destinationIsPrepared else {
            completeCascadeMovement(to: highlightedLyricID)
            await ensureFocusAlignment(
                to: highlightedLyricID,
                viewportHeight: viewportHeight,
                animated: false
            )
            return
        }

        let destinationVisibleIDs = lyricGeometryCache.frames
            .filter { entry in
                Self.isLyricFrameVisible(
                    entry.value,
                    viewportHeight: cascadeViewportHeight
                )
            }
            .sorted { left, right in
                left.value.minY < right.value.minY
            }
            .map(\.key)
        guard let highlightedIndex = lyricIndexByID[highlightedLyricID] else {
            completeCascadeMovement(to: highlightedLyricID)
            return
        }
        if let profile = settings.appleMusicLyricsMotionProfile {
            let targetMountedIDSet = Set(lyricGeometryCache.frames.keys)
            let targetMountedInterludeIDSet = Set(
                lyricGeometryCache.interludeFrames.keys
            )
            let mountedIDSet = initialMountedIDSet.union(
                targetMountedIDSet
            )
            let mountedInterludeIDSet = initialMountedInterludeIDSet.union(
                targetMountedInterludeIDSet
            )
            let targetVisibleInterludeIDs = lyricGeometryCache
                .interludeFrames
                .filter { entry in
                    Self.isLyricFrameVisible(
                        entry.value,
                        viewportHeight: cascadeViewportHeight
                    )
                }
                .map(\.key)
            let mountedIDsInLyricOrder = displayItems.compactMap { item in
                switch item {
                case let .lyric(line) where mountedIDSet.contains(line.id):
                    PositionCascadeLineID.lyric(line.id)
                case let .interlude(interlude)
                    where mountedInterludeIDSet.contains(interlude.id):
                    PositionCascadeLineID.interlude(interlude.id)
                default:
                    nil
                }
            }
            let currentViewportIDs = Set(
                initialVisibleIDs.map(PositionCascadeLineID.lyric)
                    + initialVisibleInterludeIDs.map(
                        PositionCascadeLineID.interlude
                    )
            )
            let targetViewportIDs = Set(
                destinationVisibleIDs.map(PositionCascadeLineID.lyric)
                    + targetVisibleInterludeIDs.map(
                        PositionCascadeLineID.interlude
                    )
            )
            let positionPlan = AppleMusicLyricsLinePositionPlanner.plan(
                mountedIDsInLyricOrder: mountedIDsInLyricOrder,
                currentViewportIDs: currentViewportIDs,
                targetViewportIDs: targetViewportIDs,
                contentOffsetDelta: Double(movementDistance)
            )
            guard !positionPlan.isEmpty else {
                completeCascadeMovement(to: highlightedLyricID)
                return
            }
            await animatePreparedAppleMusicLinePositionCascade(
                positionPlan,
                to: highlightedLyricID,
                profile: profile,
                timedWordTransitionSourceDuration:
                    timedWordTransitionSourceDuration,
                transition: preparedMovementTransition
            )
            return
        }
        var movingIDSet = Set(initialVisibleIDs)
        movingIDSet.formUnion(destinationVisibleIDs)
        let guaranteedFutureEndIndex = min(
            highlightedIndex
                + Self.customFutureCascadeSafetyLineCount
                + 1,
            lyrics.endIndex
        )
        for index in highlightedIndex..<guaranteedFutureEndIndex {
            movingIDSet.insert(lyrics[index].id)
        }
        if customPreloadLineCount > 0,
           let bottomVisibleIndex = destinationVisibleIDs
            .compactMap({ lyricIndexByID[$0] })
            .max() {
            let preloadStartIndex = bottomVisibleIndex + 1
            let preloadEndIndex = min(
                preloadStartIndex + customPreloadLineCount,
                lyrics.endIndex
            )
            if preloadStartIndex < preloadEndIndex {
                for index in preloadStartIndex..<preloadEndIndex {
                    movingIDSet.insert(lyrics[index].id)
                }
            }
        }
        let movingIndexes = movingIDSet.compactMap { lyricIndexByID[$0] }
        guard let firstMovingIndex = movingIndexes.min(),
              let lastMovingIndex = movingIndexes.max() else {
            completeCascadeMovement(to: highlightedLyricID)
            return
        }
        let orderedMovingIDs = lyrics[firstMovingIndex...lastMovingIndex]
            .map(\.id)
        guard orderedMovingIDs.count > 1 else {
            completeCascadeMovement(to: highlightedLyricID)
            return
        }
        let movementOrderByID = Dictionary(
            uniqueKeysWithValues: orderedMovingIDs.map { id in
                let lineIndex = lyricIndexByID[id] ?? highlightedIndex
                let lineOrder = max(
                    lineIndex - highlightedIndex,
                    0
                )
                return (id, lineOrder)
            }
        )
        // Keep the focus line's start delay unchanged, while grading its
        // catch-up speed and bounce from the preceding line downward.
        let firstChasingIndex = max(
            highlightedIndex - 1,
            lyrics.startIndex
        )
        let chaseOrderByID: [LyricLine.ID: Int] = Dictionary(
            uniqueKeysWithValues: orderedMovingIDs.compactMap { id in
                guard let lineIndex = lyricIndexByID[id],
                      lineIndex >= firstChasingIndex else {
                    return nil
                }
                return (id, lineIndex - firstChasingIndex)
            }
        )
        let maximumChaseOrder = chaseOrderByID.values.max() ?? 0
        guard let cascadeTiming = LyricPlaybackTimeline.focusCascadeTiming(
            maximumLineOrder: maximumChaseOrder,
            preferredDelayPerLine:
                settings.effectiveAppleMusicLyricsCascadeDelay,
            preferredDelayIncreasePerLine:
                settings.effectiveAppleMusicLyricsCascadeDelayIncrease,
            followingLineBaseDelay:
                settings.effectiveAppleMusicLyricsFollowingDelay,
            preferredCatchUpCompletionRatio:
                settings.effectiveAppleMusicLyricsCatchUpRatio,
            focusColorLeadTime: focusColorLeadTime,
            baseAnimationDuration: baseAnimationDuration,
            preferredAnimationDuration: cascadeAnimationDuration,
            prefersBounce: prefersCascadeBounce,
            snapThreshold:
                settings.effectiveAppleMusicLyricsSnapThreshold,
            remainingDuration: remainingDurationAtTransition
        ) else {
            completeCascadeMovement(to: highlightedLyricID)
            return
        }
        await animatePreparedCascade(
            orderedMovingIDs,
            to: highlightedLyricID,
            movementOrderByID: movementOrderByID,
            chaseOrderByID: chaseOrderByID,
            maximumChaseOrder: maximumChaseOrder,
            cascadeTiming: cascadeTiming,
            focusColorLeadTime: focusColorLeadTime,
            carriedVelocityByID: carriedMovementVelocities,
            transition: preparedMovementTransition
        )
    }

    /// The time-driven handoff normally starts only after the dots are gone.
    /// Preserve a fixed copy only for an interrupted/forced handoff that lands
    /// inside the cue-out window, then move the resident stack underneath it.
    private func moveFocusFromInterlude(
        to id: LyricLine.ID,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat
    ) async {
        if let interludeID = visibleInterludeID,
           let interlude = interludeByID[interludeID] {
            let motionTiming = AppleMusicInterludeMotionProfile.iOS26_6
                .timing(for: interlude)
            let playbackTime = player.estimatedProgress()
                + effectiveLyricsAdvanceTime
            if playbackTime >= motionTiming.cueOutTime,
               playbackTime < motionTiming.visualEndTime {
                let presentation =
                    AppleMusicRetainedInterludePresentation(
                        interlude: interlude,
                        frame: retainedInterludeFrame(
                            for: interlude,
                            viewportWidth: viewportWidth,
                            viewportHeight: viewportHeight
                        )
                    )
                var retentionTransaction = Transaction(animation: nil)
                retentionTransaction.disablesAnimations = true
                withTransaction(retentionTransaction) {
                    retainedInterlude = presentation
                }
                // Materialize the fixed copy before the scroll view starts
                // moving the resident row toward the top mask.
                await Task.yield()
                guard !Task.isCancelled else { return }
            } else {
                retainedInterlude = nil
            }
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementOffsetByID.removeAll()
            lyricMovementTransition = nil
            retainedCascadeLyrics.removeAll()
        }

        startFocusColorTransition(to: id)
        let fallbackDuration = LyricPlaybackTimeline.focusAnimationDuration(
            for: id,
            in: lyrics
        )
        withAnimation(
            accessibilityReduceMotion
                ? nil
                : lyricLineChangeAnimation(
                    fallback: .smooth(duration: fallbackDuration)
                )
        ) {
            scrollPositionID = id
            visualCascadeFocusLyricID = id
        }
        await waitForFocusAlignment(
            to: id,
            viewportHeight: viewportHeight
        )
    }

    private func retainedInterludeFrame(
        for interlude: LyricInterlude,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat
    ) -> CGRect {
        if let measuredFrame = lyricGeometryCache.interludeFrames[
            interlude.id
        ], Self.isLyricFrameVisible(
            measuredFrame,
            viewportHeight: viewportHeight
        ) {
            return measuredFrame
        }

        let motionProfile = AppleMusicInterludeMotionProfile.iOS26_6
        let focusPosition = lyricsFocusPosition(for: viewportHeight)
        return CGRect(
            x: 0,
            y: max(viewportHeight - motionProfile.viewHeight, 0)
                * focusPosition,
            width: max(viewportWidth, 1),
            height: motionProfile.viewHeight
        )
    }

    private func finishRetainedInterlude(
        _ presentationID: AppleMusicRetainedInterludePresentation.ID
    ) {
        guard retainedInterlude?.id == presentationID else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            retainedInterlude = nil
        }
    }

    private func waitForFocusAlignment(
        to id: LyricLine.ID,
        viewportHeight: CGFloat
    ) async {
        let focusPosition = lyricsFocusPosition(for: viewportHeight)
        let viewportAnchorY = viewportHeight * focusPosition
        for _ in 0..<30 {
            guard !Task.isCancelled else { return }
            if let frame = lyricGeometryCache.frames[id] {
                let anchorY = frame.minY + frame.height * focusPosition
                if abs(anchorY - viewportAnchorY) <= 2 { return }
            }
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return
            }
        }
    }

    private func animatePreparedCascade(
        _ orderedMovingIDs: [LyricLine.ID],
        to highlightedLyricID: LyricLine.ID,
        movementOrderByID: [LyricLine.ID: Int],
        chaseOrderByID: [LyricLine.ID: Int],
        maximumChaseOrder: Int,
        cascadeTiming: LyricFocusCascadeTiming,
        focusColorLeadTime: TimeInterval,
        carriedVelocityByID: [LyricLine.ID: CGFloat],
        transition: LyricMovementTransition
    ) async {
        let usesBounce = cascadeTiming.usesBounce
        let chaseSpeedGradient = min(
            max(
                settings.effectiveAppleMusicLyricsChaseSpeedGradient,
                AppSettings.lyricsFocusCascadeChaseSpeedGradientRange.lowerBound
            ),
            AppSettings.lyricsFocusCascadeChaseSpeedGradientRange.upperBound
        )
        let slowestChaseDuration = cascadeTiming.lineTiming(
            for: 0
        ).duration
        let movementAnimations = Dictionary(
            uniqueKeysWithValues: orderedMovingIDs.map { id in
                let movementOrder = movementOrderByID[id, default: 0]
                let chaseOrder = chaseOrderByID[id]
                let movementTiming = cascadeTiming.lineTiming(
                    for: movementOrder
                )
                let chaseTiming = cascadeTiming.lineTiming(
                    for: chaseOrder ?? 0
                )
                let requestedChaseDuration = slowestChaseDuration
                    + (
                        chaseTiming.duration
                            - slowestChaseDuration
                    ) * chaseSpeedGradient
                let chaseDuration = min(
                    max(requestedChaseDuration, 0),
                    movementTiming.duration
                )
                let destinationOffset = transition
                    .destinationOffsetsByID[id, default: 0]
                let initialOffset = transition.initialOffsetsByID[
                    id,
                    default: destinationOffset
                ]
                let movementDistance =
                    destinationOffset - initialOffset
                let carriedVelocity = carriedVelocityByID[id, default: 0]
                let rawInitialVelocity = abs(movementDistance) > 0.5
                    ? Double(carriedVelocity / movementDistance)
                    : 0
                let initialVelocity = rawInitialVelocity.isFinite
                    ? min(max(rawInitialVelocity, -12), 12)
                    : 0
                let configuration = LyricMovementAnimationConfiguration(
                    delay: movementTiming.delay,
                    duration: chaseDuration,
                    usesBounce: usesBounce,
                    bounce: lyricFocusCascadeBounce(
                        chaseOrder: chaseOrder,
                        maximumChaseOrder: maximumChaseOrder
                    ),
                    initialVelocity: initialVelocity
                )
                return (id, configuration)
            }
        )
        guard !Task.isCancelled,
              lyricMovementTransition?.id == transition.id else { return }

        if focusColorLeadTime >= 0 {
            startFocusColorTransition(to: highlightedLyricID)
        }
        if focusColorLeadTime > 0 {
            do {
                try await Task.sleep(for: .seconds(focusColorLeadTime))
            } catch {
                return
            }
        }
        guard !Task.isCancelled,
              let preparedTransition = lyricMovementTransition,
              preparedTransition.id == transition.id else { return }

        let startedTransition = preparedTransition.starting(
            with: movementAnimations,
            at: .now
        )
        var movementTransaction = Transaction(animation: nil)
        movementTransaction.disablesAnimations = true
        withTransaction(movementTransaction) {
            lyricMovementTransition = startedTransition
            lyricMovementOffsetByID =
                preparedTransition.destinationOffsetsByID
        }
        visualCascadeFocusLyricID = highlightedLyricID

        let focusColorDelayAfterMovement = max(-focusColorLeadTime, 0)
        if focusColorDelayAfterMovement > 0 {
            do {
                try await Task.sleep(
                    for: .seconds(focusColorDelayAfterMovement)
                )
            } catch {
                return
            }
            guard !Task.isCancelled,
                  lyricMovementTransition?.id == transition.id else { return }
            startFocusColorTransition(to: highlightedLyricID)
        }

        let elapsedSinceMovementStart = startedTransition.startedAt.map {
            Date.now.timeIntervalSince($0)
        } ?? 0
        let remainingMovementDuration = max(
            startedTransition.completionDuration
                - elapsedSinceMovementStart,
            0
        ) + Self.cascadeSettlementGraceDuration
        if remainingMovementDuration > 0 {
            do {
                try await Task.sleep(
                    for: .seconds(remainingMovementDuration)
                )
            } catch {
                return
            }
        }
        guard !Task.isCancelled,
              lyricMovementTransition?.id == transition.id else { return }
        completeCascadeMovement(to: highlightedLyricID)
    }

    private func animatePreparedAppleMusicLinePositionCascade(
        _ plan: [
            AppleMusicLyricsLinePositionPlanner.PlannedLine<
                PositionCascadeLineID
            >
        ],
        to highlightedLyricID: LyricLine.ID,
        profile: AppleMusicLyricsMotionProfile,
        timedWordTransitionSourceDuration: TimeInterval?,
        transition: LyricMovementTransition
    ) async {
        let animationByID = plan.reduce(
            into: [
                LyricLine.ID: LyricMovementAnimationConfiguration
            ]()
        ) { animations, line in
            guard case let .lyric(lyricID) = line.id else { return }
            let destinationOffset = transition
                .destinationOffsetsByID[lyricID, default: 0]
            let initialOffset = transition.initialOffsetsByID[
                lyricID,
                default: destinationOffset
            ]
            let movementDistance = destinationOffset - initialOffset
            guard movementDistance != 0 else { return }
            let spring = timedWordTransitionSourceDuration.map(
                profile.dynamicSpring(sourceDuration:)
            ) ?? profile.lineChangeSpring
            // Apple derives the timed-word source from the final selected
            // line's start minus the previous next-line's authored end. LRC
            // and missing-duration rows cannot represent that contract, so
            // they fall back to the observed fixed line-change spring.
            // No binary evidence supports carrying a presentation velocity
            // into this descriptor, therefore its initial velocity is zero.
            animations[lyricID] = LyricMovementAnimationConfiguration(
                delay: line.delay,
                duration: 0,
                physicalSpring: spring,
                initialVelocity: 0
            )
        }
        guard !animationByID.isEmpty else {
            completeCascadeMovement(to: highlightedLyricID)
            return
        }
        guard !Task.isCancelled,
              lyricMovementTransition?.id == transition.id else { return }

        startFocusColorTransition(to: highlightedLyricID)
        let startedTransition = transition.starting(
            with: animationByID,
            at: .now
        )
        var movementTransaction = Transaction(animation: nil)
        movementTransaction.disablesAnimations = true
        withTransaction(movementTransaction) {
            lyricMovementTransition = startedTransition
            lyricMovementOffsetByID = transition.destinationOffsetsByID
        }
        visualCascadeFocusLyricID = highlightedLyricID

        let elapsedSinceMovementStart = startedTransition.startedAt.map {
            Date.now.timeIntervalSince($0)
        } ?? 0
        let remainingMovementDuration = max(
            startedTransition.completionDuration
                - elapsedSinceMovementStart,
            0
        ) + Self.cascadeSettlementGraceDuration
        if remainingMovementDuration > 0 {
            do {
                try await Task.sleep(
                    for: .seconds(remainingMovementDuration)
                )
            } catch {
                return
            }
        }
        guard !Task.isCancelled,
              lyricMovementTransition?.id == transition.id else { return }
        completeCascadeMovement(to: highlightedLyricID)
    }

    private func appleMusicTimedWordTransitionSourceDuration(
        from previousLyricID: LyricLine.ID?,
        to highlightedLyricID: LyricLine.ID
    ) -> TimeInterval? {
        guard hasSyllableSyncedLyrics,
              let previousLyricID,
              let previousIndex = lyricIndexByID[previousLyricID],
              let highlightedIndex = lyricIndexByID[highlightedLyricID] else {
            return nil
        }
        let previousLine = lyrics[previousIndex]
        let highlightedLine = lyrics[highlightedIndex]
        guard previousLine.timingKind == .precise,
              highlightedLine.timingKind == .precise,
              previousLine.isSyllableSynced,
              highlightedLine.isSyllableSynced,
              let previousDuration = previousLine.duration,
              previousDuration.isFinite,
              previousDuration >= 0 else {
            return nil
        }
        let sourceDuration = highlightedLine.time
            - (previousLine.time + previousDuration)
        return sourceDuration.isFinite ? sourceDuration : nil
    }

    private func lyricFocusCascadeBounce(
        chaseOrder: Int?,
        maximumChaseOrder: Int
    ) -> Double {
        let maximumBounce = min(
            max(
                settings.lyricsFocusCascadeBounce,
                AppSettings.lyricsFocusCascadeBounceRange.lowerBound
            ),
            AppSettings.lyricsFocusCascadeBounceRange.upperBound
        )
        guard maximumBounce > 0, let chaseOrder else { return 0 }

        let bounceGradient = min(
            max(
                settings.lyricsFocusCascadeBounceGradient,
                AppSettings.lyricsFocusCascadeBounceGradientRange.lowerBound
            ),
            AppSettings.lyricsFocusCascadeBounceGradientRange.upperBound
        )
        let bouncingLineCount = max(maximumChaseOrder + 1, 1)
        let linePosition = min(
            max(chaseOrder, 0),
            maximumChaseOrder
        ) + 1
        let normalizedPosition =
            Double(linePosition) / Double(bouncingLineCount)
        let bounceScale =
            1 - (1 - normalizedPosition) * bounceGradient
        return maximumBounce * bounceScale
    }

    private func lyricMovementPhase(
        for id: LyricLine.ID
    ) -> LyricMovementPhase {
        let fallbackOffset = lyricMovementOffsetByID[id, default: 0]
        guard !accessibilityReduceMotion,
              let lyricMovementTransition else {
            return .stationary(offset: fallbackOffset)
        }
        return lyricMovementTransition.phase(
            for: id,
            fallbackOffset: fallbackOffset
        )
    }

    private func startFocusColorTransition(
        to highlightedLyricID: LyricLine.ID?
    ) {
        guard visualHighlightedLyricID != highlightedLyricID else {
            return
        }
        let now = Date.now
        let initialColorProgressByID: [LyricLine.ID: CGFloat]
        let initialColorVelocityByID: [LyricLine.ID: CGFloat]
        let initialBlurProgressByID: [LyricLine.ID: CGFloat]
        if let lyricFocusColorTransition {
            initialColorProgressByID =
                lyricFocusColorTransition
                    .presentationColorProgressByID(at: now)
            initialBlurProgressByID =
                lyricFocusColorTransition
                    .presentationBlurProgressByID(at: now)
            initialColorVelocityByID =
                lyricFocusColorTransition
                    .presentationColorVelocityByID(at: now)
        } else if let visualHighlightedLyricID {
            initialColorProgressByID = [visualHighlightedLyricID: 1]
            initialBlurProgressByID = [visualHighlightedLyricID: 1]
            initialColorVelocityByID = [:]
        } else {
            initialColorProgressByID = [:]
            initialBlurProgressByID = [:]
            initialColorVelocityByID = [:]
        }
        let motionProfile = settings.appleMusicLyricsMotionProfile
        let colorSpring = motionProfile?.lineChangeSpring
        let transition = LyricFocusColorTransition(
            initialColorProgressByID: initialColorProgressByID,
            initialColorVelocityByID: initialColorVelocityByID,
            initialBlurProgressByID: initialBlurProgressByID,
            destinationLyricID: highlightedLyricID,
            startedAt: now,
            colorDuration: colorSpring.map {
                LyricFocusColorTransition.settlingDuration(
                    initialProgressByID: initialColorProgressByID,
                    initialVelocityByID: initialColorVelocityByID,
                    destinationLyricID: highlightedLyricID,
                    parameters: $0
                )
            } ?? 0.12,
            blurDuration:
                motionProfile?.focusBlurTransitionDuration
                    ?? 0.12,
            colorTimingCurve: colorSpring.map {
                .physicalSpring($0)
            } ?? .smoothStep,
            blurTimingCurve: motionProfile.map {
                .cubicBezier(
                    controlPoint1X: CGFloat(
                        $0.focusBlurTransitionControlPoint1X
                    ),
                    controlPoint1Y: CGFloat(
                        $0.focusBlurTransitionControlPoint1Y
                    ),
                    controlPoint2X: CGFloat(
                        $0.focusBlurTransitionControlPoint2X
                    ),
                    controlPoint2Y: CGFloat(
                        $0.focusBlurTransitionControlPoint2Y
                    )
                )
            } ?? .smoothStep
        )

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visualHighlightedLyricID = highlightedLyricID
            lyricFocusColorTransition = transition
        }
    }

    private func finishFocusColorTransition(
        _ transition: LyricFocusColorTransition
    ) async {
        let remainingDuration =
            transition.completionDate.timeIntervalSince(.now)
        if remainingDuration > 0 {
            do {
                try await Task.sleep(
                    for: .seconds(remainingDuration)
                )
            } catch {
                return
            }
        }
        guard !Task.isCancelled,
              lyricFocusColorTransition?.id == transition.id else {
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricFocusColorTransition = nil
        }
    }

    private func isAdjacentFocusTransition(
        from currentID: LyricLine.ID?,
        to nextID: LyricLine.ID
    ) -> Bool {
        guard let currentID,
              let currentIndex = lyricIndexByID[currentID],
              let nextIndex = lyricIndexByID[nextID] else {
            return false
        }
        return abs(nextIndex - currentIndex) == 1
    }

    private func isNonAdjacentFocusTransition(
        from currentID: LyricLine.ID?,
        to nextID: LyricLine.ID
    ) -> Bool {
        guard let currentID,
              let currentIndex = lyricIndexByID[currentID],
              let nextIndex = lyricIndexByID[nextID] else {
            return false
        }
        return abs(nextIndex - currentIndex) > 1
    }

    private func isReverseFocusTransition(
        from currentID: LyricLine.ID?,
        to nextID: LyricLine.ID
    ) -> Bool {
        guard let currentID,
              let currentIndex = lyricIndexByID[currentID],
              let nextIndex = lyricIndexByID[nextID] else {
            return false
        }
        return nextIndex < currentIndex
    }

    private func moveFocusWithoutCascade(
        to id: LyricLine.ID,
        viewportHeight: CGFloat
    ) async {
        resetMovementOffsets()
        await ensureFocusAlignment(
            to: id,
            viewportHeight: viewportHeight,
            animated: true
        )
        await Task.yield()
        guard !Task.isCancelled else { return }
        let destinationOffsets = focusedLineFollowingOffsets(for: id)
        startFocusColorTransition(to: id)
        let fallbackDuration = LyricPlaybackTimeline.focusAnimationDuration(
            for: id,
            in: lyrics
        )
        withAnimation(
            accessibilityReduceMotion
                ? nil
                : lyricLineChangeAnimation(
                    fallback: .easeInOut(duration: fallbackDuration)
                )
        ) {
            visualCascadeFocusLyricID = id
            lyricMovementOffsetByID = destinationOffsets
        }
        completeSeekFeedbackIfNeeded(for: id)
    }

    private func moveFocusToInterlude(
        _ interlude: LyricInterlude,
        animated: Bool
    ) {
        let update = {
            scrollPositionID = interlude.id
            visualCascadeFocusLyricID = nil
            lyricMovementOffsetByID.removeAll()
            lyricMovementTransition = nil
            retainedCascadeLyrics.removeAll()
            retainedInterlude = nil
        }

        guard animated,
              !accessibilityReduceMotion,
              scrollPositionID != interlude.id else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction, update)
            startFocusColorTransition(to: nil)
            return
        }

        withAnimation(
            lyricLineChangeAnimation(
                fallback: .smooth(duration: 0.3)
            ),
            update
        )
        startFocusColorTransition(to: nil)
    }

    private func completeCascadeMovement(to id: LyricLine.ID) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollPositionID = id
            visualCascadeFocusLyricID = id
            lyricMovementOffsetByID = focusedLineFollowingOffsets(for: id)
            lyricMovementTransition = nil
            retainedCascadeLyrics.removeAll()
        }
        startFocusColorTransition(to: id)
        completeSeekFeedbackIfNeeded(for: id)
    }

    private func resetMovementOffsets() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementOffsetByID = focusedLineFollowingOffsets(
                for:
                    visualCascadeFocusLyricID
                    ?? playbackFocus?.lyricID
                    ?? highlightedLyricID
            )
            lyricMovementTransition = nil
            retainedCascadeLyrics.removeAll()
        }
    }

    private func lyricNeighborIDs(
        around focusedLyricID: LyricLine.ID?
    ) -> (
        preceding: LyricLine.ID?,
        following: LyricLine.ID?
    ) {
        guard let focusedLyricID,
              let focusIndex = lyricIndexByID[focusedLyricID] else {
            return (nil, nil)
        }

        let precedingID = focusIndex > lyrics.startIndex
            ? lyrics[lyrics.index(before: focusIndex)].id
            : nil
        let followingIndex = lyrics.index(after: focusIndex)
        let followingID = followingIndex < lyrics.endIndex
            ? lyrics[followingIndex].id
            : nil
        return (precedingID, followingID)
    }

    private func measuredLyricAnchorStride(
        around focusedLyricID: LyricLine.ID?,
        lineSpacing: CGFloat,
        fallback: CGFloat
    ) -> CGFloat {
        guard let focusedLyricID,
              let focusIndex = lyricIndexByID[focusedLyricID],
              let focusHeight =
                lyricGeometryCache.layoutHeights[focusedLyricID] else {
            return max(fallback, 1)
        }

        var neighboringStrides: [CGFloat] = []
        if focusIndex > lyrics.startIndex {
            let precedingID = lyrics[focusIndex - 1].id
            if let precedingHeight =
                lyricGeometryCache.layoutHeights[precedingID] {
                neighboringStrides.append(
                    precedingHeight * 0.5
                        + lineSpacing
                        + focusHeight * 0.5
                )
            }
        }
        let followingIndex = focusIndex + 1
        if followingIndex < lyrics.endIndex {
            let followingID = lyrics[followingIndex].id
            if let followingHeight =
                lyricGeometryCache.layoutHeights[followingID] {
                neighboringStrides.append(
                    focusHeight * 0.5
                        + lineSpacing
                        + followingHeight * 0.5
                )
            }
        }

        guard !neighboringStrides.isEmpty else {
            return max(fallback, 1)
        }
        let measuredStride = neighboringStrides.reduce(0, +)
            / CGFloat(neighboringStrides.count)
        return measuredStride.isFinite
            ? max(measuredStride, 1)
            : max(fallback, 1)
    }

    private func lyricAccessibilityValue(
        isPlaybackLine: Bool,
        isBrowsingFocus: Bool
    ) -> String {
        switch (isPlaybackLine, isBrowsingFocus) {
        case (true, true): L10n.string("ui.lyrics.current_browse_focus")
        case (true, false): L10n.string("ui.player.now_playing")
        case (false, true): L10n.string("ui.lyrics.browse_focus")
        case (false, false): ""
        }
    }

    nonisolated private static func lyricDistanceBlurRadius(
        forPixelDistance distance: CGFloat,
        lyricStride: CGFloat,
        intensity: CGFloat,
        focusProgress: CGFloat,
        motionProfile: AppleMusicLyricsMotionProfile?
    ) -> CGFloat {
        let lineDistance = max(distance / max(lyricStride, 1), 0)
        let baseRadius: CGFloat
        if let motionProfile {
            let nonFocusedRadius = max(
                CGFloat(motionProfile.nonFocusedBlurRadius),
                0
            )
            let maximumRadius = max(
                CGFloat(motionProfile.maximumNonFocusedBlurRadius),
                nonFocusedRadius
            )
            let maximumBlurProgress = min(
                max(lineDistance - 1, 0),
                1
            )
            baseRadius = nonFocusedRadius
                + (maximumRadius - nonFocusedRadius)
                    * maximumBlurProgress
        } else {
            let blurProgress = max(lineDistance - 1.35, 0)
            baseRadius = min(blurProgress * 3.1, 10)
        }
        let normalizedFocusProgress = min(
            max(focusProgress, 0),
            1
        )
        return baseRadius
            * max(intensity, 0)
            * (1 - normalizedFocusProgress)
    }

    nonisolated private static func isValidLyricFrame(
        _ frame: CGRect
    ) -> Bool {
        !frame.isNull
            && !frame.isInfinite
            && !frame.isEmpty
            && frame.minY.isFinite
            && frame.maxY.isFinite
    }

    nonisolated private static func isLyricFrameVisible(
        _ frame: CGRect,
        movementOffset: CGFloat = 0,
        viewportHeight: CGFloat
    ) -> Bool {
        guard isValidLyricFrame(frame),
              movementOffset.isFinite,
              viewportHeight.isFinite,
              viewportHeight > 0 else {
            return false
        }

        return frame.maxY + movementOffset > 0
            && frame.minY + movementOffset < viewportHeight
    }

    nonisolated private static func lyricVisualDistance(
        visualMidY: CGFloat,
        focusAnchorY: CGFloat,
        expandedBottomProgress: CGFloat
    ) -> CGFloat {
        let signedDistance = visualMidY - focusAnchorY
        guard signedDistance > 0 else {
            return abs(signedDistance)
        }
        let progress = min(max(expandedBottomProgress, 0), 1)
        let distanceScale =
            1
            + (expandedBottomDistanceScale - 1) * progress
        return signedDistance * distanceScale
    }

    nonisolated private static func lyricFocusBlurRadius(
        intensity: CGFloat,
        isPrecedingFocusLine: Bool,
        isFollowingFocusLine: Bool,
        motionProfile: AppleMusicLyricsMotionProfile?
    ) -> CGFloat {
        guard let motionProfile = motionProfile else {
            let precedingLineRadius: CGFloat =
                isPrecedingFocusLine ? 2.4 : 0
            let followingLineRadius: CGFloat =
                isFollowingFocusLine ? 0.7 : 0
            return (precedingLineRadius + followingLineRadius)
                * intensity
        }
        _ = motionProfile
        return 0
    }

    nonisolated private static func lyricOpacity(
        forPixelDistance distance: CGFloat,
        lyricStride: CGFloat,
        dimAmount: Double,
        focusProgress: CGFloat
    ) -> Double {
        let lineDistance = Double(distance / lyricStride)
        let baseOpacity: Double
        switch lineDistance {
        case ...1:
            baseOpacity = 1 - lineDistance * 0.44
        case ...2:
            baseOpacity = 0.56 - (lineDistance - 1) * 0.22
        default:
            baseOpacity = max(0.12, 0.34 - (lineDistance - 2) * 0.07)
        }
        let distanceOpacity =
            1 - (1 - baseOpacity) * dimAmount
        let normalizedFocusProgress = Double(
            min(max(focusProgress, 0), 1)
        )
        return distanceOpacity
            + (1 - distanceOpacity) * normalizedFocusProgress
    }

    nonisolated private static func appleMusicLyricFocusOpacity(
        focusProgress: CGFloat,
        motionProfile: AppleMusicLyricsMotionProfile?,
        usesIncreasedContrast: Bool
    ) -> Double {
        guard let motionProfile else { return 1 }
        let selectedOpacity = usesIncreasedContrast
            ? motionProfile.increasedContrastSelectedTextOpacity
            : motionProfile.selectedTextOpacity
        let deselectedOpacity = usesIncreasedContrast
            ? motionProfile.increasedContrastDeselectedTextOpacity
            : motionProfile.deselectedTextOpacity
        let progress = Double(min(max(focusProgress, 0), 1))
        return deselectedOpacity
            + (selectedOpacity - deselectedOpacity) * progress
    }

    nonisolated private static func lyricBottomRevealOpacity(
        frame: CGRect,
        movementOffset: CGFloat,
        viewportHeight: CGFloat
    ) -> Double {
        let visualMinY = frame.minY + movementOffset
        let revealDistance = min(max(frame.height * 0.8, 32), 72)
        let progress = (viewportHeight - visualMinY) / revealDistance
        return Double(min(max(progress, 0), 1))
    }

    nonisolated private static func lyricEmphasis(
        focusProgress: CGFloat,
        isBrowsingFocus: Bool,
        dimAmount: Double
    ) -> Double {
        let baseOpacity = isBrowsingFocus ? 0.7 : 0.52
        let unfocusedOpacity =
            1 - (1 - baseOpacity) * dimAmount
        let normalizedFocusProgress = Double(
            min(max(focusProgress, 0), 1)
        )
        return unfocusedOpacity
            + (1 - unfocusedOpacity) * normalizedFocusProgress
    }

    nonisolated private static func lyricGlowOverflow(
        isEnabled: Bool,
        fontSize: Double,
        intensity: Double
    ) -> CGFloat {
        guard isEnabled else { return 0 }
        return CGFloat(min(max(fontSize * intensity * 0.75, 16), 32))
    }

    private func schedulePlaybackFollowing() {
        guard isBrowsingLyrics, settings.lyricsAutoFollow else {
            followRequest = nil
            return
        }
        followRequest = LyricFollowRequest(
            generation: browsingGeneration,
            delay: max(settings.lyricsFollowDelay, 0)
        )
    }

    private func performPlaybackFollowingRequest() async {
        guard let request = followRequest else { return }
        do {
            try await Task.sleep(for: .seconds(request.delay))
        } catch {
            return
        }
        guard !Task.isCancelled,
              followRequest == request,
              request.generation == browsingGeneration,
              settings.lyricsAutoFollow,
              isBrowsingLyrics,
              !isManuallyScrolling else {
            return
        }
        followRequest = nil
        isBrowsingLyrics = false
    }

    private func handleManualScrollOffsetChange(
        from oldOffset: CGFloat,
        to newOffset: CGFloat
    ) {
        guard isManuallyScrolling,
              let showsInterface = interfaceVisibilityTracker.update(
                offsetDelta: newOffset - oldOffset,
                hideThreshold: CGFloat(
                    settings.appleMusicLyricsScrollHideThreshold
                )
              ) else {
            return
        }

        onInterfaceVisibilityChange?(showsInterface)
    }

    private func requestPlaybackFocus() {
        browsingGeneration += 1
        followRequest = nil
        isBrowsingLyrics = false
        playbackFocusRequestGeneration += 1
    }

    private func synchronizeFocusWithPlayback() {
        let interlude = focusedInterlude
        let playbackLyricID =
            playbackFocus?.lyricID
            ?? highlightedLyricID
        guard let focusID =
            interlude?.id
                ?? playbackLyricID
                ?? lyrics.first?.id else {
            return
        }
        let visualFocusID = interlude == nil
            ? playbackLyricID
            : nil
        guard scrollPositionID != focusID
                || visualHighlightedLyricID != visualFocusID
                || visualCascadeFocusLyricID != visualFocusID
                || isBrowsingLyrics else {
            return
        }

        browsingGeneration += 1
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isBrowsingLyrics = false
            scrollPositionID = focusID
            visualHighlightedLyricID = visualFocusID
            lyricFocusColorTransition = nil
            visualCascadeFocusLyricID = visualFocusID
            lyricMovementOffsetByID = interlude == nil
                ? focusedLineFollowingOffsets(
                    for: playbackLyricID
                )
                : [:]
            lyricMovementTransition = nil
            retainedCascadeLyrics.removeAll()
        }
    }

    private func seek(to line: LyricLine) {
        guard settings.lyricsTapToSeek else { return }
        seekFeedback = LyricSeekFeedback(
            lyricID: line.id,
            previousFocusLyricID: visualCascadeFocusLyricID,
            playerSeekRevision: player.seekRevision + 1,
            startedAt: .now,
            minimumHoldDuration:
                accessibilityReduceMotion
                    ? 0
                    : LyricPlaybackTimeline.focusAnimationDuration(
                        for: line.id,
                        in: lyrics
                    )
        )
        browsingGeneration += 1
        isBrowsingLyrics = false
        player.seek(to: line.time)
    }

    private func holdSeekFeedbackUntilFocusCompletes(
        viewportHeight: CGFloat
    ) async {
        guard let feedback = seekFeedback else { return }

        for _ in 0..<250 {
            guard !Task.isCancelled,
                  seekFeedback == feedback else {
                return
            }

            if hasCompletedSeekMovement(
                feedback,
                viewportHeight: viewportHeight
            ) {
                completeSeekFeedback(
                    feedback
                )
                return
            }

            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return
            }
        }

        guard seekFeedback == feedback else { return }
        completeSeekFeedback(
            feedback
        )
    }

    private func hasCompletedSeekMovement(
        _ feedback: LyricSeekFeedback,
        viewportHeight: CGFloat
    ) -> Bool {
        let id = feedback.lyricID
        guard visualCascadeFocusLyricID == id,
              Date.now.timeIntervalSince(feedback.startedAt)
                >= feedback.minimumHoldDuration,
              visualHighlightedLyricID == id,
              scrollPositionID == id,
              let frame = lyricGeometryCache.frames[id] else {
            return false
        }

        let movementOffset: CGFloat
        if lyricMovementTransition?.focusID == id,
           let presentation = lyricMovementTransition?
            .presentationStates(at: .now)[id] {
            movementOffset = presentation.offset
        } else {
            movementOffset = lyricMovementOffsetByID[id, default: 0]
        }

        let focusPosition = lyricsFocusPosition(for: viewportHeight)
        let visualAnchorY =
            frame.minY
            + movementOffset
            + frame.height * focusPosition
        let viewportAnchorY = viewportHeight * focusPosition
        return abs(visualAnchorY - viewportAnchorY) <= 2
    }

    private func completeSeekFeedback(
        _ feedback: LyricSeekFeedback
    ) {
        guard seekFeedback == feedback else { return }

        withAnimation(
            accessibilityReduceMotion
                ? nil
                : lyricFocusScaleAnimation(isFocused: true)
        ) {
            seekFeedback = nil
        }
    }

    private func completeSeekFeedbackIfNeeded(
        for lyricID: LyricLine.ID
    ) {
        guard let feedback = seekFeedback,
              feedback.lyricID == lyricID else {
            return
        }
        completeSeekFeedback(feedback)
    }

    private func lyricInteractionAccessibilityHint(
        allowsShare: Bool
    ) -> String {
        switch (
            settings.lyricsTapToSeek,
            settings.lyricsLongPressToShare && allowsShare
        ) {
        case (true, true):
            L10n.string("ui.lyrics.tap_seek_long_press_share")
        case (true, false):
            L10n.string("ui.lyrics.tap_seek_hint")
        case (false, true):
            L10n.string("ui.lyrics.long_press_share_hint")
        case (false, false):
            L10n.string("ui.lyrics.interaction_disabled_hint")
        }
    }

    private func presentShare(for line: LyricLine) {
        guard settings.lyricsLongPressToShare,
              line.text.count
                <= LyricsSelectionManager.defaultCharacterLimit,
              let song = player.currentSong else {
            return
        }
        onInterfaceInteraction?()
        lyricSharePresentation = LyricSharePresentation(
            song: song,
            lyrics: lyrics,
            initialLyricID: line.id
        )
    }

    private func moveFocus(to id: LyricLine.ID, animated: Bool) {
        let update = {
            scrollPositionID = id
        }

        if animated, !accessibilityReduceMotion {
            let fallbackDuration =
                LyricPlaybackTimeline.focusAnimationDuration(
                    for: id,
                    in: lyrics
                )
            withAnimation(
                lyricLineChangeAnimation(
                    fallback: .smooth(duration: fallbackDuration)
                ),
                update
            )
        } else {
            update()
        }
    }

    private func lyricLineChangeAnimation(
        fallback: Animation
    ) -> Animation {
        guard let spring = settings.appleMusicLyricsMotionProfile?
            .lineChangeSpring else {
            return fallback
        }
        return lyricPhysicalSpringAnimation(spring)
    }

    private func ensureFocusAlignment(
        to id: LyricLine.ID,
        viewportHeight: CGFloat,
        animated: Bool
    ) async {
        let focusPosition = lyricsFocusPosition(for: viewportHeight)
        let viewportAnchorY = viewportHeight * focusPosition

        if let frame = lyricGeometryCache.frames[id] {
            let currentAnchorY = frame.minY + frame.height * focusPosition
            if abs(currentAnchorY - viewportAnchorY) <= 2 {
                return
            }
        }

        for attempt in 0..<3 {
            guard !Task.isCancelled else { return }

            if scrollPositionID == id || attempt > 0 {
                var resetTransaction = Transaction(animation: nil)
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) {
                    scrollPositionID = nil
                }
                await Task.yield()
                guard !Task.isCancelled else { return }
            }

            moveFocus(to: id, animated: animated && attempt == 0)
            let isAligned = await waitForPreparedFocus(
                id: id,
                viewportAnchorY: viewportAnchorY,
                focusPosition: focusPosition
            )
            if isAligned {
                return
            }
        }
    }
}

private enum AppleMusicLyricsDisplayItem: Identifiable {
    case interlude(LyricInterlude)
    case lyric(LyricLine)

    var id: String {
        switch self {
        case let .interlude(interlude):
            interlude.id
        case let .lyric(line):
            line.id
        }
    }
}

private struct LyricFocusMovementTrigger: Hashable {
    let highlightedLyricID: LyricLine.ID?
    let interludeID: LyricInterlude.ID?
    let visibleInterludeID: LyricInterlude.ID?
    let isActive: Bool
    let isBrowsingLyrics: Bool
    let playbackFocusRequestGeneration: Int
}

private struct LyricFollowRequest: Hashable {
    let id = UUID()
    let generation: Int
    let delay: TimeInterval
}

private struct LyricSeekFeedback: Hashable {
    let token = UUID()
    let lyricID: LyricLine.ID
    let previousFocusLyricID: LyricLine.ID?
    let playerSeekRevision: Int
    let startedAt: Date
    let minimumHoldDuration: TimeInterval
}

private nonisolated struct LyricGeometryMeasurement:
    Equatable,
    Sendable
{
    let frame: CGRect
    let layoutHeight: CGFloat
}
