import SwiftUI

struct TextPV1GeometryLayer: View {
    let scene: TextPV1Scene
    let motion: TextPV1MotionFrame
    let intensity: CGFloat
    let seed: UInt64

    var body: some View {
        Canvas(opaque: true, colorMode: .linear, rendersAsynchronously: true) { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(scene.backgroundColor)
            )

            switch scene {
            case .impactDark:
                drawImpact(in: &context, size: size)
            case .editorialWhite:
                drawEditorial(in: &context, size: size)
            case .aperture:
                drawAperture(in: &context, size: size)
            case .wireframe:
                drawWireframe(in: &context, size: size)
            case .splitScreen:
                drawSplitScreen(in: &context, size: size)
            case .verticalColumns:
                drawVerticalColumns(in: &context, size: size)
            case .targetLock:
                drawTargetLock(in: &context, size: size)
            case .staggeredBands:
                drawStaggeredBands(in: &context, size: size)
            }

            drawOpeningFlash(in: &context, size: size)
        }
        .rotationEffect(
            .degrees(Double(motion.entryBounce * 4 * intensity))
        )
        .scaleEffect(1 + motion.entryBounce * 0.085 * intensity)
        .accessibilityHidden(true)
    }

    private func drawImpact(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.47)
        let reveal = max(motion.entry, 0.04)
        let foreground = Color.white.opacity(0.76 * (1 - motion.exit))

        for index in 0..<4 {
            let spread = CGFloat(index + 1) * 0.11
            let side = min(size.width, size.height)
                * (0.1 + reveal * spread + motion.entryKick * 0.22)
            let angle = TextPV1StableSeed.unit(index, seed: seed) * .pi
                + motion.phase * 0.012 * CGFloat(index.isMultiple(of: 2) ? 1 : -1)
            context.stroke(
                rotatedRectangle(
                    center: center,
                    size: CGSize(width: side * 1.5, height: side),
                    angle: angle
                ),
                with: .color(foreground.opacity(0.48)),
                lineWidth: max(1, size.width * 0.0025)
            )
        }

        for index in 0..<18 {
            let randomX = TextPV1StableSeed.unit(index * 3, seed: seed)
            let randomY = TextPV1StableSeed.unit(index * 3 + 1, seed: seed)
            let randomSize = TextPV1StableSeed.unit(index * 3 + 2, seed: seed)
            let drift = sin(motion.phase * 0.18 + CGFloat(index))
                * 10 * intensity
            let side = 3 + randomSize * 11
            let rect = CGRect(
                x: randomX * size.width + drift,
                y: randomY * size.height - drift * 0.6,
                width: side,
                height: side
            )
            context.stroke(
                Path(rect),
                with: .color(foreground.opacity(0.35 + randomSize * 0.35)),
                lineWidth: max(0.8, side * 0.12)
            )
        }

        var slash = Path()
        slash.move(to: CGPoint(x: -size.width * 0.08, y: size.height * 0.78))
        slash.addLine(
            to: CGPoint(
                x: size.width * (0.72 + motion.progress * 0.36),
                y: size.height * 0.19
            )
        )
        context.stroke(
            slash,
            with: .color(foreground.opacity(0.18)),
            lineWidth: max(2, size.width * 0.016)
        )
    }

    private func drawEditorial(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let foreground = Color.black.opacity(0.88 * (1 - motion.exit))
        let center = CGPoint(
            x: size.width * (0.5 + motion.pulse * 0.012),
            y: size.height * 0.48
        )
        let circleSide = min(size.width, size.height)
            * (0.28 + motion.entry * 0.92)
        context.stroke(
            Path(
                ellipseIn: CGRect(
                    x: center.x - circleSide / 2,
                    y: center.y - circleSide / 2,
                    width: circleSide,
                    height: circleSide
                )
            ),
            with: .color(foreground),
            lineWidth: max(3, size.width * 0.009)
        )

        for index in 0..<7 {
            let position = CGFloat(index) / 6
            let y = size.height * (0.16 + position * 0.7)
                + sin(motion.phase * 0.08 + CGFloat(index)) * 4 * intensity
            var horizontal = Path()
            horizontal.move(
                to: CGPoint(
                    x: size.width * (index.isMultiple(of: 2) ? -0.06 : 0.18),
                    y: y
                )
            )
            horizontal.addLine(
                to: CGPoint(x: size.width * (0.72 + motion.entry * 0.34), y: y)
            )
            context.stroke(
                horizontal,
                with: .color(foreground.opacity(index.isMultiple(of: 2) ? 0.9 : 0.42)),
                lineWidth: index.isMultiple(of: 3) ? max(3, size.height * 0.016) : 1.5
            )
        }

        for index in 0..<10 {
            let randomX = TextPV1StableSeed.unit(index * 2, seed: seed)
            let randomY = TextPV1StableSeed.unit(index * 2 + 1, seed: seed)
            let side = min(size.width, size.height) * (index.isMultiple(of: 4) ? 0.12 : 0.035)
            let rect = CGRect(
                x: randomX * (size.width - side),
                y: randomY * (size.height - side),
                width: side,
                height: side
            )
            if index.isMultiple(of: 3) {
                context.fill(Path(rect), with: .color(foreground.opacity(0.72)))
            } else {
                context.stroke(
                    Path(rect),
                    with: .color(foreground.opacity(0.58)),
                    lineWidth: 1.5
                )
            }
        }
    }

    private func drawAperture(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let panelWidth = size.width * (0.22 + (1 - motion.entry) * 0.22)
        let panelColor = Color(white: 0.12).opacity(1 - motion.exit * 0.8)
        context.fill(
            Path(CGRect(x: 0, y: 0, width: panelWidth, height: size.height)),
            with: .color(panelColor)
        )
        context.fill(
            Path(
                CGRect(
                    x: size.width - panelWidth,
                    y: 0,
                    width: panelWidth,
                    height: size.height
                )
            ),
            with: .color(Color(white: 0.34).opacity(1 - motion.exit * 0.8))
        )

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for index in 0..<3 {
            let radius = min(size.width, size.height)
                * (0.13 + CGFloat(index) * 0.1 + motion.entryKick * 0.12)
            let start = Angle.radians(
                Double(motion.phase * 0.03 + CGFloat(index) * 0.8)
            )
            let end = Angle.radians(start.radians + .pi * (1.15 + Double(index) * 0.12))
            var arc = Path()
            arc.addArc(
                center: center,
                radius: radius,
                startAngle: start,
                endAngle: end,
                clockwise: false
            )
            context.stroke(
                arc,
                with: .color(Color.black.opacity(0.25 + CGFloat(index) * 0.2)),
                lineWidth: max(1, size.width * (0.002 + CGFloat(index) * 0.002))
            )
        }

        for index in 0..<12 {
            let x = size.width * (0.29 + TextPV1StableSeed.unit(index, seed: seed) * 0.42)
            let y = size.height * (0.08 + CGFloat(index) / 13 * 0.84)
            let length = size.width * (0.012 + TextPV1StableSeed.unit(index + 30, seed: seed) * 0.03)
            var tick = Path()
            tick.move(to: CGPoint(x: x - length, y: y))
            tick.addLine(to: CGPoint(x: x + length, y: y))
            context.stroke(
                tick,
                with: .color(Color.black.opacity(0.18)),
                lineWidth: 1
            )
        }
    }

    private func drawWireframe(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let foreground = Color.black.opacity(0.88 * (1 - motion.exit))
        let slope = size.height * (0.18 + motion.pulse * 0.02)

        for index in 0..<3 {
            let y = size.height * (0.22 + CGFloat(index) * 0.28)
            var line = Path()
            line.move(to: CGPoint(x: -size.width * 0.1, y: y - slope))
            line.addLine(to: CGPoint(x: size.width * 1.1, y: y + slope))
            context.stroke(
                line,
                with: .color(foreground.opacity(index == 1 ? 1 : 0.68)),
                lineWidth: index == 1 ? max(5, size.width * 0.016) : max(2, size.width * 0.007)
            )
        }

        let verticalX = size.width * (0.68 + motion.pulse * 0.015)
        var vertical = Path()
        vertical.move(to: CGPoint(x: verticalX, y: -size.height * 0.1))
        vertical.addLine(to: CGPoint(x: verticalX - size.width * 0.16, y: size.height * 1.1))
        context.stroke(
            vertical,
            with: .color(foreground),
            lineWidth: max(3, size.width * 0.009)
        )

        for index in 0..<8 {
            let randomX = TextPV1StableSeed.unit(index * 2, seed: seed)
            let randomY = TextPV1StableSeed.unit(index * 2 + 1, seed: seed)
            let side = min(size.width, size.height)
                * (index.isMultiple(of: 3) ? 0.16 : 0.055)
            let center = CGPoint(x: randomX * size.width, y: randomY * size.height)
            let angle = (TextPV1StableSeed.unit(index + 40, seed: seed) - 0.5) * 0.5
                + motion.phase * 0.004
            let path = rotatedRectangle(
                center: center,
                size: CGSize(width: side, height: side),
                angle: angle
            )
            if index.isMultiple(of: 4) {
                context.fill(path, with: .color(foreground.opacity(0.82)))
            } else {
                context.stroke(
                    path,
                    with: .color(foreground.opacity(0.7)),
                    lineWidth: max(1, size.width * 0.004)
                )
            }
        }
    }

    private func drawOpeningFlash(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let flashOpacity = max(0, 1 - motion.entry * 4.5)
        guard flashOpacity > 0 else { return }
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(
                (scene.isDark ? Color.white : Color.black)
                    .opacity(flashOpacity)
            )
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
