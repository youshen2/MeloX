// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

extension TextPVEffectPainter {
    func drawBalancingCircles(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("count", default: 5), 1)
        let blue = color("blueColor", in: config, default: "#0028B4")
        let white = color("whiteColor", in: config, default: "#ffffff")
        let glow = config.number("glowAlpha", default: 0.4)
        for index in 0..<count {
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi + frame.animatedTime * 0.08
            let radius = min(size.width, size.height) * (0.32 + random(index) * 0.16)
            let center = CGPoint(
                x: size.width / 2 + cos(angle) * radius,
                y: size.height / 2 + sin(angle) * radius
            )
            let circleRadius = 16 + random(index + 20) * 35
            let fill = index.isMultiple(of: 2) ? blue : white
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - circleRadius * 1.45,
                    y: center.y - circleRadius * 1.45,
                    width: circleRadius * 2.9,
                    height: circleRadius * 2.9
                )),
                with: .color(fill.opacity(glow * 0.18))
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - circleRadius,
                    y: center.y - circleRadius,
                    width: circleRadius * 2,
                    height: circleRadius * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.9), fill]),
                    center: CGPoint(x: center.x - circleRadius * 0.3, y: center.y - circleRadius * 0.3),
                    startRadius: 0,
                    endRadius: circleRadius
                )
            )
        }
    }

    func drawFlowingLines(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("count", default: 4), 1)
        let amplitude = config.number("amplitude", default: 80)
        let speed = config.number("speed", default: 0.08)
        let stroke = color("color", in: config, default: "$secondary")
        let alpha = config.number("alpha", default: 0.15)
        let width = config.number("strokeWidth", default: 0.5)
        for lineIndex in 0..<count {
            var path = Path()
            let baseY = size.height * CGFloat(lineIndex + 1) / CGFloat(count + 1)
            let phase = frame.animatedTime * speed * 2 * .pi + CGFloat(lineIndex)
            for step in 0...80 {
                let progress = CGFloat(step) / 80
                let x = progress * size.width
                let y = baseY
                    + sin(progress * 3 * .pi + phase) * amplitude
                    + cos(progress * 7 * .pi - phase * 0.6) * amplitude * 0.18
                step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(path, with: .color(stroke.opacity(alpha)), lineWidth: width)
        }
    }

    func drawRadialRectangles(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("count", default: 14), 1)
        let center = point(
            x: config.number("x", default: 0.47),
            y: config.number("y", default: 0.48),
            in: size
        )
        let base = color("baseColor", in: config, default: "#1133aa")
        let edge = color("edgeColor", in: config, default: "#cccc00")
        let rotation = frame.animatedTime * config.number("rotSpeed", default: 0.08)
        let growth = 1 + sin(frame.animatedTime * config.number("growSpeed", default: 0.03) * 2 * .pi) * 0.16
        for index in 0..<count {
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi + rotation
            let radialDistance = min(size.width, size.height) * (0.16 + CGFloat(index % 3) * 0.08)
            let rectCenter = CGPoint(
                x: center.x + cos(angle) * radialDistance,
                y: center.y + sin(angle) * radialDistance
            )
            let width = (45 + random(index) * 65) * growth
            let height = (130 + random(index + 40) * 210) * growth
            let path = rotatedRectangle(
                center: rectCenter,
                width: width,
                height: height,
                rotation: angle + .pi / 2
            )
            context.stroke(path, with: .color(edge.opacity(0.65)), lineWidth: 3)
            context.fill(path, with: .linearGradient(
                Gradient(colors: [base.opacity(0.25), base, .black.opacity(0.7)]),
                startPoint: CGPoint(x: rectCenter.x, y: rectCenter.y - height / 2),
                endPoint: CGPoint(x: rectCenter.x, y: rectCenter.y + height / 2)
            ))
        }
    }

    func drawScatteredShapes(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("count", default: 18), 1)
        let minSize = config.number("minSize", default: 4)
        let maxSize = config.number("maxSize", default: 30)
        let speed = config.number("speed", default: 0.1)
        let fill = color("color", in: config, default: "$primary")
        let alpha = config.number("alpha", default: 0.3)
        let forcedShape = config.string("shape", default: "")
        for index in 0..<count {
            let side = minSize + random(index * 5 + 2) * (maxSize - minSize)
            let drift = sin(frame.animatedTime * speed + CGFloat(index)) * 14 * frame.motionIntensity
            let center = CGPoint(
                x: random(index * 5) * size.width + drift,
                y: random(index * 5 + 1) * size.height - drift * 0.55
            )
            let shape = forcedShape.isEmpty
                ? ["circle", "square", "diamond"][index % 3]
                : forcedShape
            let path: Path
            if shape == "circle" {
                path = Path(ellipseIn: CGRect(
                    x: center.x - side / 2,
                    y: center.y - side / 2,
                    width: side,
                    height: side
                ))
            } else {
                path = rotatedRectangle(
                    center: center,
                    width: side,
                    height: shape == "diamond" ? side : side * 0.72,
                    rotation: shape == "diamond" ? .pi / 4 : random(index + 90) * .pi
                )
            }
            context.fill(path, with: .color(fill.opacity(alpha)))
        }
    }

    func drawWebLines(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("count", default: 18), 1)
        let focal = point(
            x: config.number("focalX", default: 0.5),
            y: config.number("focalY", default: 0.5),
            in: size
        )
        let spread = config.number("spread", default: 0.3)
        let stroke = color("color", in: config, default: "$primary")
        let glow = color("glowColor", in: config, default: "$accent")
        var path = Path()
        for index in 0..<count {
            let edge = index % 4
            let start: CGPoint
            switch edge {
            case 0: start = CGPoint(x: random(index) * size.width, y: 0)
            case 1: start = CGPoint(x: size.width, y: random(index) * size.height)
            case 2: start = CGPoint(x: random(index) * size.width, y: size.height)
            default: start = CGPoint(x: 0, y: random(index) * size.height)
            }
            let target = CGPoint(
                x: focal.x + signedRandom(index * 2 + 20) * size.width * spread,
                y: focal.y + signedRandom(index * 2 + 21) * size.height * spread
            )
            let bend = CGPoint(
                x: (start.x + target.x) / 2 + signedRandom(index * 2 + 50) * 40,
                y: (start.y + target.y) / 2 + signedRandom(index * 2 + 51) * 40
            )
            path.move(to: start)
            path.addQuadCurve(to: target, control: bend)
        }
        context.stroke(path, with: .color(glow.opacity(0.18)), lineWidth: 4)
        context.stroke(path, with: .color(stroke.opacity(0.75)), lineWidth: 1)
    }

    func drawPlanet(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = config.number("radius", default: 120)
        let core = config.number("coreRadius", default: 12)
        let fill = color("color", in: config, default: "#ffffff")
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [.white, fill.opacity(0.8), .black]),
                center: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.35),
                startRadius: core,
                endRadius: radius
            )
        )
        let ring = rotatedRectangle(
            center: center,
            width: radius * 3,
            height: radius * 0.34,
            rotation: -0.22
        )
        context.stroke(ring, with: .color(fill.opacity(0.65)), lineWidth: 2)
    }
}
