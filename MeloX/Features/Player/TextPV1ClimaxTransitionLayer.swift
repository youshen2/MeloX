import SwiftUI

struct TextPV1ClimaxTransitionLayer: View {
    let scene: TextPV1Scene
    let motion: TextPV1MotionFrame
    let intensity: CGFloat
    let seed: UInt64

    var body: some View {
        let entryRemainder = 1 - motion.entry
        let rotation3DDegrees = Double(entryRemainder * 42 * intensity)
        let rotationDegrees = Double(
            entryRemainder * -320 * intensity
                + motion.entryBounce * 70 * intensity
        )
        let impactScale = 0.72 + motion.entry * 0.28
            + motion.entryBounce * 0.18 * intensity
        let impactBlur = motion.transitionActivity * 2.4 * intensity
        let impactOpacity = min(motion.transitionActivity * 1.7, 1)

        Canvas(rendersAsynchronously: true) { context, size in
            let activity = motion.transitionActivity
            guard activity > 0.001 else { return }

            let foreground = scene.foregroundColor
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
            let minimumSide = min(size.width, size.height)
            let ringProgress = motion.exit > 0
                ? 1 - motion.exit
                : motion.entry
            let radius = minimumSide
                * (0.12 + ringProgress * 0.63)
                * (0.92 + intensity * 0.08)
                * (1 + motion.entryBounce * 0.16)

            drawImpactRings(
                in: &context,
                center: center,
                radius: radius,
                activity: activity,
                foreground: foreground,
                canvasWidth: size.width
            )
            drawRadialFragments(
                in: &context,
                center: center,
                radius: radius,
                activity: activity,
                foreground: foreground,
                canvasSize: size
            )
            drawCrossCut(
                in: &context,
                center: center,
                activity: activity,
                foreground: foreground,
                canvasSize: size
            )
        }
        .rotation3DEffect(
            .degrees(rotation3DDegrees),
            axis: (x: 0.12, y: 0.84, z: 0.18)
        )
        .rotationEffect(.degrees(rotationDegrees))
        .scaleEffect(impactScale)
        .blur(radius: impactBlur)
        .opacity(impactOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawImpactRings(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        activity: CGFloat,
        foreground: Color,
        canvasWidth: CGFloat
    ) {
        for index in 0..<3 {
            let offset = CGFloat(index) * canvasWidth * 0.012
            let ringRadius = radius + offset
            let rect = CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(
                    foreground.opacity(
                        (index == 0 ? 0.94 : 0.26) * activity
                    )
                ),
                lineWidth: index == 0
                    ? max(12, canvasWidth * 0.055 * intensity)
                    : max(3, canvasWidth * 0.014 * intensity)
            )
        }
    }

    private func drawRadialFragments(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        activity: CGFloat,
        foreground: Color,
        canvasSize: CGSize
    ) {
        for index in 0..<16 {
            let random = TextPV1StableSeed.unit(index + 300, seed: seed)
            let angle = CGFloat(index) / 16 * 2 * .pi
                + (random - 0.5) * 0.28
                + motion.phase * 0.014
                + motion.entryBounce * 0.72
            let distance = radius
                * (0.42 + random * 0.8)
                * (0.7 + motion.entry * 0.55)
            let width = canvasSize.width * (0.025 + random * 0.07)
            let height = max(4, canvasSize.height * (0.012 + random * 0.035))
            let fragmentCenter = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )
            let path = rotatedRectangle(
                center: fragmentCenter,
                size: CGSize(width: width, height: height),
                angle: angle
            )

            if index.isMultiple(of: 3) {
                context.fill(
                    path,
                    with: .color(foreground.opacity(0.62 * activity))
                )
            } else {
                context.stroke(
                    path,
                    with: .color(foreground.opacity(0.54 * activity)),
                    lineWidth: max(1, canvasSize.width * 0.003)
                )
            }
        }
    }

    private func drawCrossCut(
        in context: inout GraphicsContext,
        center: CGPoint,
        activity: CGFloat,
        foreground: Color,
        canvasSize: CGSize
    ) {
        let reach = canvasSize.width * (0.18 + motion.entry * 0.48)
        var horizontal = Path()
        horizontal.move(to: CGPoint(x: center.x - reach, y: center.y))
        horizontal.addLine(to: CGPoint(x: center.x + reach, y: center.y))
        context.stroke(
            horizontal,
            with: .color(foreground.opacity(0.7 * activity)),
            lineWidth: max(2, canvasSize.height * 0.018 * intensity)
        )

        let verticalReach = canvasSize.height * (0.12 + motion.entry * 0.32)
        var vertical = Path()
        vertical.move(to: CGPoint(x: center.x, y: center.y - verticalReach))
        vertical.addLine(to: CGPoint(x: center.x, y: center.y + verticalReach))
        context.stroke(
            vertical,
            with: .color(foreground.opacity(0.38 * activity)),
            lineWidth: max(1, canvasSize.width * 0.006 * intensity)
        )
    }

    private func rotatedRectangle(
        center: CGPoint,
        size: CGSize,
        angle: CGFloat
    ) -> Path {
        let rect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )
        let transform = CGAffineTransform(
            translationX: center.x,
            y: center.y
        ).rotated(by: angle)
        return Path(rect).applying(transform)
    }
}
