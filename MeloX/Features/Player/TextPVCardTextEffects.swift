// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

extension TextPVEffectPainter {
    func drawGlowTextCards(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let characters = frame.visibleCharacters
        guard !characters.isEmpty else { return }
        let baseFontSize = config.number("fontSize", default: 70)
        let charsPerRow = max(config.integer("charsPerRow", default: 5), 1)
        let rowCount = Int(ceil(Double(characters.count) / Double(charsPerRow)))
        let sizeVariance = config.number("sizeVariance", default: 0.3)
        let cardPadding = config.number("cardPadding", default: 18)
        let baseSize = baseFontSize + cardPadding * 2
        let gap = baseSize * 0.08
        let center = point(
            x: config.number("x", default: 0.5),
            y: config.number("y", default: 0.5),
            in: size
        )
        let cardColor = color("cardColor", in: config, default: "#ffffff")
        let textColor = color("textColor", in: config, default: "#1a1a1a")
        let glowColor = color("glowColor", in: config, default: "#ffffff")
        let glowAlpha = config.number("glowAlpha", default: 0.6)
        let staggerX = config.number("staggerX", default: 12)
        let staggerY = config.number("staggerY", default: 8)
        let delayStep = config.number("staggerDelay", default: 0.06)
        let family = config.string("fontFamily", default: "Noto Serif JP")

        for (index, character) in characters.enumerated() {
            let row = index / charsPerRow
            let column = index % charsPerRow
            let rowColumnCount = min(charsPerRow, characters.count - row * charsPerRow)
            let gridWidth = CGFloat(rowColumnCount) * (baseSize + gap)
            let gridHeight = CGFloat(rowCount) * (baseSize + gap)
            let target = CGPoint(
                x: center.x - gridWidth / 2 + (baseSize + gap) / 2
                    + CGFloat(column) * (baseSize + gap)
                    + sin(CGFloat(index) * 1.3) * staggerX,
                y: center.y - gridHeight / 2 + (baseSize + gap) / 2
                    + CGFloat(row) * (baseSize + gap)
                    + cos(CGFloat(index) * 1.7) * staggerY
            )
            let elapsed = (frame.segmentTime - CGFloat(index) * delayStep) * frame.animationSpeed
            guard elapsed >= 0 else { continue }
            let progress = min(elapsed * 3, 1)
            let ease = 1 - pow(1 - progress, 3)
            let overshoot = progress < 1 ? 1 + sin(progress * .pi) * 0.05 : 1
            let sizeFactor = 1 + sin(CGFloat(index) * 2.7 + 0.5) * sizeVariance
            let textScale = ease * overshoot
            guard textScale > 0 else { continue }
            let fontSize = baseFontSize * sizeFactor * textScale
            let cardSize = (baseFontSize * sizeFactor + cardPadding * 2) * textScale
            let drift = frame.motionIntensity * 2
            let animatedCenter = CGPoint(
                x: target.x + sin(frame.time * 0.3 + CGFloat(index) * delayStep * 10) * drift,
                y: target.y + cos(frame.time * 0.25 + CGFloat(index) * delayStep * 8) * drift
            )
            context.fill(
                Path(roundedRect: CGRect(
                    x: animatedCenter.x - cardSize * 0.75,
                    y: animatedCenter.y - cardSize * 0.75,
                    width: cardSize * 1.5,
                    height: cardSize * 1.5
                ), cornerRadius: 3),
                with: .radialGradient(
                    Gradient(colors: [glowColor.opacity(glowAlpha), .clear]),
                    center: animatedCenter,
                    startRadius: cardSize * 0.25,
                    endRadius: cardSize * 0.75
                )
            )
            context.fill(
                Path(CGRect(
                    x: animatedCenter.x - cardSize / 2,
                    y: animatedCenter.y - cardSize / 2,
                    width: cardSize,
                    height: cardSize
                )),
                with: .color(cardColor.opacity(min(ease * 1.2, 1)))
            )
            let symbolID = TextPVCanvasSymbolID(
                effectIndex: effectIndex,
                itemIndex: index
            )
            if let symbol = context.resolveSymbol(id: symbolID) {
                var symbolContext = context
                symbolContext.translateBy(
                    x: animatedCenter.x,
                    y: animatedCenter.y
                )
                symbolContext.scaleBy(x: textScale, y: textScale)
                symbolContext.opacity = Double(min(ease * 1.2, 1))
                symbolContext.draw(symbol, at: .zero, anchor: .center)
            } else {
                drawText(
                    String(character),
                    in: &context,
                    at: animatedCenter,
                    color: textColor,
                    size: fontSize,
                    family: family,
                    opacity: min(ease * 1.2, 1)
                )
            }
        }
    }

    func drawFormulaText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let formulas = TextPVTextResources.formulae
        let singleCharacters = TextPVTextResources.formulaGlyphs
        let count = max(config.integer("count", default: 18), 1)
        let formulaRatio = config.number("formulaRatio", default: 0.65)
        let fill = color("color", in: config, default: "$text")
        let configuredAlpha = config.number("alpha", default: 1)
        for index in 0..<count {
            let isFormula = random(index * 6) < formulaRatio
            let text = isFormula
                ? formulas[Int(random(index * 6 + 1) * CGFloat(formulas.count - 1))]
                : String(singleCharacters[Int(random(index * 6 + 1) * CGFloat(singleCharacters.count - 1))])
            let fontSize = isFormula
                ? 11 + random(index * 6 + 2) * 5
                : 24 + random(index * 6 + 2) * 36
            let position = CGPoint(
                x: -80 + random(index * 6 + 3) * (size.width + 100),
                y: 20 + random(index * 6 + 4) * max(size.height - 40, 1)
            )
            let baseAlpha = (0.4 + random(index * 6 + 5) * 0.5) * configuredAlpha
            let opacity = baseAlpha + sin(frame.time * 0.2 * frame.animationSpeed + random(index + 90) * 2 * .pi) * 0.06
            drawText(
                text,
                in: &context,
                at: position,
                color: fill,
                size: fontSize,
                family: "SF Mono",
                weight: isFormula ? .regular : .bold,
                anchor: .leading,
                opacity: opacity
            )
        }
    }

    func drawFallingText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let pool = frame.visibleCharacters
        guard !pool.isEmpty else { return }
        let count = max(config.integer("count", default: 30), 1)
        let minSize = config.number("minSize", default: 28)
        let maxSize = config.number("maxSize", default: 72)
        let fill = color("color", in: config, default: "$accent")
        let family = config.string("fontFamily", default: "Noto Serif JP")
        for index in 0..<count {
            let fontSize = minSize + random(index * 8 + 1) * (maxSize - minSize)
            let speed = 60 + random(index * 8 + 2) * 120
            let startY = -fontSize - random(index * 8 + 3) * (size.height + fontSize * 2)
            let y = (startY + frame.time * speed * frame.animationSpeed
                * (1 + frame.beatIntensity * 0.6))
                .truncatingRemainder(dividingBy: size.height + fontSize * 3)
                - fontSize
            guard y >= -fontSize * 1.5,
                  y <= size.height + fontSize * 1.5 else {
                continue
            }
            let rotation = signedRandom(index * 8 + 4) * 0.5
                + frame.time * signedRandom(index * 8 + 5) * 3
                    * frame.animationSpeed * frame.motionIntensity
            let flip = cos(frame.time * (1.5 + random(index * 8 + 6) * 3)
                + random(index * 8 + 7) * 2 * .pi)
            let position = CGPoint(x: random(index * 8) * size.width, y: y)
            let symbolID = TextPVCanvasSymbolID(
                effectIndex: effectIndex,
                itemIndex: index
            )

            if let symbol = context.resolveSymbol(id: symbolID) {
                var symbolContext = context
                symbolContext.translateBy(x: position.x, y: position.y)
                symbolContext.rotate(by: .radians(Double(rotation)))
                symbolContext.scaleBy(x: max(abs(flip), 0.1), y: 1)
                symbolContext.draw(symbol, at: .zero, anchor: .center)
            } else {
                drawText(
                    String(pool[Int(random(index) * CGFloat(pool.count - 1))]),
                    in: &context,
                    at: position,
                    color: fill,
                    size: fontSize * max(abs(flip), 0.1),
                    family: family,
                    rotation: rotation
                )
            }
        }
    }

    func drawScatteredText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let pool = config["chars"]?.stringValue.map(Array.init)
            ?? frame.normalizedCharacters
        guard !pool.isEmpty else { return }
        let count = max(config.integer("count", default: 15), 1)
        let minSize = config.number("minSize", default: 20)
        let maxSize = config.number("maxSize", default: 60)
        let fill = color("color", in: config, default: "$secondary")
        for index in 0..<count {
            let opacity = 0.25 + random(index + 80) * 0.5
                + sin(frame.time * (0.2 + random(index + 90) * 0.4)
                    + random(index + 100) * 2 * .pi) * 0.12
            drawText(
                String(pool[Int(random(index) * CGFloat(pool.count - 1))]),
                in: &context,
                at: CGPoint(
                    x: random(index * 3 + 1) * size.width,
                    y: random(index * 3 + 2) * size.height
                ),
                color: fill,
                size: minSize + random(index + 50) * (maxSize - minSize),
                family: config.string("fontFamily", default: "Noto Serif JP"),
                rotation: signedRandom(index + 70) * 0.3,
                opacity: opacity
            )
        }
    }

    func drawVerticalSubText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let characters = frame.previousCharacters
        guard !characters.isEmpty else { return }
        let fontSize = config.number("fontSize", default: 14)
        let charsPerColumn = max(config.integer("charsPerCol", default: 5), 1)
        let x = size.width * config.number("x", default: 0.62)
        let y = size.height * config.number("y", default: 0.35)
        let lineHeight = fontSize * 1.4
        let columnGap = fontSize * 1.6
        let fill = color("color", in: config, default: "#ffffff")
        let opacity = 0.7 + sin(frame.time * 0.5) * 0.1
        for (index, character) in characters.enumerated() {
            let column = index / charsPerColumn
            let row = index % charsPerColumn
            drawText(
                String(character),
                in: &context,
                at: CGPoint(
                    x: x - CGFloat(column) * columnGap,
                    y: y + CGFloat(row) * lineHeight
                ),
                color: fill,
                size: fontSize,
                family: config.string("fontFamily", default: "Noto Serif JP"),
                opacity: opacity
            )
        }
    }
}
