import SwiftUI

struct LyricTimingTextAttribute: TextAttribute, Hashable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let syllableStartTime: TimeInterval
    let syllableEndTime: TimeInterval
    let characterIndex: Int
    let characterCount: Int
}

/// Renders timed lyric runs in the coordinates supplied by SwiftUI.
/// Each glyph fades uniformly from its unplayed style to white, avoiding a
/// sweeping highlight that competes with the lyric glow. The played glyph and
/// its original glow are composited once before lift and long-syllable scale
/// transforms are applied, keeping their relative brightness stable.
struct LyricGlowTextRenderer: TextRenderer {
    struct Style: Equatable, Sendable {
        let glowRadius: CGFloat
        let glowOpacity: Double
        let unplayedOpacity: Double
        let maximumUnplayedBlurRadius: CGFloat
        let playedRise: CGFloat
        let maximumLongSyllableScale: CGFloat
        let longSyllableExpansionPadding: CGFloat

        fileprivate var drawsGlow: Bool {
            glowRadius > 0 && glowOpacity > 0
        }
    }

    struct LayoutConfiguration: Equatable, Sendable {
        let width: CGFloat?
        let centersLines: Bool

        fileprivate var constrainedWidth: CGFloat? {
            guard let width, width.isFinite, width > 0 else { return nil }
            return width
        }
    }

    static let glowTailDuration: TimeInterval = 0.55

    var playbackTime: TimeInterval
    let style: Style
    let layoutConfiguration: LayoutConfiguration

    var animatableData: Double {
        get { playbackTime }
        set { playbackTime = newValue }
    }

    var displayPadding: EdgeInsets {
        let padding = style.glowRadius * Metrics.displayPaddingMultiplier
        let expansionPadding = max(style.longSyllableExpansionPadding, 0)
        return EdgeInsets(
            top: padding + max(style.playedRise, 0) + expansionPadding,
            leading: padding + expansionPadding,
            bottom: padding + expansionPadding,
            trailing: padding + expansionPadding
        )
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        text: TextProxy
    ) -> CGSize {
        guard let width = layoutConfiguration.constrainedWidth else {
            return text.sizeThatFits(proposal)
        }

        let measuredSize = text.sizeThatFits(
            ProposedViewSize(width: width, height: proposal.height)
        )
        return CGSize(width: width, height: measuredSize.height)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            var lineContext = context
            lineContext.translateBy(x: horizontalOffset(for: line), y: 0)

            for run in line {
                draw(run, in: &lineContext)
            }
        }
    }

    private func horizontalOffset(for line: Text.Layout.Line) -> CGFloat {
        guard layoutConfiguration.centersLines,
              let width = layoutConfiguration.constrainedWidth else {
            return 0
        }

        let lineBounds = line.typographicBounds.rect
        guard lineBounds.width.isFinite,
              lineBounds.midX.isFinite else {
            return 0
        }
        return width * 0.5 - lineBounds.midX
    }

    private func draw(
        _ run: Text.Layout.Run,
        in context: inout GraphicsContext
    ) {
        guard let timing = run[LyricTimingTextAttribute.self] else {
            context.draw(run)
            return
        }

        let state = visualState(for: timing)
        drawUnplayed(
            run,
            revealProgress: state.revealProgress,
            blurRadius: state.unplayedBlurRadius,
            in: &context
        )
        guard state.revealProgress > 0 else { return }

        drawPlayed(
            run,
            revealProgress: state.revealProgress,
            liftProgress: state.liftProgress,
            expansionScale: state.expansionScale,
            rawProgress: state.rawProgress,
            glowStrength: state.glowStrength,
            in: &context
        )
    }

    private func visualState(
        for timing: LyricTimingTextAttribute
    ) -> RunVisualState {
        let rawProgress = playedProgress(for: timing)
        let glowStrength = style.drawsGlow && rawProgress > 0
            ? glowStrength(for: timing, rawProgress: rawProgress)
            : 0

        return RunVisualState(
            rawProgress: rawProgress,
            revealProgress: smootherStep(rawProgress),
            liftProgress: liftProgress(for: timing),
            expansionScale: expansionScale(for: timing),
            unplayedBlurRadius: unplayedBlurRadius(for: timing),
            glowStrength: glowStrength
        )
    }

    private func liftProgress(
        for timing: LyricTimingTextAttribute
    ) -> Double {
        guard playbackTime > timing.startTime else { return 0 }

        let transitionEndTime = timing.endTime
            + Metrics.liftContinuationDuration
        let transitionDuration = transitionEndTime - timing.startTime
        guard transitionDuration > 0 else { return 1 }
        return smootherStep(
            (playbackTime - timing.startTime) / transitionDuration
        )
    }

    private func expansionScale(
        for timing: LyricTimingTextAttribute
    ) -> CGFloat {
        let maximumScale = max(style.maximumLongSyllableScale, 1)
        let syllableDuration = timing.syllableEndTime
            - timing.syllableStartTime
        guard maximumScale > 1,
              syllableDuration >= Metrics.longSyllableDurationThreshold,
              timing.characterCount > 0 else {
            return 1
        }

        let characterDuration = syllableDuration
            / Double(timing.characterCount)
        let overlapDuration = min(
            characterDuration * Metrics.expansionOverlapFraction,
            Metrics.maximumExpansionOverlapDuration
        )
        let windowStart = timing.startTime
            - (timing.characterIndex > 0 ? overlapDuration : 0)
        let windowEnd = timing.endTime
            + (timing.characterIndex < timing.characterCount - 1
                ? overlapDuration
                : 0)
        let windowDuration = windowEnd - windowStart
        guard windowDuration > 0,
              playbackTime > windowStart,
              playbackTime < windowEnd else {
            return 1
        }

        let rawProgress = unitProgress(
            (playbackTime - windowStart) / windowDuration
        )
        let envelope = sin(.pi * smootherStep(rawProgress))
        return 1 + (maximumScale - 1) * CGFloat(envelope)
    }

    private func drawUnplayed(
        _ run: Text.Layout.Run,
        revealProgress: Double,
        blurRadius: CGFloat,
        in context: inout GraphicsContext
    ) {
        var unplayedContext = context
        unplayedContext.opacity = style.unplayedOpacity
            * (1 - unitProgress(revealProgress))
        if blurRadius > 0 {
            unplayedContext.addFilter(.blur(radius: blurRadius))
        }
        unplayedContext.draw(run)
    }

    private func drawPlayed(
        _ run: Text.Layout.Run,
        revealProgress: Double,
        liftProgress: Double,
        expansionScale: CGFloat,
        rawProgress: Double,
        glowStrength: Double,
        in context: inout GraphicsContext
    ) {
        let revealedBounds = revealedBounds(
            of: run,
            progress: revealProgress
        )
        let verticalOffset = -max(style.playedRise, 0)
            * CGFloat(unitProgress(liftProgress))
        let scale = max(expansionScale, 1)
        let bounds = run.typographicBounds.rect
        var playedContext = context
        if verticalOffset != 0 || scale != 1 {
            let transform = CGAffineTransform(
                a: scale,
                b: 0,
                c: 0,
                d: scale,
                tx: bounds.midX * (1 - scale),
                ty: bounds.midY * (1 - scale) + verticalOffset
            )
            playedContext.addFilter(
                .projectionTransform(ProjectionTransform(transform))
            )
        }

        playedContext.drawLayer { layer in
            if glowStrength > 0 {
                drawGlow(
                    for: run,
                    revealedBounds: revealedBounds,
                    rawProgress: rawProgress,
                    strength: glowStrength,
                    in: &layer
                )
            }

            var textContext = layer
            textContext.opacity = unitProgress(revealProgress)
            textContext.draw(run)
        }
    }

    private func drawGlow(
        for run: Text.Layout.Run,
        revealedBounds: CGRect,
        rawProgress: Double,
        strength: Double,
        in context: inout GraphicsContext
    ) {
        let pulse = 1 + Metrics.glowPulseAmount * sin(.pi * rawProgress)
        let baseOpacity = style.glowOpacity * strength

        drawGlowLayer(
            for: run,
            revealedBounds: revealedBounds,
            radius: style.glowRadius
                * Metrics.outerGlowRadiusMultiplier
                * CGFloat(pulse),
            opacity: min(baseOpacity * Metrics.outerGlowOpacityMultiplier, 1),
            in: &context
        )
        drawGlowLayer(
            for: run,
            revealedBounds: revealedBounds,
            radius: style.glowRadius
                * Metrics.innerGlowRadiusMultiplier
                * CGFloat(pulse),
            opacity: min(baseOpacity, 1),
            in: &context
        )
    }

    private func drawGlowLayer(
        for run: Text.Layout.Run,
        revealedBounds: CGRect,
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
            layer.clip(to: Path(revealedBounds))
            layer.draw(run)
        }
    }

    private func revealedBounds(
        of run: Text.Layout.Run,
        progress: Double
    ) -> CGRect {
        let bounds = run.typographicBounds.rect
        let revealedWidth = bounds.width * CGFloat(unitProgress(progress))
        let originX = run.layoutDirection == .rightToLeft
            ? bounds.maxX - revealedWidth
            : bounds.minX

        return CGRect(
            x: originX,
            y: bounds.minY,
            width: revealedWidth,
            height: bounds.height
        )
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

    private func glowStrength(
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
            return attack * breath
        }

        let tailProgress = (playbackTime - timing.endTime)
            / Self.glowTailDuration
        guard tailProgress < 1 else { return 0 }
        return (1 - smootherStep(tailProgress)) * Metrics.minimumGlowStrength
    }

    private func smootherStep(_ value: Double) -> Double {
        let progress = unitProgress(value)
        return progress * progress * progress
            * (progress * (progress * 6 - 15) + 10)
    }

    private func unitProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

private extension LyricGlowTextRenderer {
    struct RunVisualState {
        let rawProgress: Double
        let revealProgress: Double
        let liftProgress: Double
        let expansionScale: CGFloat
        let unplayedBlurRadius: CGFloat
        let glowStrength: Double
    }

    enum Metrics {
        static let displayPaddingMultiplier: CGFloat = 6
        static let unplayedBlurLeadDuration: TimeInterval = 2.4
        static let minimumUnplayedBlurFraction = 0.12
        static let glowAttackProgress = 0.24
        static let minimumGlowStrength = 0.82
        static let glowPulseAmount = 0.2
        static let liftContinuationDuration: TimeInterval = 0.32
        static let longSyllableDurationThreshold: TimeInterval = 0.7
        static let expansionOverlapFraction = 0.32
        static let maximumExpansionOverlapDuration: TimeInterval = 0.14
        static let outerGlowRadiusMultiplier: CGFloat = 1.75
        static let outerGlowOpacityMultiplier = 0.72
        static let innerGlowRadiusMultiplier: CGFloat = 0.62
    }
}
