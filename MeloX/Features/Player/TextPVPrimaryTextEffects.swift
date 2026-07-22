// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

extension TextPVEffectPainter {
    func drawBigOutlineText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let characters = frame.visibleCharacters
        guard !characters.isEmpty else { return }
        let baseFontSize = config.number("fontSize", default: 0)
        let fontSize = baseFontSize > 0
            ? baseFontSize
            : min(size.height * 0.35, size.width / CGFloat(characters.count) * 0.7)
        let spacing = fontSize * config.number("spacingFrac", default: 1.3)
        let totalWidth = CGFloat(characters.count - 1) * spacing
        let startX = (size.width - totalWidth) / 2
        let staggerY = config.number("staggerY", default: fontSize * 0.25)
        let staggerDelay = config.number("staggerDelay", default: 0.15)
        let fill = color("color", in: config, default: "#e0e0e0")
        let stroke = color("strokeColor", in: config, default: "#ffffff")
        let family = config.string("fontFamily", default: "Noto Sans JP")

        for (index, character) in characters.enumerated() {
            let elapsed = max(0, frame.segmentTime * frame.animationSpeed * 2.5
                - CGFloat(index) * staggerDelay * frame.animationSpeed)
            guard elapsed > 0 else { continue }
            let progress = min(1, elapsed / 0.6)
            let elastic = elasticOut(progress)
            let yTarget = size.height / 2
                + (index.isMultiple(of: 2) ? -staggerY : staggerY)
            let y = yTarget + 80 * (1 - elastic)
            let rotation = (1 - elastic) * 0.4 * (index.isMultiple(of: 2) ? 1 : -1)
            drawText(
                String(character),
                in: &context,
                at: CGPoint(x: startX + CGFloat(index) * spacing, y: y),
                color: fill,
                size: fontSize * (elastic * 1.05 + frame.beatIntensity * 0.06),
                family: family,
                rotation: rotation,
                opacity: min(1, elapsed * 3),
                strokeColor: stroke,
                strokeWidth: max(3, fontSize * 0.03)
            )
        }
    }

    func drawShadowShapes(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let definitions = config.array("shapes")
        let fill = color("color", in: config, default: "#ffffff")
        let shadow = color("shadowColor", in: config, default: "#000066")
        let shadowAlpha = config.number("shadowAlpha", default: 0.5)
        let shadowX = config.number("shadowOffX", default: 12)
        let shadowY = config.number("shadowOffY", default: 14)

        for (index, value) in definitions.enumerated() {
            guard let item = value.objectValue else { continue }
            let rawX = item["x"]?.numberValue ?? 0.5
            let rawY = item["y"]?.numberValue ?? 0.5
            let rawSize = item["size"]?.numberValue ?? 0.12
            let center = CGPoint(
                x: rawX <= 1 ? rawX * size.width : rawX,
                y: rawY <= 1 ? rawY * size.height : rawY
            )
            let side = rawSize <= 1 ? rawSize * min(size.width, size.height) : rawSize
            let type = item["type"]?.stringValue ?? "square"
            let baseRotation = item["rotation"]?.numberValue ?? 0
            let breathSpeed = 0.6 + random(index * 4) * 0.8
            let breathPhase = random(index * 4 + 1) * 2 * .pi
            let breathAmount = 0.08 + random(index * 4 + 2) * 0.08
            let scale = 1 + sin(frame.animatedTime * breathSpeed + breathPhase)
                * breathAmount * frame.motionIntensity
            let rotation = baseRotation
                + sin(frame.animatedTime * breathSpeed * 0.7 + breathPhase)
                * 0.05 * frame.motionIntensity
            let width = type == "rect" ? side * 1.6 : side
            let height = type == "rect" ? side * 0.4 : side
            let shape = rotatedRectangle(
                center: center,
                width: width * scale,
                height: height * scale,
                rotation: rotation
            )
            let shadowShape = rotatedRectangle(
                center: CGPoint(x: center.x + shadowX, y: center.y + shadowY),
                width: width * scale,
                height: height * scale,
                rotation: rotation
            )
            context.fill(shadowShape, with: .color(shadow.opacity(shadowAlpha)))
            context.fill(shape, with: .color(fill))
        }
    }

    func drawLayeredText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let fontSize = config.number("fontSize", default: 80)
        let maxLayers = max(config.integer("maxLayers", default: 4), 1)
        let fill = color("color", in: config, default: "$primary")
        let progress = min(1, frame.segmentTime * 3 * frame.animationSpeed)
        let eased = 1 - pow(1 - progress, 2)
        let overshoot = progress < 0.8 ? 1 + 0.15 * sin(progress * .pi * 3) : 1
        let scales: [CGFloat] = [1, 1.35, 0.75, 1.15]
        let offsets: [CGPoint] = [
            .zero,
            CGPoint(x: -20, y: 15),
            CGPoint(x: 15, y: -10),
            CGPoint(x: -10, y: -20),
        ]

        for depth in stride(from: maxLayers - 1, through: 1, by: -1) {
            let offset = offsets[depth % offsets.count]
            drawText(
                frame.previousText.isEmpty ? frame.normalizedText : frame.previousText,
                in: &context,
                at: CGPoint(x: size.width / 2 + offset.x, y: size.height / 2 + offset.y),
                color: fill,
                size: fontSize * scales[depth % scales.count],
                family: "Noto Serif JP",
                opacity: max(0.08, 0.55 - CGFloat(depth) * 0.18),
                tracking: 8
            )
        }
        drawText(
            frame.normalizedText,
            in: &context,
            at: CGPoint(x: size.width / 2, y: size.height / 2),
            color: fill,
            size: fontSize * eased * overshoot,
            family: "Noto Serif JP",
            opacity: min(1, frame.segmentTime * 5 * frame.animationSpeed),
            tracking: 8
        )
    }

    func drawWaveText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let characters = frame.visibleCharacters
        guard !characters.isEmpty else { return }
        let spread = size.width * config.number("charSpreadFrac", default: 0.5)
        let spacing = characters.count > 1 ? spread / CGFloat(characters.count - 1) : 0
        let startX = size.width / 2 - spread / 2
        let fontSize = config.number("fontSize", default: 52)
        let staggerY = config.number("staggerY", default: 18)
        let fill = color("color", in: config, default: "#ffffff")
        for (index, character) in characters.enumerated() {
            let elapsed = max(0, frame.segmentTime - CGFloat(index) * 0.15)
            guard elapsed > 0 else { continue }
            let raw = min(1, elapsed * 3)
            let elastic = raw < 1
                ? raw * (1 + 0.4 * sin(raw * .pi * 3) * (1 - raw))
                : 1
            let yProgress = min(1, elapsed * 4)
            let yEased = 1 - pow(1 - yProgress, 2)
            let targetY = size.height / 2 + (index.isMultiple(of: 2) ? -staggerY : staggerY)
            drawText(
                String(character),
                in: &context,
                at: CGPoint(
                    x: startX + CGFloat(index) * spacing,
                    y: targetY + 60 * (1 - yEased)
                ),
                color: fill,
                size: fontSize * elastic * 1.1,
                family: config.string("fontFamily", default: "Noto Serif JP"),
                rotation: (1 - min(1, elapsed * 2.5)) * 0.6
                    * (index.isMultiple(of: 2) ? 1 : -1),
                opacity: min(1, elapsed * 5)
            )
        }
    }

    func drawHeroText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let position = point(
            x: config.number("x", default: 0.5),
            y: config.number("y", default: 0.5),
            in: size
        )
        let animation = config.string("animation", default: "")
        let amount = config.number("animationAmount", default: 0.03)
        let speed = config.number("animationSpeed", default: 0.5)
        let scale = animation == "breathe"
            ? 1 + sin(frame.animatedTime * speed * 2 * .pi) * amount * frame.motionIntensity
            : 1
        drawText(
            frame.normalizedText,
            in: &context,
            at: position,
            color: color("color", in: config, default: "$text"),
            size: config.number("fontSize", default: 120) * scale,
            family: config.string("fontFamily", default: "Noto Serif JP"),
            rotation: config.number("rotation", default: 0) * .pi / 180,
            opacity: min(1, frame.segmentTime * max(frame.animationSpeed, 0.5) * 4),
            tracking: config.number("letterSpacing", default: 8),
            strokeColor: config["strokeColor"] == nil
                ? nil
                : color("strokeColor", in: config, default: "#000000"),
            strokeWidth: config.number("strokeWidth", default: 0)
        )
    }

    func drawCuteOutlineText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        drawText(
            frame.normalizedText,
            in: &context,
            at: point(
                x: config.number("x", default: 0.5),
                y: config.number("y", default: 0.5),
                in: size
            ),
            color: color("fillColor", in: config, default: "#fab2b5"),
            size: config.number("fontSize", default: 80),
            family: config.string("fontFamily", default: "Noto Sans JP"),
            opacity: min(1, frame.segmentTime * max(frame.animationSpeed, 0.5) * 4),
            tracking: config.number("letterSpacing", default: 4),
            strokeColor: color("strokeColor", in: config, default: "#ffffff"),
            strokeWidth: config.number("strokeWidth", default: 8)
        )
    }

    private func elasticOut(_ progress: CGFloat) -> CGFloat {
        if progress == 0 || progress == 1 { return progress }
        return pow(2, -10 * progress)
            * sin((progress * 10 - 0.75) * (2 * .pi / 3)) + 1
    }
}
