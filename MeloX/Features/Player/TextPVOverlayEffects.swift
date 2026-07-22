// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

extension TextPVEffectPainter {
    func drawDotScreen(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let spacing = max(config.number("spacing", default: 8), 4)
        let radius = config.number(
            "dotRadius",
            default: config.number("dotSize", default: 1.5)
        )
        let fill = color("color", in: config, default: "#ffffff")
        let alpha = config.number("alpha", default: 0.12)
        let path = cachedPath(
            "dotScreen",
            size: size,
            discriminator: "\(spacing):\(radius)"
        ) {
            var path = Path()
            var y: CGFloat = 0
            while y <= size.height {
                var x: CGFloat = 0
                while x <= size.width {
                    path.addEllipse(in: CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                    x += spacing
                }
                y += spacing
            }
            return path
        }
        context.fill(path, with: .color(fill.opacity(alpha)))
    }

    func drawScanlines(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let spacing = max(config.number("spacing", default: 4), 2)
        let stroke = color("color", in: config, default: "#000000")
        let alpha = config.number("alpha", default: 0.12)
        let path = cachedPath(
            "scanlines",
            size: size,
            discriminator: "\(spacing)"
        ) {
            var path = Path()
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            return path
        }
        context.stroke(path, with: .color(stroke.opacity(alpha)), lineWidth: 1)
    }

    func drawFilmGrain(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let alpha = config.number("alpha", default: 0.08)
        let interval = max(config.integer("updateInterval", default: 2), 1)
        let frameBucket = Int(frame.time * 60) / interval
        let variantCount = max(config.integer("frameVariants", default: 4), 1)
        let frameVariant = frameBucket % variantCount
        let dynamicSeed = seed &+ UInt64(truncatingIfNeeded: frameVariant)
        let count = min(max(Int(size.width * size.height / 260), 120), 1_800)
        let paths = cachedPathPair(
            "filmGrain",
            size: size,
            discriminator: "\(frameVariant):\(count)",
            includesSeed: true
        ) {
            var light = Path()
            var dark = Path()
            for index in 0..<count {
                let x = TextPVSeed.unit(dynamicSeed, index * 3) * size.width
                let y = TextPVSeed.unit(dynamicSeed, index * 3 + 1) * size.height
                let side = 0.5 + TextPVSeed.unit(dynamicSeed, index * 3 + 2) * 1.8
                let rect = CGRect(x: x, y: y, width: side, height: side)
                index.isMultiple(of: 2) ? light.addRect(rect) : dark.addRect(rect)
            }
            return (light, dark)
        }
        context.fill(paths.0, with: .color(.white.opacity(alpha)))
        context.fill(paths.1, with: .color(.black.opacity(alpha)))
    }

    func drawChromaticAberration(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let offset = config.number(
            "offset",
            default: config.number("amount", default: 3)
        ) * frame.motionIntensity
        let speed = config.number("flickerSpeed", default: 4) * frame.animationSpeed
        let flicker = sin(frame.time * speed * 2 * .pi)
        let strength = ((offset * (0.6 + flicker * 0.4)) / 255).textPVClamped(to: 0...0.12)
        let bounds = Path(CGRect(origin: .zero, size: size))
        context.fill(bounds, with: .color(.red.opacity(strength)))
        context.fill(bounds, with: .color(.blue.opacity(strength * 0.72)))
    }

    func drawGlitchBars(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let maxBars = config.integer("maxBars", default: 8)
        let minHeight = config.number("minHeight", default: 2)
        let maxHeight = config.number("maxHeight", default: 12)
        let fill = color("color", in: config, default: "$primary")
        let alpha = config.number("alpha", default: 0.9)
        let tick = Int(frame.time * max(frame.animationSpeed, 0.1) / 0.15)
        for index in 0..<maxBars {
            let live = TextPVSeed.unit(seed &+ UInt64(tick), index * 4) > 0.58
            guard live else { continue }
            let height = minHeight + random(index * 4 + 1, salt: UInt64(tick)) * (maxHeight - minHeight)
            let width = size.width * (0.3 + random(index * 4 + 2, salt: UInt64(tick)) * 0.7)
            let rect = CGRect(
                x: random(index * 4 + 3, salt: UInt64(tick)) * max(size.width - width, 0),
                y: random(index * 4 + 4, salt: UInt64(tick)) * size.height,
                width: width,
                height: height
            )
            context.fill(Path(rect), with: .color(fill.opacity(alpha * (0.45 + random(index) * 0.55))))
        }
    }

    func drawVignette(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let fill = color("color", in: config, default: "#000000")
        let alpha = config.number(
            "alpha",
            default: config.number("intensity", default: 0.5)
        )
        let radius = config.number("radius", default: 0.72)
        let endRadius = max(size.width, size.height) * radius
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.42),
                    .init(color: fill.opacity(alpha), location: 1),
                ]),
                center: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: 0,
                endRadius: endRadius
            )
        )
    }

    func drawColorMask(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let fill = color("color", in: config, default: "#000000")
        let alpha = config.number("alpha", default: 0.15)
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(fill.opacity(alpha))
        )
    }

    func drawLightSpot(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let fill = color("color", in: config, default: "#ffffff")
        let alpha = config.number("alpha", default: 0.5)
        let center = point(
            x: config.number("x", default: 0.5),
            y: config.number("y", default: 0.08),
            in: size
        )
        let radius = max(size.width, size.height) * config.number("radius", default: 0.4)
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [fill.opacity(alpha), .clear]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    func drawHUDCorners(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let margin = config.number("margin", default: 20)
        let arm = config.number("armLength", default: 40)
        let width = config.number("lineWidth", default: 2)
        let stroke = color("color", in: config, default: "$primary")
        let alpha = config.number("alpha", default: 0.9)
        var path = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: margin, y: margin), 1, 1),
            (CGPoint(x: size.width - margin, y: margin), -1, 1),
            (CGPoint(x: margin, y: size.height - margin), 1, -1),
            (CGPoint(x: size.width - margin, y: size.height - margin), -1, -1),
        ]
        for (corner, xDirection, yDirection) in corners {
            path.move(to: CGPoint(x: corner.x + arm * xDirection, y: corner.y))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + arm * yDirection))
        }
        context.stroke(path, with: .color(stroke.opacity(alpha)), lineWidth: width)
    }

    func drawMotionBrackets(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        guard !frame.motionTargets.isEmpty else { return }
        let style = config.string("style", default: "medium")
        let stroke = color("color", in: config, default: "$primary")
        let alpha = config.number("alpha", default: 0.7)
        let width = config.number("lineWidth", default: 1)
        let targets = frame.motionTargets
        var brackets = Path()
        for (index, target) in targets.enumerated() {
            let length = min(target.width, target.height) * (style == "high" ? 0.28 : 0.2)
            addBracketCorners(rect: target, length: length, to: &brackets)
            if style == "high" && index == 1 {
                let crossCenter = CGPoint(x: target.midX, y: target.midY)
                brackets.move(to: CGPoint(x: crossCenter.x - 8, y: crossCenter.y))
                brackets.addLine(to: CGPoint(x: crossCenter.x + 8, y: crossCenter.y))
                brackets.move(to: CGPoint(x: crossCenter.x, y: crossCenter.y - 8))
                brackets.addLine(to: CGPoint(x: crossCenter.x, y: crossCenter.y + 8))
            }
        }
        context.stroke(brackets, with: .color(stroke.opacity(alpha)), lineWidth: width)

        if config.bool("showConnections", default: false) {
            var connections = Path()
            for pair in zip(targets, targets.dropFirst()) {
                connections.move(to: CGPoint(x: pair.0.midX, y: pair.0.midY))
                connections.addLine(to: CGPoint(x: pair.1.midX, y: pair.1.midY))
            }
            context.stroke(
                connections,
                with: .color(color("connColor", in: config, default: "#888888").opacity(alpha * 0.65)),
                lineWidth: width
            )
        }

        if style == "high" {
            drawText(
                "NO MATCH // 77%",
                in: &context,
                at: CGPoint(x: targets[1].midX, y: targets[1].minY - 12),
                color: stroke,
                size: 11,
                family: "mono",
                opacity: alpha
            )
        }
    }

    private func addBracketCorners(rect: CGRect, length: CGFloat, to path: inout Path) {
        path.move(to: CGPoint(x: rect.minX + length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
    }
}
