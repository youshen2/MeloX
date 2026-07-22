import SwiftUI

extension TextPV1GeometryLayer {
    func drawSplitScreen(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let foreground = Color.white.opacity(0.9 * (1 - motion.exit))
        let dividerX = size.width * (0.88 - motion.entry * 0.13)

        context.fill(
            Path(
                CGRect(
                    x: dividerX,
                    y: 0,
                    width: size.width - dividerX,
                    height: size.height
                )
            ),
            with: .color(foreground.opacity(0.92))
        )

        var divider = Path()
        divider.move(to: CGPoint(x: dividerX - size.width * 0.035, y: 0))
        divider.addLine(to: CGPoint(x: dividerX + size.width * 0.025, y: size.height))
        context.stroke(
            divider,
            with: .color(foreground),
            lineWidth: max(3, size.width * 0.012)
        )

        for index in 0..<6 {
            let randomX = TextPV1StableSeed.unit(index * 2, seed: seed)
            let randomY = TextPV1StableSeed.unit(index * 2 + 1, seed: seed)
            let width = size.width * (0.08 + CGFloat(index % 3) * 0.045)
            let height = size.height * (0.08 + CGFloat((index + 1) % 3) * 0.035)
            let rect = CGRect(
                x: randomX * size.width * 0.68,
                y: randomY * max(size.height - height, 1),
                width: width,
                height: height
            )
            if index.isMultiple(of: 3) {
                context.fill(Path(rect), with: .color(foreground.opacity(0.16)))
            } else {
                context.stroke(
                    Path(rect),
                    with: .color(foreground.opacity(0.44)),
                    lineWidth: max(1, size.width * 0.0025)
                )
            }
        }

        let movingWidth = size.width * (0.12 + motion.entry * 0.34)
        context.fill(
            Path(
                CGRect(
                    x: size.width * 0.08,
                    y: size.height * 0.76,
                    width: movingWidth,
                    height: max(3, size.height * 0.018)
                )
            ),
            with: .color(foreground.opacity(0.62))
        )
    }

    func drawVerticalColumns(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let foreground = Color.black.opacity(0.78 * (1 - motion.exit))
        let columnCount = 6

        for index in 0..<columnCount {
            let progress = CGFloat(index) / CGFloat(columnCount - 1)
            let x = size.width * (0.08 + progress * 0.84)
            let top = size.height
                * (0.06 + TextPV1StableSeed.unit(index, seed: seed) * 0.18)
            let bottom = size.height
                * (0.78 + TextPV1StableSeed.unit(index + 20, seed: seed) * 0.16)
            let width = index.isMultiple(of: 3)
                ? max(4, size.width * 0.018)
                : max(1, size.width * 0.004)
            var column = Path()
            column.move(to: CGPoint(x: x, y: top))
            column.addLine(to: CGPoint(x: x, y: bottom))
            context.stroke(
                column,
                with: .color(foreground.opacity(index.isMultiple(of: 3) ? 0.85 : 0.38)),
                lineWidth: width
            )

            let markerSide = min(size.width, size.height)
                * (index.isMultiple(of: 2) ? 0.06 : 0.035)
            let marker = CGRect(
                x: x - markerSide / 2,
                y: (index.isMultiple(of: 2) ? top : bottom) - markerSide / 2,
                width: markerSide,
                height: markerSide
            )
            context.stroke(
                Path(marker),
                with: .color(foreground.opacity(0.55)),
                lineWidth: max(1, size.width * 0.003)
            )
        }

        let capHeight = max(4, size.height * 0.025)
        context.fill(
            Path(CGRect(x: 0, y: 0, width: size.width * motion.entry, height: capHeight)),
            with: .color(foreground)
        )
        context.fill(
            Path(
                CGRect(
                    x: size.width * (1 - motion.entry),
                    y: size.height - capHeight,
                    width: size.width * motion.entry,
                    height: capHeight
                )
            ),
            with: .color(foreground)
        )
    }

    func drawTargetLock(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let foreground = Color.white.opacity(0.82 * (1 - motion.exit))
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
        let minimumSide = min(size.width, size.height)

        for index in 0..<4 {
            let radius = minimumSide
                * (0.1 + CGFloat(index) * 0.105 + motion.entryKick * 0.08)
            context.stroke(
                Path(
                    ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                ),
                with: .color(foreground.opacity(0.26 + CGFloat(index) * 0.13)),
                lineWidth: index == 2 ? max(3, size.width * 0.008) : 1.2
            )
        }

        for index in 0..<12 {
            let angle = CGFloat(index) / 12 * 2 * .pi + motion.phase * 0.006
            let innerRadius = minimumSide * 0.31
            let outerRadius = minimumSide
                * (0.4 + TextPV1StableSeed.unit(index, seed: seed) * 0.12)
            var spoke = Path()
            spoke.move(
                to: CGPoint(
                    x: center.x + cos(angle) * innerRadius,
                    y: center.y + sin(angle) * innerRadius
                )
            )
            spoke.addLine(
                to: CGPoint(
                    x: center.x + cos(angle) * outerRadius,
                    y: center.y + sin(angle) * outerRadius
                )
            )
            context.stroke(
                spoke,
                with: .color(foreground.opacity(index.isMultiple(of: 3) ? 0.72 : 0.3)),
                lineWidth: index.isMultiple(of: 3) ? 2.5 : 1
            )
        }

        var horizontal = Path()
        horizontal.move(to: CGPoint(x: 0, y: center.y))
        horizontal.addLine(to: CGPoint(x: size.width, y: center.y))
        context.stroke(
            horizontal,
            with: .color(foreground.opacity(0.34)),
            lineWidth: 1
        )
    }

    func drawStaggeredBands(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let foreground = Color.black.opacity(0.86 * (1 - motion.exit))

        for index in 0..<5 {
            let y = size.height * (0.12 + CGFloat(index) * 0.19)
            let startsTrailing = index.isMultiple(of: 2)
            let width = size.width * (0.18 + CGFloat(index % 3) * 0.08)
            let revealWidth = width * motion.entry
            let x = startsTrailing
                ? size.width - revealWidth
                : 0
            context.fill(
                Path(
                    CGRect(
                        x: x,
                        y: y,
                        width: revealWidth,
                        height: index == 2
                            ? max(5, size.height * 0.025)
                            : max(2, size.height * 0.009)
                    )
                ),
                with: .color(foreground.opacity(index == 2 ? 0.9 : 0.46))
            )
        }

        for index in 0..<7 {
            let x = size.width * (0.12 + CGFloat(index) * 0.115)
            let y = size.height
                * (index.isMultiple(of: 2) ? 0.2 : 0.72)
            let side = min(size.width, size.height)
                * (0.035 + TextPV1StableSeed.unit(index, seed: seed) * 0.05)
            let rect = CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side)
            if index.isMultiple(of: 3) {
                context.fill(Path(rect), with: .color(foreground.opacity(0.66)))
            } else {
                context.stroke(
                    Path(rect),
                    with: .color(foreground.opacity(0.55)),
                    lineWidth: max(1, size.width * 0.003)
                )
            }
        }

        var diagonal = Path()
        diagonal.move(to: CGPoint(x: -size.width * 0.08, y: size.height * 0.9))
        diagonal.addLine(to: CGPoint(x: size.width * 1.08, y: size.height * 0.1))
        context.stroke(
            diagonal,
            with: .color(foreground.opacity(0.16)),
            lineWidth: max(2, size.width * 0.006)
        )
    }
}
