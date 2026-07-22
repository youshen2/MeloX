// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

extension TextPVEffectPainter {
    func drawBurstLines(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("rayCount", default: 16), 1)
        let center = point(
            x: config.number("x", default: 0.5),
            y: config.number("y", default: 0.5),
            in: size
        )
        let side = max(size.width, size.height)
        let inner = config.number("innerRadius", default: 0.05) * side
        let outer = config.number("outerRadius", default: 0.75) * side
        let rotation = frame.animatedTime * config.number("rotSpeed", default: 0.05)
        let stroke = color("color", in: config, default: "$primary")
        let alpha = config.number("alpha", default: 0.3)
        let width = config.number("lineWidth", default: 1)
        var path = Path()
        for index in 0..<count {
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi + rotation
            path.move(to: CGPoint(
                x: center.x + cos(angle) * inner,
                y: center.y + sin(angle) * inner
            ))
            path.addLine(to: CGPoint(
                x: center.x + cos(angle) * outer,
                y: center.y + sin(angle) * outer
            ))
        }
        context.stroke(path, with: .color(stroke.opacity(alpha)), lineWidth: width)
    }

    func drawCenteredSquares(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let pulse = 1 + sin(frame.animatedTime * 1.8) * 0.03 * frame.motionIntensity
        let outer = config.number("outerSize", default: 320) * pulse
        let middle = config.number("midSize", default: 240) * pulse
        let inner = config.number("innerSize", default: 170) * pulse
        let outerPath = rotatedRectangle(
            center: center,
            width: outer,
            height: outer,
            rotation: frame.animatedTime * 0.04
        )
        let middlePath = rotatedRectangle(
            center: center,
            width: middle,
            height: middle,
            rotation: -frame.animatedTime * 0.06
        )
        let innerPath = rotatedRectangle(
            center: center,
            width: inner,
            height: inner,
            rotation: frame.animatedTime * 0.09
        )
        context.stroke(
            outerPath,
            with: .color(color("borderColor", in: config, default: "$primary")),
            lineWidth: 3
        )
        context.fill(
            middlePath,
            with: .color(color("midColor", in: config, default: "$primary"))
        )
        context.fill(
            innerPath,
            with: .color(color("innerColor", in: config, default: "$secondary"))
        )
    }

    func drawCompositionGuides(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let guides = config.array("guides").compactMap(\.stringValue)
        let stroke = color("color", in: config, default: "$line")
        let alpha = config.number("alpha", default: 0.35)
        let width = config.number("lineWidth", default: 1)
        var path = Path()

        if guides.contains("thirds") {
            for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
                path.move(to: CGPoint(x: size.width * fraction, y: 0))
                path.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
                path.move(to: CGPoint(x: 0, y: size.height * fraction))
                path.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
            }
        }

        if guides.contains("goldenSpiral") {
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) * 0.48
            let rotation = frame.animatedTime * config.number("rotSpeed", default: 0)
            let steps = 140
            for index in 0...steps {
                let progress = CGFloat(index) / CGFloat(steps)
                let angle = progress * 4.5 * .pi + rotation
                let radius = 4 * exp(progress * log(maxRadius / 4))
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
        }

        context.stroke(path, with: .color(stroke.opacity(alpha)), lineWidth: width)
    }

    func drawConcentricCircles(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("count", default: 5), 1)
        let maxRadius = config.number("maxRadius", default: 500)
        let center = point(
            x: config.number("x", default: 0.5),
            y: config.number("y", default: 0.5),
            in: size
        )
        let stroke = color("color", in: config, default: "$secondary")
        let alpha = config.number("alpha", default: 0.4)
        let width = config.number("strokeWidth", default: 1)
        var path = Path()
        for index in 1...count {
            let radius = maxRadius * CGFloat(index) / CGFloat(count)
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
        context.stroke(path, with: .color(stroke.opacity(alpha)), lineWidth: width)
    }

    func drawDiagonalSplit(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = hypot(size.width, size.height)
        let base = config.number("baseHalfAngle", default: 0.6)
        let variation = sin(frame.animatedTime * 0.7) * config.number("angleVariation", default: 0.3)
        let rotation = config.number("initRotation", default: -.pi / 2)
            + frame.animatedTime * config.number("rotSpeed", default: 0.25)
        let fill = color("color", in: config, default: "$accent")
        let alpha = config.number("alpha", default: 1)
        var wedge = Path()
        wedge.move(to: center)
        wedge.addLine(to: CGPoint(
            x: center.x + cos(rotation - base - variation) * radius,
            y: center.y + sin(rotation - base - variation) * radius
        ))
        wedge.addLine(to: CGPoint(
            x: center.x + cos(rotation + base + variation) * radius,
            y: center.y + sin(rotation + base + variation) * radius
        ))
        wedge.closeSubpath()
        context.fill(wedge, with: .color(fill.opacity(alpha)))

        let centerSize = config.number("centerSize", default: 12)
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - centerSize / 2,
                y: center.y - centerSize / 2,
                width: centerSize,
                height: centerSize
            )),
            with: .color(color("centerColor", in: config, default: "$primary"))
        )
    }

    func drawDiagonalStructure(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let step = max(config.number("step", default: 100), 20)
        let stroke = color("color", in: config, default: "#f0f0f0")
        let alpha = config.number("alpha", default: 0.3)
        var path = Path()
        var coordinate: CGFloat = 0
        while coordinate <= size.width + size.height {
            path.move(to: CGPoint(x: coordinate, y: 0))
            path.addLine(to: CGPoint(x: 0, y: coordinate))
            path.move(to: CGPoint(x: size.width - coordinate, y: size.height))
            path.addLine(to: CGPoint(x: size.width, y: size.height - coordinate))
            coordinate += step
        }
        context.stroke(path, with: .color(stroke.opacity(alpha)), lineWidth: 1)
    }

    func drawPerspectiveGrid(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let stroke = color("color", in: config, default: "$line")
        let alpha = config.number("alpha", default: 0.5)
        let width = config.number("lineWidth", default: 1.5)
        let horizon = size.height * 0.48
        let offset = (frame.animatedTime * config.number("scrollSpeed", default: 0.25) * 40)
            .truncatingRemainder(dividingBy: 40)
        var path = Path()
        for index in -9...9 {
            path.move(to: CGPoint(x: size.width / 2, y: horizon))
            path.addLine(to: CGPoint(
                x: size.width / 2 + CGFloat(index) * size.width / 7,
                y: size.height
            ))
        }
        for index in 0..<12 {
            let t = (CGFloat(index) * 40 + offset) / max(size.height - horizon, 1)
            let curved = t * t
            let y = horizon + curved * (size.height - horizon)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(path, with: .color(stroke.opacity(alpha)), lineWidth: width)
    }

    func drawScreenBorder(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let margin = config.number("margin", default: 18)
        let gap = config.number("gap", default: 5)
        let starSize = config.number("starSize", default: 4)
        let width = config.number("lineWidth", default: 1.5)
        let stroke = color("color", in: config, default: "$primary")
        let alpha = config.number("alpha", default: 0.5)
        let rect = CGRect(x: margin, y: margin, width: size.width - margin * 2, height: size.height - margin * 2)
        context.stroke(Path(rect), with: .color(stroke.opacity(alpha)), lineWidth: width)
        context.stroke(
            Path(rect.insetBy(dx: gap, dy: gap)),
            with: .color(stroke.opacity(alpha * 0.55)),
            lineWidth: max(width * 0.55, 0.5)
        )
        let horizontalCount = config.integer("edgeStarCount", default: 4)
        let verticalCount = config.integer("edgeStarCountV", default: 2)
        for index in 1...max(horizontalCount, 1) {
            let x = margin + rect.width * CGFloat(index) / CGFloat(horizontalCount + 1)
            context.fill(starPath(center: CGPoint(x: x, y: margin), radius: starSize), with: .color(stroke.opacity(alpha)))
            context.fill(starPath(center: CGPoint(x: x, y: size.height - margin), radius: starSize), with: .color(stroke.opacity(alpha)))
        }
        for index in 1...max(verticalCount, 1) {
            let y = margin + rect.height * CGFloat(index) / CGFloat(verticalCount + 1)
            context.fill(starPath(center: CGPoint(x: margin, y: y), radius: starSize), with: .color(stroke.opacity(alpha)))
            context.fill(starPath(center: CGPoint(x: size.width - margin, y: y), radius: starSize), with: .color(stroke.opacity(alpha)))
        }
    }
}
