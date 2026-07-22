// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

private enum TextPVStaggeredMode: Int, CaseIterable {
    case diagonalLeft
    case diagonalRight
    case verticalCenter
    case verticalFramed
    case horizontalWide
}

private struct TextPVCharacterSlot {
    let character: Character
    let position: CGPoint
    let fontSize: CGFloat
    let rotation: CGFloat
}

extension TextPVEffectPainter {
    func drawStaggeredText(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let characters = frame.visibleCharacters
        guard !characters.isEmpty else { return }
        let modeDuration = config.number("modeDuration", default: 3)
        let transition = config.number("transition", default: 0.4)
        let modeIndex = Int(floor(frame.segmentTime / modeDuration))
            % TextPVStaggeredMode.allCases.count
        let mode = TextPVStaggeredMode.allCases[modeIndex]
        let elapsed = frame.segmentTime.truncatingRemainder(dividingBy: modeDuration)
        let fadeIn = min(1, elapsed / transition)
        let fadeOut = min(1, (modeDuration - elapsed) / transition)
        let alpha = min(fadeIn, fadeOut)
        let slots = staggeredSlots(
            characters: characters,
            mode: mode,
            fontSize: config.number("fontSize", default: 64),
            columnCharacters: config.integer("colChars", default: 5),
            size: size
        )

        if mode == .verticalFramed, let bounds = slotBounds(slots) {
            let padding = config.number("framePadding", default: 30)
            context.stroke(
                Path(bounds.insetBy(dx: -padding, dy: -padding)),
                with: .color(color("frameColor", in: config, default: "#ffffff")
                    .opacity(config.number("frameAlpha", default: 0.6) * alpha)),
                lineWidth: 1.5
            )
        }

        for (index, slot) in slots.enumerated() {
            let characterDelay = CGFloat(index) * 0.04
            let characterAlpha = max(0, min(1,
                (elapsed - characterDelay) * frame.animationSpeed * 3
            ))
            let drift = frame.motionIntensity * 1.5
            drawText(
                String(slot.character),
                in: &context,
                at: CGPoint(
                    x: slot.position.x + sin(frame.time * 0.4 + CGFloat(index) * 1.3) * drift,
                    y: slot.position.y + cos(frame.time * 0.35 + CGFloat(index) * 0.9) * drift
                ),
                color: color("color", in: config, default: "#ffffff"),
                size: slot.fontSize,
                family: config.string("fontFamily", default: "Noto Serif JP"),
                rotation: slot.rotation,
                opacity: alpha * characterAlpha
            )
        }
    }

    func drawCrayonShatter(
        _ config: TextPVEffectConfig,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let characters = frame.visibleCharacters
        guard !characters.isEmpty else { return }
        let baseFontSize = config.number("fontSize", default: 115)
        let spacing = baseFontSize * config.number("charSpacingFrac", default: 1.05)
        let columns = max(Int(size.width * 0.82 / max(spacing, 1)), 1)
        let rows = Int(ceil(Double(characters.count) / Double(columns)))
        let columnSpacing = baseFontSize * config.number("colSpacingFrac", default: 1.4)
        let totalWidth = CGFloat(min(columns, characters.count) - 1) * spacing
        let totalHeight = CGFloat(max(rows - 1, 0)) * columnSpacing
        let start = CGPoint(
            x: size.width / 2 - totalWidth / 2,
            y: size.height / 2 - totalHeight / 2
        )
        let paletteColors = config.array("colors").compactMap(\.stringValue)
        let baseColor = color("baseColor", in: config, default: "$text")
        let replaceProbability = config.number("replaceProb", default: 0.55)
        let offsetProbability = config.number("offsetProb", default: 0.55)
        let rotationProbability = config.number("rotateProb", default: 0.55)
        let maxOffset = config.number("maxOffsetPx", default: 5)
        let maxRotation = config.number("maxRotateDeg", default: 14) * .pi / 180
        let frameHold = max(config.number("frameHoldSec", default: 0.18), 0.04)
        let frameCount = max(config.integer("frameCount", default: 4), 1)
        let animationFrame = Int(frame.time / frameHold) % frameCount

        for (index, character) in characters.enumerated() {
            let column = index % columns
            let row = index / columns
            let localSeed = seed &+ UInt64(index * 97 + animationFrame * 7919)
            let phaseOffset = sin(CGFloat(column) * config.number("colRowPhase", default: 0.45)) * 8
            let jitter = config.number("layoutJitter", default: 0.06) * baseFontSize
            let position = CGPoint(
                x: start.x + CGFloat(column) * spacing
                    + TextPVSeed.signed(localSeed, 1) * jitter
                    + (TextPVSeed.unit(localSeed, 2) < offsetProbability
                        ? TextPVSeed.signed(localSeed, 3) * maxOffset
                        : 0),
                y: start.y + CGFloat(row) * columnSpacing + phaseOffset
                    + TextPVSeed.signed(localSeed, 4) * jitter
                    + (TextPVSeed.unit(localSeed, 5) < offsetProbability
                        ? TextPVSeed.signed(localSeed, 6) * maxOffset
                        : 0)
            )
            let selectedColor: Color
            if !paletteColors.isEmpty,
               TextPVSeed.unit(localSeed, 7) < replaceProbability {
                let colorIndex = Int(TextPVSeed.unit(localSeed, 8) * CGFloat(paletteColors.count - 1))
                selectedColor = palette.resolve(paletteColors[colorIndex])
            } else {
                selectedColor = baseColor
            }
            let rotation = TextPVSeed.unit(localSeed, 9) < rotationProbability
                ? TextPVSeed.signed(localSeed, 10) * maxRotation
                : 0
            let swing = TextPVSeed.unit(localSeed, 11) < config.number("swingProb", default: 0.15)
                ? sin(frame.animatedTime * 2 + CGFloat(index)) * maxRotation * 0.4
                : 0
            let outlineWidth = config.number("outlineLineWidth", default: 1.5)
            drawText(
                String(character),
                in: &context,
                at: position,
                color: selectedColor,
                size: baseFontSize,
                family: config.string("fontFamily", default: "Yu Gothic"),
                rotation: rotation + swing,
                strokeColor: baseColor.opacity(0.7),
                strokeWidth: outlineWidth
            )

            let fragmentCount = 5
            for fragment in 0..<fragmentCount {
                let fragmentAngle = TextPVSeed.unit(localSeed, 20 + fragment) * 2 * .pi
                let distance = 6 + TextPVSeed.unit(localSeed, 30 + fragment) * baseFontSize * 0.25
                let fragmentSize = 2 + TextPVSeed.unit(localSeed, 40 + fragment) * 7
                let fragmentCenter = CGPoint(
                    x: position.x + cos(fragmentAngle) * distance,
                    y: position.y + sin(fragmentAngle) * distance
                )
                context.fill(
                    rotatedRectangle(
                        center: fragmentCenter,
                        width: fragmentSize * 2.2,
                        height: fragmentSize * 0.7,
                        rotation: fragmentAngle
                    ),
                    with: .color(selectedColor.opacity(0.72))
                )
            }
        }
    }

    private func staggeredSlots(
        characters: [Character],
        mode: TextPVStaggeredMode,
        fontSize: CGFloat,
        columnCharacters: Int,
        size: CGSize
    ) -> [TextPVCharacterSlot] {
        switch mode {
        case .diagonalLeft, .diagonalRight:
            let isLeft = mode == .diagonalLeft
            let startX = size.width * (isLeft ? 0.12 : 0.88)
            let stepX = fontSize * 0.4 * (isLeft ? 1 : -1)
            return characters.enumerated().map { index, character in
                let i = CGFloat(index)
                let sizeVariation = 0.7
                    + (isLeft ? sin(i * 2.3) : cos(i * 2.3)) * 0.4
                let jitterX = (isLeft ? sin(i * 3.7) : cos(i * 3.7)) * fontSize * 0.3
                let jitterY = (isLeft ? cos(i * 2.1) : sin(i * 2.1)) * fontSize * 0.15
                return TextPVCharacterSlot(
                    character: character,
                    position: CGPoint(
                        x: startX + i * stepX + jitterX,
                        y: size.height * 0.15 + i * fontSize * 1.3 + jitterY
                    ),
                    fontSize: fontSize * sizeVariation,
                    rotation: (isLeft ? -0.15 : 0.15)
                        + (isLeft ? sin(i * 1.7) : cos(i * 1.7)) * 0.1
                )
            }
        case .verticalCenter, .verticalFramed:
            let perColumn = max(columnCharacters, 1)
            let columns = Int(ceil(Double(characters.count) / Double(perColumn)))
            let gap = fontSize * 1.4
            let columnGap = fontSize * 1.3
            let totalWidth = CGFloat(columns - 1) * columnGap
            let totalHeight = CGFloat(min(characters.count, perColumn) - 1) * gap
            let origin = CGPoint(
                x: size.width / 2 + totalWidth / 2,
                y: size.height / 2 - totalHeight / 2
            )
            return characters.enumerated().map { index, character in
                TextPVCharacterSlot(
                    character: character,
                    position: CGPoint(
                        x: origin.x - CGFloat(index / perColumn) * columnGap,
                        y: origin.y + CGFloat(index % perColumn) * gap
                    ),
                    fontSize: fontSize,
                    rotation: 0
                )
            }
        case .horizontalWide:
            let spacing = fontSize * 2.2
            let startX = (size.width - CGFloat(characters.count - 1) * spacing) / 2
            return characters.enumerated().map { index, character in
                TextPVCharacterSlot(
                    character: character,
                    position: CGPoint(
                        x: startX + CGFloat(index) * spacing,
                        y: size.height / 2
                    ),
                    fontSize: fontSize * 0.95,
                    rotation: 0
                )
            }
        }
    }

    private func slotBounds(_ slots: [TextPVCharacterSlot]) -> CGRect? {
        guard let first = slots.first else { return nil }
        return slots.dropFirst().reduce(
            CGRect(
                x: first.position.x - first.fontSize / 2,
                y: first.position.y - first.fontSize / 2,
                width: first.fontSize,
                height: first.fontSize
            )
        ) { bounds, slot in
            bounds.union(CGRect(
                x: slot.position.x - slot.fontSize / 2,
                y: slot.position.y - slot.fontSize / 2,
                width: slot.fontSize,
                height: slot.fontSize
            ))
        }
    }
}
