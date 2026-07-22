// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Native Canvas symbol caching added under the PV Tool Non-Commercial License.

import SwiftUI

struct TextPVCanvasSymbolID: Hashable {
    let effectIndex: Int
    let itemIndex: Int
}

struct TextPVCanvasTextSymbol: Identifiable, Equatable {
    let id: TextPVCanvasSymbolID
    let character: Character
    let color: Color
    let fontSize: CGFloat
    let fontFamily: String
}

enum TextPVCanvasSymbolFactory {
    static func makeSymbols(
        template: TextPVTemplate,
        visibleCharacters: [Character],
        seed: UInt64
    ) -> [TextPVCanvasTextSymbol] {
        guard !visibleCharacters.isEmpty else { return [] }

        return template.effects.enumerated().flatMap {
            (effectIndex, effect) -> [TextPVCanvasTextSymbol] in
            switch effect.kind {
            case .fallingText:
                makeFallingTextSymbols(
                    effect: effect,
                    effectIndex: effectIndex,
                    template: template,
                    visibleCharacters: visibleCharacters,
                    seed: seed
                )
            case .glowTextCards:
                makeGlowTextCardSymbols(
                    effect: effect,
                    effectIndex: effectIndex,
                    template: template,
                    visibleCharacters: visibleCharacters
                )
            default:
                []
            }
        }
    }

    private static func makeFallingTextSymbols(
        effect: TextPVEffect,
        effectIndex: Int,
        template: TextPVTemplate,
        visibleCharacters: [Character],
        seed: UInt64
    ) -> [TextPVCanvasTextSymbol] {
        let effectSeed = seed
            &+ UInt64(effectIndex) &* 0xD1B54A32D192ED03
        let count = max(effect.config.integer("count", default: 30), 1)
        let minimumSize = effect.config.number("minSize", default: 28)
        let maximumSize = effect.config.number("maxSize", default: 72)
        let family = effect.config.string(
            "fontFamily",
            default: "Noto Serif JP"
        )
        let colorToken = effect.config.string("color", default: "$accent")
        let color = template.palette.resolve(colorToken, fallback: "$accent")

        return (0..<count).map { index in
            let fontSize = minimumSize
                + TextPVSeed.unit(effectSeed, index * 8 + 1)
                * (maximumSize - minimumSize)
            let characterIndex = Int(
                TextPVSeed.unit(effectSeed, index)
                    * CGFloat(visibleCharacters.count - 1)
            )

            return TextPVCanvasTextSymbol(
                id: TextPVCanvasSymbolID(
                    effectIndex: effectIndex,
                    itemIndex: index
                ),
                character: visibleCharacters[characterIndex],
                color: color,
                fontSize: fontSize,
                fontFamily: family
            )
        }
    }

    private static func makeGlowTextCardSymbols(
        effect: TextPVEffect,
        effectIndex: Int,
        template: TextPVTemplate,
        visibleCharacters: [Character]
    ) -> [TextPVCanvasTextSymbol] {
        let baseFontSize = effect.config.number("fontSize", default: 70)
        let sizeVariance = effect.config.number("sizeVariance", default: 0.3)
        let family = effect.config.string(
            "fontFamily",
            default: "Noto Serif JP"
        )
        let colorToken = effect.config.string(
            "textColor",
            default: "#1a1a1a"
        )
        let color = template.palette.resolve(colorToken, fallback: "#1a1a1a")

        return visibleCharacters.enumerated().map { index, character in
            let sizeFactor = 1
                + sin(CGFloat(index) * 2.7 + 0.5) * sizeVariance
            return TextPVCanvasTextSymbol(
                id: TextPVCanvasSymbolID(
                    effectIndex: effectIndex,
                    itemIndex: index
                ),
                character: character,
                color: color,
                fontSize: baseFontSize * sizeFactor,
                fontFamily: family
            )
        }
    }
}

struct TextPVCanvasSymbols: View, Equatable {
    let symbols: [TextPVCanvasTextSymbol]

    var body: some View {
        ForEach(symbols) { symbol in
            TextPVCanvasTextSymbolView(symbol: symbol)
                .tag(symbol.id)
        }
    }
}

private struct TextPVCanvasTextSymbolView: View {
    let symbol: TextPVCanvasTextSymbol

    var body: some View {
        glyph
            .foregroundStyle(symbol.color)
            .padding(1)
    }

    private var glyph: Text {
        Text(verbatim: String(symbol.character))
            .font(
                TextPVFontFactory.font(
                    size: symbol.fontSize,
                    family: symbol.fontFamily,
                    weight: .bold
                )
            )
    }
}
