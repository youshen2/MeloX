// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

extension TextPVEffectPainter {
    func drawEdgeClouds(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let cloudCount = max(config.integer("cloudCount", default: 5), 1)
        let baseRadius = config.number("baseRadius", default: 100)
        let minCircles = config.integer("minCircles", default: 6)
        let maxCircles = config.integer("maxCircles", default: 10)
        let fill = color("color", in: config, default: "#ffffff")
        let shadow = color("shadowColor", in: config, default: "#fbbdbe")
        let alpha = config.number("alpha", default: 1)
        let shadowAlpha = config.number("shadowAlpha", default: 0.25)
        let shadowX = config.number("shadowOffsetX", default: 4)
        let shadowY = config.number("shadowOffsetY", default: 4)

        for cloudIndex in 0..<cloudCount {
            let edge = cloudIndex % 4
            let center: CGPoint
            switch edge {
            case 0: center = CGPoint(x: random(cloudIndex) * size.width, y: -baseRadius * 0.25)
            case 1: center = CGPoint(x: size.width + baseRadius * 0.2, y: random(cloudIndex) * size.height)
            case 2: center = CGPoint(x: random(cloudIndex) * size.width, y: size.height + baseRadius * 0.2)
            default: center = CGPoint(x: -baseRadius * 0.2, y: random(cloudIndex) * size.height)
            }
            let circles = minCircles + Int(random(cloudIndex + 50) * CGFloat(max(maxCircles - minCircles, 1)))
            var cloud = Path()
            var cloudShadow = Path()
            for circleIndex in 0..<circles {
                let angle = CGFloat(circleIndex) / CGFloat(circles) * 2 * .pi
                let radius = baseRadius * (0.35 + random(cloudIndex * 30 + circleIndex) * 0.32)
                let distance = baseRadius * (0.28 + random(cloudIndex * 30 + circleIndex + 90) * 0.35)
                let circleCenter = CGPoint(
                    x: center.x + cos(angle) * distance,
                    y: center.y + sin(angle) * distance
                )
                let rect = CGRect(
                    x: circleCenter.x - radius,
                    y: circleCenter.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                cloud.addEllipse(in: rect)
                cloudShadow.addEllipse(in: rect.offsetBy(dx: shadowX, dy: shadowY))
            }
            context.fill(cloudShadow, with: .color(shadow.opacity(shadowAlpha)))
            context.fill(cloud, with: .color(fill.opacity(alpha)))
        }
    }

    func drawPulsingCircle(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let center = point(
            x: config.number("x", default: 0.5),
            y: config.number("y", default: 0.5),
            in: size
        )
        let baseRadius = config.number("radius", default: 250)
        let speed = config.number("animSpeed", default: 0.2)
        let wave = sin(frame.animatedTime * speed * 2 * .pi)
        let radius = baseRadius * (1 + wave * config.number("radiusPulseAmount", default: 0.08))
        let strokePulse = 1 + wave * config.number("strokePulseAmount", default: 0.5)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(color("outerStrokeColor", in: config, default: "#ecbfc0")
                .opacity(config.number("outerStrokeAlpha", default: 0.6))),
            lineWidth: config.number("outerStrokeWidth", default: 3)
        )
        context.stroke(
            Path(ellipseIn: rect.insetBy(dx: 12, dy: 12)),
            with: .color(color("strokeColor", in: config, default: "#ffffff")
                .opacity(config.number("strokeAlpha", default: 0.8))),
            lineWidth: config.number("strokeWidth", default: 8) * strokePulse
        )
    }

    func drawScalloppedBorder(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let radius = config.number("circleRadius", default: 80)
        let speed = config.number("animSpeed", default: 0.2)
        let move = sin(frame.animatedTime * speed * 2 * .pi)
            * config.number("moveAmount", default: 15)
        let fill = color("color", in: config, default: "#ffffff")
        let shadow = color("shadowColor", in: config, default: "#ecbfc0")
        let alpha = config.number("alpha", default: 1)
        let shadowAlpha = config.number("shadowAlpha", default: 0.6)
        let shadowX = config.number("shadowOffsetX", default: 0)
        let shadowY = config.number("shadowOffsetY", default: 8)
        var border = Path()
        var shadowPath = Path()

        var x = -radius + move
        while x < size.width + radius {
            addScallop(at: CGPoint(x: x, y: 0), radius: radius, to: &border)
            addScallop(at: CGPoint(x: x + shadowX, y: shadowY), radius: radius, to: &shadowPath)
            addScallop(at: CGPoint(x: x, y: size.height), radius: radius, to: &border)
            addScallop(at: CGPoint(x: x + shadowX, y: size.height + shadowY), radius: radius, to: &shadowPath)
            x += radius * 1.45
        }
        var y = -radius - move
        while y < size.height + radius {
            addScallop(at: CGPoint(x: 0, y: y), radius: radius, to: &border)
            addScallop(at: CGPoint(x: shadowX, y: y + shadowY), radius: radius, to: &shadowPath)
            addScallop(at: CGPoint(x: size.width, y: y), radius: radius, to: &border)
            addScallop(at: CGPoint(x: size.width + shadowX, y: y + shadowY), radius: radius, to: &shadowPath)
            y += radius * 1.45
        }
        context.fill(shadowPath, with: .color(shadow.opacity(shadowAlpha)))
        context.fill(border, with: .color(fill.opacity(alpha)))
    }

    private func addScallop(at center: CGPoint, radius: CGFloat, to path: inout Path) {
        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    func drawDesktopIcon(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let x = config.number("x", default: 30)
        let y = config.number("y", default: 30)
        let side = config.number("size", default: 64)
        let iconType = config.string("iconType", default: "paint")
        let label = config.string("label", default: "Icon")
        let labelColor = color("labelColor", in: config, default: "#5a3a5a")
        let rect = CGRect(x: x, y: y, width: side, height: side)
        context.fill(Path(rect), with: .color(.white.opacity(0.92)))
        context.stroke(Path(rect), with: .color(palette.resolve("$primary")), lineWidth: 3)
        drawText(
            iconType == "notes" ? "▤" : "▧",
            in: &context,
            at: CGPoint(x: rect.midX, y: rect.midY),
            color: palette.resolve(iconType == "notes" ? "$accent" : "$primary"),
            size: side * 0.54,
            family: "mono"
        )
        drawText(
            label,
            in: &context,
            at: CGPoint(x: rect.midX, y: rect.maxY + 13),
            color: labelColor,
            size: 11,
            family: "mono"
        )
    }

    func drawPixelWindow(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let width = config.number("width", default: 280)
        let height = config.number("height", default: 180)
        let center = CGPoint(
            x: coordinate(config.number("x", default: 0.5), extent: size.width),
            y: coordinate(config.number("y", default: 0.5), extent: size.height)
        )
        let rect = CGRect(
            x: center.x - width * config.number("anchorX", default: 0.5),
            y: center.y - height * config.number("anchorY", default: 0.5),
            width: width,
            height: height
        )
        let titleHeight = config.number("titleBarHeight", default: 28)
        let alpha = config.number("alpha", default: 0.95)
        let background = color("bgColor", in: config, default: "#ffffff")
        let border = color("borderColor", in: config, default: "#ffb3d9")
        let titleBackground = color("titleBgColor", in: config, default: "#ffb3d9")
        let titleColor = color("titleColor", in: config, default: "#ffffff")
        context.fill(Path(rect), with: .color(background.opacity(alpha)))
        context.stroke(
            Path(rect),
            with: .color(border.opacity(alpha)),
            lineWidth: config.number("borderWidth", default: 4)
        )
        let titleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: titleHeight)
        context.fill(Path(titleRect), with: .color(titleBackground.opacity(alpha)))
        drawText(
            config.string("title", default: "Window"),
            in: &context,
            at: CGPoint(x: titleRect.minX + 9, y: titleRect.midY),
            color: titleColor,
            size: 12,
            family: "mono",
            anchor: .leading
        )
        drawText(
            "□ ×",
            in: &context,
            at: CGPoint(x: titleRect.maxX - 8, y: titleRect.midY),
            color: titleColor,
            size: 12,
            family: "mono",
            anchor: .trailing
        )
        if let content = config["content"]?.stringValue {
            drawText(
                content,
                in: &context,
                at: CGPoint(x: rect.minX + 14, y: titleRect.maxY + 14),
                color: color("contentColor", in: config, default: "#5a3a5a"),
                size: 13,
                family: "mono",
                anchor: .topLeading
            )
        } else if let icon = config["icon"]?.stringValue {
            drawText(
                icon == "heart" ? "♥" : "▧",
                in: &context,
                at: CGPoint(x: rect.midX, y: titleRect.maxY + (rect.height - titleHeight) / 2),
                color: color("iconColor", in: config, default: "#ffb3d9"),
                size: config.number("iconSize", default: 60),
                family: "mono"
            )
        }
    }

    private func coordinate(_ value: CGFloat, extent: CGFloat) -> CGFloat {
        abs(value) <= 1 ? value * extent : value
    }
}
