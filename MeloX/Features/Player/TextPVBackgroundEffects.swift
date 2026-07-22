// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

extension TextPVEffectPainter {
    func drawBackgroundBlocks(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = config.integer("count", default: 7)
        let alpha = config.number("alpha", default: 0.5)
        for index in 0..<count {
            let brightness = 230 + Int(random(index * 5 + 4) * 19)
            let shade = Color(
                red: Double(brightness) / 255,
                green: Double(brightness) / 255,
                blue: Double(brightness) / 255
            )
            let rect = CGRect(
                x: random(index * 5) * size.width,
                y: random(index * 5 + 1) * size.height,
                width: (0.08 + random(index * 5 + 2) * 0.25) * size.width,
                height: (0.04 + random(index * 5 + 3) * 0.3) * size.height
            )
            context.fill(Path(rect), with: .color(shade.opacity(alpha)))
        }
    }

    func drawCheckerboard(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let cell = max(config.number("cellSize", default: 40), 4)
        let color1 = color("color1", in: config, default: "#000000")
        let color2 = color("color2", in: config, default: "#ffffff")
        let alpha = config.number("alpha", default: 0.08)
        let columns = Int(ceil(size.width / cell))
        let rows = Int(ceil(size.height / cell))
        let paths = cachedPathPair(
            "checkerboard",
            size: size,
            discriminator: "\(cell)"
        ) {
            var first = Path()
            var second = Path()
            for row in 0...rows {
                for column in 0...columns {
                    let rect = CGRect(
                        x: CGFloat(column) * cell,
                        y: CGFloat(row) * cell,
                        width: cell,
                        height: cell
                    )
                    if (row + column).isMultiple(of: 2) {
                        first.addRect(rect)
                    } else {
                        second.addRect(rect)
                    }
                }
            }
            return (first, second)
        }
        context.fill(paths.0, with: .color(color1.opacity(alpha)))
        context.fill(paths.1, with: .color(color2.opacity(alpha)))
    }

    func drawDiagonalHatch(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let spacing = max(config.number("spacing", default: 8), 3)
        let lineWidth = config.number("lineWidth", default: 0.8)
        let stroke = color("color", in: config, default: "$accent")
        let alpha = config.number("alpha", default: 0.15)
        let path = cachedPath(
            "diagonalHatch",
            size: size,
            discriminator: "\(spacing)"
        ) {
            var path = Path()
            var offset = -size.height
            while offset < size.width + size.height {
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                offset += spacing
            }
            return path
        }
        context.stroke(
            path,
            with: .color(stroke.opacity(alpha)),
            lineWidth: lineWidth
        )
    }

    func drawGradientOverlay(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let top = color("colorTop", in: config, default: "#004040")
        let middle = color("colorMid", in: config, default: config.string("colorTop", default: "#004040"))
        let bottom = color("colorBottom", in: config, default: "#001020")
        let alpha = config.number("alpha", default: 0.5)
        let gradient = Gradient(colors: [
            top.opacity(alpha),
            middle.opacity(alpha),
            bottom.opacity(alpha),
        ])
        let bounds = CGRect(origin: .zero, size: size)

        if config.string("mode", default: "linear") == "radial" {
            context.fill(
                Path(bounds),
                with: .radialGradient(
                    gradient,
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.72
                )
            )
        } else {
            context.fill(
                Path(bounds),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                )
            )
        }
    }

    func drawHalftoneBlocks(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let dotSize = config.number("size", default: 3)
        let spacing = max(config.number("spacing", default: 6), dotSize + 1)
        let fill = color("color", in: config, default: "$primary")
        let alpha = config.number("alpha", default: 0.12)
        let blocks = [
            CGRect(x: 0, y: 0, width: size.width * 0.42, height: size.height * 0.26),
            CGRect(x: size.width * 0.58, y: size.height * 0.2, width: size.width * 0.42, height: size.height * 0.34),
            CGRect(x: size.width * 0.1, y: size.height * 0.7, width: size.width * 0.58, height: size.height * 0.3),
        ]
        let dots = cachedPath(
            "halftoneBlocks",
            size: size,
            discriminator: "\(dotSize):\(spacing)"
        ) {
            var dots = Path()
            for block in blocks {
                var y = block.minY
                while y <= block.maxY {
                    var x = block.minX
                    while x <= block.maxX {
                        dots.addEllipse(in: CGRect(
                            x: x - dotSize / 2,
                            y: y - dotSize / 2,
                            width: dotSize,
                            height: dotSize
                        ))
                        x += spacing
                    }
                    y += spacing
                }
            }
            return dots
        }
        context.fill(dots, with: .color(fill.opacity(alpha)))
    }

    func drawPinkGrid(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let cell = max(config.number("cellSize", default: 50), 12)
        let speed = config.number("speed", default: 30)
        let offset = (frame.animatedTime * speed).truncatingRemainder(dividingBy: cell)
        let fill = color("color", in: config, default: "#f8c7ca")
        let line = color("lineColor", in: config, default: "#ffffff")
        let lineWidth = config.number("lineWidth", default: 2)
        let alpha = config.number("alpha", default: 1)
        var path = Path()
        var x = -cell + offset
        while x < size.width + cell {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += cell
        }
        var y = -cell + offset
        while y < size.height + cell {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += cell
        }
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(fill.opacity(alpha)))
        context.stroke(path, with: .color(line.opacity(alpha)), lineWidth: lineWidth)
    }

    func drawPinkStripes(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let stripeWidth = max(config.number("stripeWidth", default: 150), 20)
        let speed = config.number("speed", default: 0.3)
        let angle = config.number("angle", default: -45) * .pi / 180
        let alpha = config.number("alpha", default: 1)
        let pink = color("pinkColor", in: config, default: "#fbbdbe")
        let travel = frame.animatedTime * speed * stripeWidth
        let diagonal = hypot(size.width, size.height)
        var copy = context
        copy.translateBy(x: size.width / 2, y: size.height / 2)
        copy.rotate(by: .radians(Double(angle)))
        var x = -diagonal * 1.5 + travel.truncatingRemainder(dividingBy: stripeWidth * 2)
        while x < diagonal * 1.5 {
            copy.fill(
                Path(CGRect(
                    x: x,
                    y: -diagonal,
                    width: stripeWidth,
                    height: diagonal * 2
                )),
                with: .color(pink.opacity(alpha))
            )
            x += stripeWidth * 2
        }
    }

    func drawTextureBackground(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let pattern = config.string("pattern", default: "noise")
        let fill = color("color", in: config, default: "$secondary")
        let alpha = config.number("alpha", default: pattern == "dots" ? 0.2 : 0.12)
        if pattern == "dots" {
            let dots = cachedPath(
                "textureDots",
                size: size,
                discriminator: "2:8"
            ) {
                var dots = Path()
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        dots.addEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
                        x += 8
                    }
                    y += 8
                }
                return dots
            }
            context.fill(dots, with: .color(fill.opacity(alpha)))
            return
        }

        let count = Int(size.width * size.height / 180)
        let grain = cachedPath(
            "textureNoise",
            size: size,
            discriminator: "\(count)",
            includesSeed: true
        ) {
            var grain = Path()
            for index in 0..<count {
                let side = 1 + random(index * 3 + 2) * 2
                grain.addRect(CGRect(
                    x: random(index * 3) * size.width,
                    y: random(index * 3 + 1) * size.height,
                    width: side,
                    height: side
                ))
            }
            return grain
        }
        context.fill(grain, with: .color(fill.opacity(alpha)))
    }

    func drawTriangleGrid(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let columns = max(config.integer("cols", default: 9), 2)
        let step = size.width / CGFloat(columns)
        let height = step * sqrt(3) / 2
        let stroke = color("color", in: config, default: "$secondary")
        let alpha = config.number("alpha", default: 0.3)
        let path = cachedPath(
            "triangleGrid",
            size: size,
            discriminator: "\(columns)"
        ) {
            var path = Path()
            var row = 0
            var y: CGFloat = -height
            while y < size.height + height {
                var x: CGFloat = row.isMultiple(of: 2) ? -step / 2 : 0
                while x < size.width + step {
                    path.move(to: CGPoint(x: x, y: y + height))
                    path.addLine(to: CGPoint(x: x + step / 2, y: y))
                    path.addLine(to: CGPoint(x: x + step, y: y + height))
                    path.closeSubpath()
                    x += step
                }
                row += 1
                y += height
            }
            return path
        }
        context.stroke(path, with: .color(stroke.opacity(alpha)), lineWidth: 1)
    }
}
