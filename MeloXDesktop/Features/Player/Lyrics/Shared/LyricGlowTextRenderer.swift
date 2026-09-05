import SwiftUI

nonisolated struct LyricTimingTextAttribute: TextAttribute, Hashable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let syllableStartTime: TimeInterval
    let syllableEndTime: TimeInterval
    let characterIndex: Int
    let characterCount: Int
    let wordStartTime: TimeInterval
    let wordEndTime: TimeInterval
    let wordCharacterIndex: Int
    let wordCharacterCount: Int
    let usesWordTimingForLongTone: Bool
    let isWhitespace: Bool
}

struct LyricFocusOpacityEndpoints: Equatable, Sendable {
    let deselected: Double
    let selected: Double
    let selectedUpcoming: Double

    func relativeUpcomingOpacity(at progress: Double) -> Double {
        let progress = Self.unit(progress)
        let outer = deselected + (selected - deselected) * progress
        let upcoming = deselected
            + (selectedUpcoming - deselected) * progress
        guard outer > 0 else { return 0 }
        return Self.unit(upcoming / outer)
    }

    private static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

/// Renders timed lyric runs in the coordinates supplied by SwiftUI.
/// Each glyph keeps its unplayed style while the played style is revealed
/// horizontally across it. Long tones use a staggered per-character emphasis
/// envelope: every glyph expands around its own center, blooms, then settles
/// while the following glyphs enter the same animation. Glow and text stay
/// composited through all transforms.
struct LyricGlowTextRenderer: TextRenderer {
    struct Style: Equatable, Sendable {
        let glowRadius: CGFloat
        let glowOpacity: Double
        let glowsLongSyllablesOnly: Bool
        let longSyllableDetectionMode:
            LyricsLongSyllableDetectionMode
        let longSyllableDurationThreshold: TimeInterval
        let unplayedOpacity: Double
        let focusOpacityEndpoints: LyricFocusOpacityEndpoints?
        let maximumUnplayedBlurRadius: CGFloat
        let playedRise: CGFloat
        let maximumLongSyllableScale: CGFloat
        let longSyllableExpansionPadding: CGFloat
        let highlightGradientWidth: CGFloat
        let lineProgressionGradientFeather: CGFloat?
        let highlightGradientReduction: CGFloat
        let lineFinishProgressAnimationDuration: TimeInterval?
        let liftMode: LyricsLiftMode

        fileprivate var drawsGlow: Bool {
            glowRadius > 0 && glowOpacity > 0
        }
    }

    struct LayoutConfiguration: Equatable, Sendable {
        let width: CGFloat?
        let centersLines: Bool
        let trailingVisualOverflow: CGFloat

        init(
            width: CGFloat?,
            centersLines: Bool,
            trailingVisualOverflow: CGFloat = 0
        ) {
            self.width = width
            self.centersLines = centersLines
            self.trailingVisualOverflow = trailingVisualOverflow
        }

        fileprivate var constrainedWidth: CGFloat? {
            guard let width, width.isFinite, width > 0 else { return nil }
            return width
        }
    }

    static let glowTailDuration: TimeInterval = 0.55

    var playbackTime: TimeInterval
    let style: Style
    let layoutConfiguration: LayoutConfiguration
    let appliesTimingEffects: Bool
    var timingEffectsStrength: Double

    var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(
                playbackTime,
                timingEffectsStrength
            )
        }
        set {
            playbackTime = newValue.first
            timingEffectsStrength = newValue.second
        }
    }

    var displayPadding: EdgeInsets {
        let padding = style.glowRadius * Metrics.displayPaddingMultiplier
        let expansionPadding = max(style.longSyllableExpansionPadding, 0)
        return EdgeInsets(
            top: padding + max(style.playedRise, 0) + expansionPadding,
            leading: padding + expansionPadding,
            bottom: padding + expansionPadding,
            trailing:
                padding
                + expansionPadding
                + max(layoutConfiguration.trailingVisualOverflow, 0)
        )
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let effectsStrength = effectiveTimingEffectsStrength
        if layoutConfiguration.centersLines {
            // TextRenderer offsets drawing by its leading display padding.
            // Left-aligned lyrics have their own inset, but centered Skyline
            // lyrics need that rasterization-only padding removed so the
            // visible glyph bounds stay on the SwiftUI layout center.
            context.translateBy(x: -displayPadding.leading, y: 0)
        }

        for line in layout {
            var lineContext = context
            if let transform = LyricLineFitting.drawingTransform(
                for: line,
                constrainedWidth: layoutConfiguration.constrainedWidth,
                centersLine: layoutConfiguration.centersLines,
                trailingSafety: style.longSyllableExpansionPadding
            ) {
                lineContext.addFilter(
                    .projectionTransform(ProjectionTransform(transform))
                )
            }

            if effectsStrength > 0,
               style.lineProgressionGradientFeather != nil {
                drawAppleMusicLine(
                    line,
                    effectsStrength: effectsStrength,
                    in: &lineContext
                )
            } else {
                drawRuns(
                    in: line,
                    effectsStrength: effectsStrength,
                    context: &lineContext
                )
            }
        }
    }

    private func drawRuns(
        in line: Text.Layout.Line,
        effectsStrength: Double,
        context: inout GraphicsContext
    ) {
        for run in line {
            var runContext = context
            applyRubyOffset(for: run, to: &runContext)
            if effectsStrength > 0 {
                draw(
                    run,
                    effectsStrength: effectsStrength,
                    in: &runContext
                )
            } else {
                runContext.draw(run)
            }
        }
    }

    /// LyricsX owns one progression gradient per visual line. Syllable and
    /// glyph layers may still lift or expand independently, but they all share
    /// this single reveal front. Drawing a separate feather for every glyph is
    /// visibly different, especially for CJK lyrics with one run per glyph.
    private func drawAppleMusicLine(
        _ line: Text.Layout.Line,
        effectsStrength: Double,
        in context: inout GraphicsContext
    ) {
        let revealMask = appleMusicLineRevealMask(for: line)
        for run in line {
            guard let timing = run[LyricTimingTextAttribute.self] else {
                var runContext = context
                applyRubyOffset(for: run, to: &runContext)
                runContext.draw(run)
                continue
            }

            let state = visualState(for: timing)
            let bounds = run.typographicBounds.rect
            var runContext = context
            applyRubyOffset(for: run, to: &runContext)
            applyLift(
                to: &runContext,
                progress: state.liftProgress,
                effectsStrength: effectsStrength
            )
            let expansionScale = 1
                + (state.expansionScale - 1)
                    * CGFloat(effectsStrength)
            let rawExpansionOffset = expansionOffset(
                layoutDirection: run.layoutDirection,
                bounds: bounds,
                emphasis: state.emphasis
            )
            let expansionOffset = CGSize(
                width: rawExpansionOffset.width * CGFloat(effectsStrength),
                height: rawExpansionOffset.height * CGFloat(effectsStrength)
            )
            if expansionScale != 1 || expansionOffset != .zero {
                applyExpansion(
                    to: &runContext,
                    scale: expansionScale,
                    anchor: CGPoint(x: bounds.midX, y: bounds.midY),
                    offset: expansionOffset
                )
            }

            drawUnplayed(
                run,
                blurRadius:
                    state.unplayedBlurRadius * CGFloat(effectsStrength),
                effectsStrength: effectsStrength,
                in: &runContext
            )
            guard let revealMask else { continue }
            drawPlayed(
                run,
                revealMask: revealMask,
                glowStrength: state.glowStrength * effectsStrength,
                in: &runContext
            )
        }
    }

    private func applyRubyOffset(
        for run: Text.Layout.Run,
        to context: inout GraphicsContext
    ) {
        let horizontalOffset =
            run[LyricRubyPlacementTextAttribute.self]?
                .horizontalOffset ?? 0
        guard horizontalOffset != 0 else { return }
        context.translateBy(x: horizontalOffset, y: 0)
    }

    private func appleMusicLineRevealMask(
        for line: Text.Layout.Line
    ) -> RevealMask? {
        let timedRuns = line.compactMap { run -> (
            Text.Layout.Run,
            LyricTimingTextAttribute
        )? in
            guard let timing = run[LyricTimingTextAttribute.self],
                  !timing.isWhitespace else { return nil }
            return (run, timing)
        }
        guard let first = timedRuns.first,
              playbackTime >= first.1.startTime else { return nil }

        let direction = first.0.layoutDirection
        var frontX = direction == .rightToLeft
            ? first.0.typographicBounds.rect.maxX
            : first.0.typographicBounds.rect.minX

        for (run, timing) in timedRuns {
            let bounds = run.typographicBounds.rect
            guard bounds.width.isFinite, bounds.width > 0 else { continue }
            if playbackTime < timing.startTime {
                break
            }
            if playbackTime >= timing.endTime {
                frontX = direction == .rightToLeft
                    ? bounds.minX
                    : bounds.maxX
                continue
            }

            let duration = timing.endTime - timing.startTime
            let progress = duration > 0
                ? unitProgress(
                    (playbackTime - timing.startTime) / duration
                )
                : 1
            frontX = direction == .rightToLeft
                ? bounds.maxX - bounds.width * CGFloat(progress)
                : bounds.minX + bounds.width * CGFloat(progress)
            break
        }

        let featherWidth = max(
            style.lineProgressionGradientFeather
                ?? Metrics.minimumRevealFeatherWidth,
            Metrics.minimumRevealFeatherWidth
        )
        return RevealMask(
            frontX: frontX,
            featherWidth: featherWidth,
            gradient: highlightGradient(
                reduction: 0,
                layoutDirection: direction
            ),
            layoutDirection: direction
        )
    }

    private func revealMask(
        for run: Text.Layout.Run,
        timing: LyricTimingTextAttribute
    ) -> RevealMask? {
        guard !timing.isWhitespace,
              playbackTime >= timing.startTime else {
            return nil
        }

        let bounds = run.typographicBounds.rect
        guard bounds.width.isFinite,
              bounds.width > 0 else {
            return nil
        }

        let progress = LyricHighlightRevealProgress.progress(
            playbackTime: playbackTime,
            timing: timing,
            detectionMode: style.longSyllableDetectionMode,
            durationThreshold: style.longSyllableDurationThreshold,
            lineFinishProgressAnimationDuration:
                style.lineFinishProgressAnimationDuration
        )
        let gradientWidth = style.highlightGradientWidth.isFinite
            ? max(style.highlightGradientWidth, 0.1)
            : Metrics.defaultHighlightGradientWidth
        let gradientReduction = style.highlightGradientReduction.isFinite
            ? min(max(style.highlightGradientReduction, 0), 1)
            : Metrics.defaultHighlightGradientReduction
        let featherWidth: CGFloat
        if let fixedFeather = style.lineProgressionGradientFeather,
           fixedFeather.isFinite,
           fixedFeather > 0 {
            featherWidth = max(
                fixedFeather,
                Metrics.minimumRevealFeatherWidth
            )
        } else {
            featherWidth = max(
                bounds.width * gradientWidth,
                Metrics.minimumRevealFeatherWidth
            )
        }
        let direction = run.layoutDirection
        let frontX: CGFloat
        if direction == .rightToLeft {
            frontX = bounds.maxX + featherWidth
                - (bounds.width + featherWidth) * CGFloat(progress)
        } else {
            frontX = bounds.minX - featherWidth
                + (bounds.width + featherWidth) * CGFloat(progress)
        }

        return RevealMask(
            frontX: frontX,
            featherWidth: featherWidth,
            gradient: highlightGradient(
                reduction: Double(gradientReduction),
                layoutDirection: direction
            ),
            layoutDirection: direction
        )
    }

    private func highlightGradient(
        reduction: Double,
        layoutDirection: LayoutDirection
    ) -> Gradient {
        let reduction = min(max(reduction, 0), 1)
        let stopCount = Metrics.highlightGradientStopCount
        let stops = (0...stopCount).map { index in
            let location = Double(index) / Double(stopCount)
            let distanceFromFront = layoutDirection == .rightToLeft
                ? 1 - location
                : location
            let remainingHighlight = 1 - distanceFromFront
            let opacity = remainingHighlight
                * (1 - reduction * distanceFromFront)

            return Gradient.Stop(
                color: .white.opacity(opacity),
                location: CGFloat(location)
            )
        }
        return Gradient(stops: stops)
    }

    private func draw(
        _ run: Text.Layout.Run,
        effectsStrength: Double,
        in context: inout GraphicsContext
    ) {
        guard let timing = run[LyricTimingTextAttribute.self] else {
            context.draw(run)
            return
        }

        let state = visualState(for: timing)
        let bounds = run.typographicBounds.rect
        var runContext = context
        applyLift(
            to: &runContext,
            progress: state.liftProgress,
            effectsStrength: effectsStrength
        )
        let expansionScale =
            1
            + (state.expansionScale - 1)
                * CGFloat(effectsStrength)
        let rawExpansionOffset = expansionOffset(
            layoutDirection: run.layoutDirection,
            bounds: bounds,
            emphasis: state.emphasis
        )
        let expansionOffset = CGSize(
            width:
                rawExpansionOffset.width
                * CGFloat(effectsStrength),
            height:
                rawExpansionOffset.height
                * CGFloat(effectsStrength)
        )
        if expansionScale != 1 || expansionOffset != .zero {
            applyExpansion(
                to: &runContext,
                scale: expansionScale,
                anchor: CGPoint(x: bounds.midX, y: bounds.midY),
                offset: expansionOffset
            )
        }

        drawUnplayed(
            run,
            blurRadius:
                state.unplayedBlurRadius
                * CGFloat(effectsStrength),
            effectsStrength: effectsStrength,
            in: &runContext
        )
        let revealMask = revealMask(for: run, timing: timing)
        guard let revealMask else { return }

        drawPlayed(
            run,
            revealMask: revealMask,
            glowStrength:
                state.glowStrength * effectsStrength,
            in: &runContext
        )
    }

    private func visualState(
        for timing: LyricTimingTextAttribute
    ) -> RunVisualState {
        let rawProgress = playedProgress(for: timing)
        let emphasis = LyricLongToneEmphasis.state(
            playbackTime: playbackTime,
            timing: timing,
            detectionMode: style.longSyllableDetectionMode,
            durationThreshold: style.longSyllableDurationThreshold
        )
        let glowStrength: Double
        if style.drawsGlow, emphasis.isLongTone {
            glowStrength = emphasis.envelope * emphasis.glowAmount
        } else if style.drawsGlow,
                  !style.glowsLongSyllablesOnly,
                  rawProgress > 0 {
            glowStrength = ordinaryGlowStrength(
                for: timing,
                rawProgress: rawProgress
            )
        } else {
            glowStrength = 0
        }

        return RunVisualState(
            liftProgress: liftProgress(for: timing),
            expansionScale: 1
                + (max(style.maximumLongSyllableScale, 1) - 1)
                    * CGFloat(
                        emphasis.envelope
                            * emphasis.expansionAmount
                    ),
            emphasis: emphasis,
            unplayedBlurRadius: unplayedBlurRadius(for: timing),
            glowStrength: glowStrength
        )
    }

    private func liftProgress(
        for timing: LyricTimingTextAttribute
    ) -> Double {
        let liftStartTime = style.liftMode == .word
            ? timing.wordStartTime
            : timing.startTime
        let liftEndTime = style.liftMode == .word
            ? timing.wordEndTime
            : timing.endTime
        guard playbackTime > liftStartTime else { return 0 }

        let transitionEndTime = liftEndTime
            + Metrics.liftContinuationDuration
        let transitionDuration = transitionEndTime - liftStartTime
        guard transitionDuration > 0 else { return 1 }
        return smootherStep(
            (playbackTime - liftStartTime) / transitionDuration
        )
    }

    private func expansionOffset(
        layoutDirection: LayoutDirection,
        bounds: CGRect,
        emphasis: LyricLongToneEmphasis.State
    ) -> CGSize {
        emphasis.expansionOffset(
            layoutDirection: layoutDirection,
            glyphBounds: bounds
        )
    }

    private func drawUnplayed(
        _ run: Text.Layout.Run,
        blurRadius: CGFloat,
        effectsStrength: Double,
        in context: inout GraphicsContext
    ) {
        var unplayedContext = context
        if let endpoints = style.focusOpacityEndpoints {
            unplayedContext.opacity = endpoints.relativeUpcomingOpacity(
                at: effectsStrength
            )
        } else {
            let unplayedOpacity = min(
                max(style.unplayedOpacity, 0),
                1
            )
            unplayedContext.opacity =
                1 - (1 - unplayedOpacity) * effectsStrength
        }
        if blurRadius > 0 {
            unplayedContext.addFilter(.blur(radius: blurRadius))
        }
        unplayedContext.draw(run)
    }

    private func drawPlayed(
        _ run: Text.Layout.Run,
        revealMask: RevealMask,
        glowStrength: Double,
        in context: inout GraphicsContext
    ) {
        context.drawLayer { layer in
            if glowStrength > 0 {
                drawGlow(
                    for: run,
                    revealMask: revealMask,
                    strength: glowStrength,
                    in: &layer
                )
            }

            var textContext = layer
            drawRevealed(
                run,
                revealMask: revealMask,
                in: &textContext
            )
        }
    }

    private func applyLift(
        to context: inout GraphicsContext,
        progress: Double,
        effectsStrength: Double
    ) {
        let verticalOffset =
            liftOffset(at: progress)
            * CGFloat(effectsStrength)
        guard verticalOffset != 0 else { return }
        context.addFilter(
            .projectionTransform(
                ProjectionTransform(
                    CGAffineTransform(
                        translationX: 0,
                        y: verticalOffset
                    )
                )
            )
        )
    }

    private func applyExpansion(
        to context: inout GraphicsContext,
        scale: CGFloat,
        anchor: CGPoint,
        offset: CGSize
    ) {
        let scale = max(scale, 1)
        guard scale != 1 || offset != .zero else { return }
        context.addFilter(
            .projectionTransform(
                ProjectionTransform(
                    CGAffineTransform(
                        a: scale,
                        b: 0,
                        c: 0,
                        d: scale,
                        tx: anchor.x * (1 - scale) + offset.width,
                        ty: anchor.y * (1 - scale) + offset.height
                    )
                )
            )
        )
    }

    private func liftOffset(
        at progress: Double
    ) -> CGFloat {
        -max(style.playedRise, 0)
            * CGFloat(unitProgress(progress))
    }

    private func drawGlow(
        for run: Text.Layout.Run,
        revealMask: RevealMask,
        strength: Double,
        in context: inout GraphicsContext
    ) {
        let baseOpacity = style.glowOpacity * strength

        drawGlowLayer(
            for: run,
            revealMask: revealMask,
            radius: style.glowRadius
                * Metrics.outerGlowRadiusMultiplier,
            opacity: min(baseOpacity * Metrics.outerGlowOpacityMultiplier, 1),
            in: &context
        )
        drawGlowLayer(
            for: run,
            revealMask: revealMask,
            radius: style.glowRadius
                * Metrics.innerGlowRadiusMultiplier,
            opacity: min(baseOpacity, 1),
            in: &context
        )
    }

    private func drawGlowLayer(
        for run: Text.Layout.Run,
        revealMask: RevealMask,
        radius: CGFloat,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        guard radius > 0, opacity > 0 else { return }

        var glowContext = context
        glowContext.opacity = opacity
        glowContext.blendMode = .plusLighter
        glowContext.addFilter(.blur(radius: radius))
        glowContext.drawLayer { layer in
            drawRevealed(
                run,
                revealMask: revealMask,
                in: &layer
            )
        }
    }

    private func drawRevealed(
        _ run: Text.Layout.Run,
        revealMask: RevealMask,
        in context: inout GraphicsContext
    ) {
        let bounds = run.typographicBounds.rect
        guard bounds.width > 0, bounds.height > 0 else { return }

        let startPoint: CGPoint
        let endPoint: CGPoint

        if revealMask.layoutDirection == .rightToLeft {
            startPoint = CGPoint(
                x: revealMask.frontX - revealMask.featherWidth,
                y: bounds.midY
            )
            endPoint = CGPoint(
                x: revealMask.frontX,
                y: bounds.midY
            )
        } else {
            startPoint = CGPoint(
                x: revealMask.frontX,
                y: bounds.midY
            )
            endPoint = CGPoint(
                x: revealMask.frontX + revealMask.featherWidth,
                y: bounds.midY
            )
        }

        context.clipToLayer { maskContext in
            maskContext.fill(
                Path(bounds),
                with: .linearGradient(
                    revealMask.gradient,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
        }
        context.draw(run)
    }

    private func unplayedBlurRadius(
        for timing: LyricTimingTextAttribute
    ) -> CGFloat {
        guard style.maximumUnplayedBlurRadius > 0,
              playbackTime < timing.startTime else {
            return 0
        }

        let leadTime = timing.startTime - playbackTime
        let distance = smootherStep(
            leadTime / Metrics.unplayedBlurLeadDuration
        )
        let blurFraction = Metrics.minimumUnplayedBlurFraction
            + (1 - Metrics.minimumUnplayedBlurFraction) * distance
        return style.maximumUnplayedBlurRadius * CGFloat(blurFraction)
    }

    private func playedProgress(
        for timing: LyricTimingTextAttribute
    ) -> Double {
        guard playbackTime >= timing.startTime else { return 0 }
        guard playbackTime < timing.endTime else { return 1 }

        let duration = timing.endTime - timing.startTime
        guard duration > 0 else { return 1 }
        return unitProgress((playbackTime - timing.startTime) / duration)
    }

    private func ordinaryGlowStrength(
        for timing: LyricTimingTextAttribute,
        rawProgress: Double
    ) -> Double {
        if playbackTime <= timing.endTime {
            let attack = smootherStep(
                rawProgress / Metrics.glowAttackProgress
            )
            let breath = Metrics.minimumGlowStrength
                + (1 - Metrics.minimumGlowStrength)
                    * sin(.pi * rawProgress)
            return attack
                * breath
                * Metrics.ordinaryGlowStrengthMultiplier
        }

        let tailProgress = (playbackTime - timing.endTime)
            / Self.glowTailDuration
        guard tailProgress < 1 else { return 0 }
        return (1 - smootherStep(tailProgress))
            * Metrics.minimumGlowStrength
            * Metrics.ordinaryGlowStrengthMultiplier
    }

    private func smootherStep(_ value: Double) -> Double {
        let progress = unitProgress(value)
        return progress * progress * progress
            * (progress * (progress * 6 - 15) + 10)
    }

    private func unitProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private var effectiveTimingEffectsStrength: Double {
        guard appliesTimingEffects else { return 0 }
        return unitProgress(timingEffectsStrength)
    }
}

private extension LyricGlowTextRenderer {
    struct RevealMask {
        let frontX: CGFloat
        let featherWidth: CGFloat
        let gradient: Gradient
        let layoutDirection: LayoutDirection
    }

    struct RunVisualState {
        let liftProgress: Double
        let expansionScale: CGFloat
        let emphasis: LyricLongToneEmphasis.State
        let unplayedBlurRadius: CGFloat
        let glowStrength: Double
    }

    enum Metrics {
        static let displayPaddingMultiplier: CGFloat = 6
        static let unplayedBlurLeadDuration: TimeInterval = 2.4
        static let minimumUnplayedBlurFraction = 0.12
        static let glowAttackProgress = 0.24
        static let minimumGlowStrength = 0.82
        static let ordinaryGlowStrengthMultiplier = 0.55
        static let liftContinuationDuration: TimeInterval = 0.32
        static let outerGlowRadiusMultiplier: CGFloat = 1
        static let outerGlowOpacityMultiplier = 0.55
        static let innerGlowRadiusMultiplier: CGFloat = 0.35
        static let defaultHighlightGradientWidth: CGFloat = 0.7
        static let defaultHighlightGradientReduction: CGFloat = 0.65
        static let highlightGradientStopCount = 8
        static let minimumRevealFeatherWidth: CGFloat = 2
    }
}
