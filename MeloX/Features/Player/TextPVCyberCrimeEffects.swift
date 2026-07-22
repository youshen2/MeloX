// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

extension TextPVEffectPainter {
    func drawDataMonitors(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("count", default: 4), 1)
        let border = color("borderColor", in: config, default: "#ffffff")
        let fill = color("fillColor", in: config, default: "#000000")
        let data = color("dataColor", in: config, default: "#ffffff")
        let alpha = config.number("alpha", default: 0.65)
        for index in 0..<count {
            let width = size.width * (0.12 + random(index * 5 + 2) * 0.16)
            let height = size.height * (0.1 + random(index * 5 + 3) * 0.18)
            let rect = CGRect(
                x: random(index * 5) * max(size.width - width, 0),
                y: random(index * 5 + 1) * max(size.height - height, 0),
                width: width,
                height: height
            )
            context.fill(Path(rect), with: .color(fill.opacity(alpha * 0.72)))
            context.stroke(Path(rect), with: .color(border.opacity(alpha)), lineWidth: 1)
            var lines = Path()
            for row in 1...6 {
                let y = rect.minY + CGFloat(row) * rect.height / 8
                lines.move(to: CGPoint(x: rect.minX + 8, y: y))
                lines.addLine(to: CGPoint(
                    x: rect.minX + 8 + rect.width * (0.18 + random(index * 30 + row) * 0.68),
                    y: y
                ))
            }
            context.stroke(lines, with: .color(data.opacity(alpha * 0.75)), lineWidth: 1)
            drawText(
                "MON_0\(index + 1) // LIVE",
                in: &context,
                at: CGPoint(x: rect.minX + 6, y: rect.minY + 5),
                color: data,
                size: 8,
                family: "mono",
                anchor: .topLeading,
                opacity: alpha
            )
        }
    }

    func drawNoiseText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("count", default: 10), 1)
        let foreground = color("color", in: config, default: "#ffffff")
        let background = color("bgColor", in: config, default: "#000000")
        let glyphs = TextPVTextResources.noiseGlyphs
        for index in 0..<count {
            let length = 5 + Int(random(index + 80) * 15)
            let string = String((0..<length).map { position in
                glyphs[Int(random(index * 50 + position) * CGFloat(glyphs.count - 1))]
            })
            let fontSize = 7 + random(index + 120) * 7
            let position = CGPoint(
                x: random(index * 3) * size.width,
                y: random(index * 3 + 1) * size.height
            )
            let blockWidth = CGFloat(length) * fontSize * 0.62 + 6
            context.fill(
                Path(CGRect(
                    x: position.x - 3,
                    y: position.y - fontSize / 2 - 2,
                    width: blockWidth,
                    height: fontSize + 4
                )),
                with: .color(background.opacity(0.82))
            )
            drawText(
                string,
                in: &context,
                at: position,
                color: foreground,
                size: fontSize,
                family: "mono",
                anchor: .leading,
                opacity: 0.75
            )
        }
    }

    func drawVictimOutline(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let scale = config.number("scale", default: 1.5)
        let stroke = color("color", in: config, default: "#ffffff")
        let alpha = config.number("alpha", default: 0.88)
        let lineWidth = config.number("lineWidth", default: 5)
        let center = CGPoint(x: size.width * 0.48, y: size.height * 0.54)
        let unit = min(size.width, size.height) * 0.095 * scale
        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - unit * 0.42,
            y: center.y - unit * 2.35,
            width: unit * 0.84,
            height: unit * 0.84
        ))
        path.move(to: CGPoint(x: center.x, y: center.y - unit * 1.5))
        path.addCurve(
            to: CGPoint(x: center.x - unit * 0.15, y: center.y + unit * 0.5),
            control1: CGPoint(x: center.x + unit * 0.4, y: center.y - unit * 0.75),
            control2: CGPoint(x: center.x - unit * 0.45, y: center.y - unit * 0.2)
        )
        path.move(to: CGPoint(x: center.x - unit * 0.02, y: center.y - unit * 1.15))
        path.addLine(to: CGPoint(x: center.x - unit * 1.6, y: center.y - unit * 0.2))
        path.move(to: CGPoint(x: center.x + unit * 0.08, y: center.y - unit * 1.05))
        path.addLine(to: CGPoint(x: center.x + unit * 1.45, y: center.y - unit * 0.55))
        path.move(to: CGPoint(x: center.x - unit * 0.15, y: center.y + unit * 0.45))
        path.addLine(to: CGPoint(x: center.x - unit * 1.2, y: center.y + unit * 2.1))
        path.move(to: CGPoint(x: center.x - unit * 0.05, y: center.y + unit * 0.5))
        path.addLine(to: CGPoint(x: center.x + unit * 1.35, y: center.y + unit * 1.75))
        context.stroke(path, with: .color(stroke.opacity(alpha)), lineWidth: lineWidth)
    }

    func drawBloodSplatter(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("count", default: 5), 1)
        let fill = color("color", in: config, default: "#8b0000")
        let alpha = config.number("alpha", default: 0.85)
        let scale = config.number("size", default: 1.1)
        for splatter in 0..<count {
            let center = CGPoint(
                x: random(splatter * 3) * size.width,
                y: random(splatter * 3 + 1) * size.height
            )
            let radius = (18 + random(splatter * 3 + 2) * 48) * scale
            var blob = Path()
            let points = 18
            for index in 0..<points {
                let angle = CGFloat(index) / CGFloat(points) * 2 * .pi
                let spike = index.isMultiple(of: 4) ? 1.8 : 1
                let currentRadius = radius * (0.55 + random(splatter * 100 + index) * 0.55) * spike
                let point = CGPoint(
                    x: center.x + cos(angle) * currentRadius,
                    y: center.y + sin(angle) * currentRadius
                )
                index == 0 ? blob.move(to: point) : blob.addLine(to: point)
            }
            blob.closeSubpath()
            context.fill(blob, with: .color(fill.opacity(alpha)))
            for drop in 0..<7 {
                let angle = random(splatter * 20 + drop) * 2 * .pi
                let distance = radius * (1.2 + random(splatter * 20 + drop + 50) * 2.2)
                let dropRadius = 2 + random(splatter * 20 + drop + 80) * 7
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x + cos(angle) * distance - dropRadius,
                        y: center.y + sin(angle) * distance - dropRadius,
                        width: dropRadius * 2,
                        height: dropRadius * 2
                    )),
                    with: .color(fill.opacity(alpha * 0.8))
                )
            }
        }
    }

    func drawCrimeTape(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = max(config.integer("count", default: 6), 1)
        let tapeColor = color("tapeColor", in: config, default: "#f5c800")
        let textColor = color("textColor", in: config, default: "#000000")
        let tapeWidth = config.number("tapeWidth", default: 52)
        let speed = config.number("speed", default: 70)
        let label = config.string("text", default: "POLICE LINE DO NOT CROSS")
        let angleRange = config.number("angleRange", default: 0.22)
        let travel = (frame.animatedTime * speed).truncatingRemainder(dividingBy: 260)
        for index in 0..<count {
            let angle = signedRandom(index) * angleRange
            let center = CGPoint(
                x: size.width / 2 + (index.isMultiple(of: 2) ? travel : -travel),
                y: size.height * CGFloat(index + 1) / CGFloat(count + 1)
            )
            let length = hypot(size.width, size.height) * 1.35
            let tape = rotatedRectangle(
                center: center,
                width: length,
                height: tapeWidth,
                rotation: angle
            )
            context.fill(tape, with: .color(tapeColor.opacity(0.94)))
            let repetitions = max(Int(length / 250), 2)
            for repeatIndex in 0..<repetitions {
                let x = center.x - length / 2 + CGFloat(repeatIndex) * 250 + 125
                let y = center.y + tan(angle) * (x - center.x)
                drawText(
                    label,
                    in: &context,
                    at: CGPoint(x: x, y: y),
                    color: textColor,
                    size: 17,
                    family: "mono",
                    rotation: angle,
                    tracking: 1.5
                )
            }
        }
    }
}
