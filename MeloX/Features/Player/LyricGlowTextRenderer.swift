import SwiftUI

struct LyricTimingTextAttribute: TextAttribute, Hashable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
}

/// Draws the dim lyric first, then reveals the played part of each timed run.
/// The played mask is rendered into a separate blurred layer so the glow can
/// extend beyond the glyph while never using an unplayed glyph as its source.
struct LyricGlowTextRenderer: TextRenderer {
    var playbackTime: TimeInterval
    let glowRadius: CGFloat
    let glowOpacity: Double
    let unplayedOpacity: Double
    let maximumUnplayedBlurRadius: CGFloat

    var animatableData: Double {
        get { playbackTime }
        set { playbackTime = newValue }
    }

    var displayPadding: EdgeInsets {
        let padding = glowRadius * 6
        return EdgeInsets(
            top: padding,
            leading: padding,
            bottom: padding,
            trailing: padding
        )
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                guard let timing = run[LyricTimingTextAttribute.self] else {
                    context.draw(run)
                    continue
                }

                let rawProgress = rawPlayedProgress(for: timing)
                drawUnplayed(
                    run,
                    timing: timing,
                    in: &context
                )
                guard rawProgress > 0 else { continue }
                let revealProgress = smootherStep(rawProgress)

                let playedBounds = playedBounds(
                    in: run.typographicBounds.rect,
                    progress: revealProgress,
                    layoutDirection: run.layoutDirection
                )

                let glowStrength = glowStrength(
                    for: timing,
                    rawProgress: rawProgress
                )
                if glowRadius > 0, glowOpacity > 0, glowStrength > 0 {
                    let radiusPulse = 1 + 0.2 * sin(.pi * rawProgress)
                    drawGlow(
                        run,
                        playedBounds: playedBounds,
                        radius: glowRadius * 1.75 * CGFloat(radiusPulse),
                        opacity: min(glowOpacity * glowStrength * 0.72, 1),
                        in: &context
                    )
                    drawGlow(
                        run,
                        playedBounds: playedBounds,
                        radius: glowRadius * 0.62 * CGFloat(radiusPulse),
                        opacity: min(glowOpacity * glowStrength, 1),
                        in: &context
                    )
                }

                var playedContext = context
                playedContext.clip(to: Path(playedBounds))
                playedContext.draw(run)
            }
        }
    }

    private func drawUnplayed(
        _ run: Text.Layout.Run,
        timing: LyricTimingTextAttribute,
        in context: inout GraphicsContext
    ) {
        var unplayedContext = context
        unplayedContext.opacity = unplayedOpacity

        let blurRadius = unplayedBlurRadius(for: timing)
        if blurRadius > 0 {
            unplayedContext.addFilter(.blur(radius: blurRadius))
        }
        unplayedContext.draw(run)
    }

    private func unplayedBlurRadius(for timing: LyricTimingTextAttribute) -> CGFloat {
        guard maximumUnplayedBlurRadius > 0,
              playbackTime < timing.startTime else { return 0 }

        let leadTime = timing.startTime - playbackTime
        let distanceProgress = min(max(leadTime / 2.4, 0), 1)
        let easedDistance = smootherStep(distanceProgress)
        return maximumUnplayedBlurRadius * CGFloat(0.12 + 0.88 * easedDistance)
    }

    private func rawPlayedProgress(for timing: LyricTimingTextAttribute) -> Double {
        guard playbackTime >= timing.startTime else { return 0 }
        guard playbackTime < timing.endTime else { return 1 }

        let duration = timing.endTime - timing.startTime
        guard duration > 0 else { return 1 }
        return min(max((playbackTime - timing.startTime) / duration, 0), 1)
    }

    private func glowStrength(
        for timing: LyricTimingTextAttribute,
        rawProgress: Double
    ) -> Double {
        if playbackTime <= timing.endTime {
            let attack = smootherStep(min(rawProgress / 0.24, 1))
            let breath = 0.82 + 0.18 * sin(.pi * rawProgress)
            return attack * breath
        }

        let tailProgress = (playbackTime - timing.endTime) / 0.55
        guard tailProgress < 1 else { return 0 }
        return (1 - smootherStep(max(tailProgress, 0))) * 0.82
    }

    private func drawGlow(
        _ run: Text.Layout.Run,
        playedBounds: CGRect,
        radius: CGFloat,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        var glowContext = context
        glowContext.opacity = opacity
        glowContext.blendMode = .plusLighter
        glowContext.addFilter(.blur(radius: radius))
        glowContext.drawLayer { layer in
            layer.clip(to: Path(playedBounds))
            layer.draw(run)
        }
    }

    private func smootherStep(_ value: Double) -> Double {
        let progress = min(max(value, 0), 1)
        return progress * progress * progress
            * (progress * (progress * 6 - 15) + 10)
    }

    private func playedBounds(
        in bounds: CGRect,
        progress: Double,
        layoutDirection: LayoutDirection
    ) -> CGRect {
        let playedWidth = bounds.width * progress
        let originX = layoutDirection == .rightToLeft
            ? bounds.maxX - playedWidth
            : bounds.minX
        return CGRect(
            x: originX,
            y: bounds.minY,
            width: playedWidth,
            height: bounds.height
        )
    }
}
