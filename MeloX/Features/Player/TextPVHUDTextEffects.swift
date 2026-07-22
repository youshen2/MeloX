// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

extension TextPVEffectPainter {
    func drawHUDStatusText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let fontSize = config.number("fontSize", default: 13)
        drawText(
            config.string("centerText", default: "SYS.MONITOR // ONLINE"),
            in: &context,
            at: CGPoint(x: size.width / 2, y: 15),
            color: color("textColor", in: config, default: "$text"),
            size: fontSize,
            family: "Courier New",
            anchor: .top
        )
        drawText(
            config.string("rightText", default: "NETWATCH // PROTOCOL V.2.0.77"),
            in: &context,
            at: CGPoint(x: size.width - 30, y: 15),
            color: color("alertColor", in: config, default: "$accent"),
            size: fontSize - 2,
            family: "Courier New",
            anchor: .topTrailing
        )
    }

    func drawHUDInfoPanel(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        guard let target = frame.motionTargets.first else { return }
        let panelWidth = config.number("panelWidth", default: 240)
        let panelHeight = config.number("panelHeight", default: 420)
        let panel = CGRect(
            x: size.width - panelWidth - 30,
            y: 70,
            width: panelWidth,
            height: panelHeight
        )
        let primary = color("primaryColor", in: config, default: "$primary")
        let alert = color("alertColor", in: config, default: "$accent")
        let text = color("textColor", in: config, default: "$text")
        let grid = color("gridColor", in: config, default: "#323200")
        context.fill(Path(panel), with: .color(.black.opacity(0.4)))
        context.fill(
            Path(CGRect(x: panel.minX, y: panel.minY, width: panel.width, height: 5)),
            with: .color(alert.opacity(0.9))
        )
        context.stroke(Path(panel), with: .color(alert.opacity(0.7)), lineWidth: 1)
        let avatar = CGRect(
            x: panel.minX + 10,
            y: panel.minY + 40,
            width: panel.width - 20,
            height: 140
        )
        context.stroke(Path(avatar), with: .color(alert.opacity(0.5)), lineWidth: 1)
        var cross = Path()
        cross.move(to: CGPoint(x: avatar.minX, y: avatar.minY))
        cross.addLine(to: CGPoint(x: avatar.maxX, y: avatar.maxY))
        cross.move(to: CGPoint(x: avatar.minX, y: avatar.maxY))
        cross.addLine(to: CGPoint(x: avatar.maxX, y: avatar.minY))
        context.stroke(cross, with: .color(grid.opacity(0.4)), lineWidth: 1)

        let targetID = "T-\(Int(target.midX))\(Int(target.midY))"
        let lines: [(String, CGFloat, CGFloat, CGFloat, Color, Font.Weight)] = [
            ("TARGET \(targetID)", 10, 18, 14, alert, .bold),
            ("IMG_REC_FAIL", panel.width / 2 - 40, 105, 11, alert, .regular),
            ("NAME", 15, 195, 9, text, .regular),
            ("UNKNOWN", 15, 208, 12, primary, .regular),
            ("GENDER", 15, 230, 9, text, .regular),
            ("N/A", 15, 243, 12, primary, .regular),
            ("HEIGHT", panel.width / 2 + 5, 230, 9, text, .regular),
            ("---cm", panel.width / 2 + 5, 243, 12, primary, .regular),
            ("THREAT", 15, 265, 9, text, .regular),
            ("CRITICAL", 15, 278, 12, alert, .bold),
            ("LOCATION", 15, 300, 9, text, .regular),
            ("NIGHT CITY", 15, 313, 12, primary, .regular),
            ("NOTES", 15, 335, 9, text, .regular),
            ("Scanning...", 15, 348, 12, text, .regular),
            ("ARASAKA INTEL // CLASSIFIED", 10, panel.height - 18, 9, alert, .regular),
        ]
        for line in lines {
            drawText(
                line.0,
                in: &context,
                at: CGPoint(x: panel.minX + line.1, y: panel.minY + line.2),
                color: line.4,
                size: line.3,
                family: "Courier New",
                weight: line.5,
                anchor: .topLeading
            )
        }
    }

    func drawPixelTypewriter(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let characters = frame.visibleCharacters
        guard !characters.isEmpty else { return }
        let delay = max(config.number("charDelay", default: 0.08), 0.01)
        let visibleCount = min(
            Int(frame.segmentTime * max(frame.animationSpeed, 0.01) / delay),
            characters.count
        )
        let split = max(config.integer("maxCharsPerSide", default: 5), 1)
        let visible = characters.prefix(max(visibleCount, 0))
        let leftText = String(visible.prefix(split))
        let rightText = visible.count > split ? String(visible.dropFirst(split)) : ""
        let fontSize = config.number("fontSize", default: 44)
        let y = size.height * config.number("y", default: 0.5)
        let leftX = size.width * config.number("leftX", default: 0.2)
        let rightX = size.width * config.number("rightX", default: 0.6)
        let fill = color("fillColor", in: config, default: "$text")
        let stroke = color("strokeColor", in: config, default: "#ffffff")
        let shadow = color("shadowColor", in: config, default: "$primary")
        let shadowX = config.number("shadowOffsetX", default: 3)
        let shadowY = config.number("shadowOffsetY", default: 3)
        let tracking = config.number("letterSpacing", default: 3)

        for (text, x) in [(leftText, leftX), (rightText, rightX)] where !text.isEmpty {
            drawText(
                text,
                in: &context,
                at: CGPoint(x: x + shadowX, y: y + shadowY),
                color: shadow,
                size: fontSize,
                family: "Courier New",
                anchor: .leading,
                tracking: tracking
            )
            drawText(
                text,
                in: &context,
                at: CGPoint(x: x, y: y),
                color: fill,
                size: fontSize,
                family: "Courier New",
                anchor: .leading,
                tracking: tracking,
                strokeColor: stroke,
                strokeWidth: config.number("strokeWidth", default: 6)
            )
        }

        let showCursor = visibleCount < characters.count
            || config.bool("showCursorWhenDone", default: false)
        guard showCursor else { return }
        let blinkSpeed = max(config.number("cursorBlinkSpeed", default: 0.5), 0.1)
        guard Int(frame.time / blinkSpeed).isMultiple(of: 2) else { return }
        let cursorWidth = config.number("cursorWidth", default: 4)
        let cursorHeight = fontSize * 0.8
        let rightSide = visible.count > split
        let currentText = rightSide ? rightText : leftText
        let baseX = rightSide ? rightX : leftX
        let cursorX = baseX + CGFloat(currentText.count) * fontSize * 0.7 + 5
        context.fill(
            Path(CGRect(
                x: cursorX,
                y: y - cursorHeight / 2,
                width: cursorWidth,
                height: cursorHeight
            )),
            with: .color(color("cursorColor", in: config, default: "$primary").opacity(0.8))
        )
    }
}
