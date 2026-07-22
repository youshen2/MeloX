import CoreGraphics
import Foundation

extension EVALyricLayoutEngine {
    static func cornerComposition(
        characters: [Character]
    ) -> EVALyricComposition {
        let parts = titleParts(from: characters)
        let trailing = Array(parts.trailing)
        let bend = max(trailing.count / 2, trailing.count > 1 ? 1 : 0)
        let upperTrailing = cleanedText(trailing[..<bend])
        let lowerTrailing = cleanedText(trailing[bend...])

        var blocks: [EVALyricTextBlock] = [
            EVALyricTextBlock(
                id: "corner-leading",
                text: parts.leading,
                frame: CGRect(x: 0.01, y: 0.04, width: 0.49, height: 0.46),
                flow: .horizontal,
                alignment: .leading,
                sizeScale: 1,
                widthScale: 0.9
            ),
            punctuationBlock(
                id: "corner-punctuation",
                frame: CGRect(x: 0.39, y: 0.18, width: 0.18, height: 0.3)
            )
        ]

        if !upperTrailing.isEmpty {
            blocks.append(
                EVALyricTextBlock(
                    id: "corner-upper-trailing",
                    text: upperTrailing,
                    frame: CGRect(x: 0.54, y: 0.03, width: 0.43, height: 0.43),
                    flow: .horizontal,
                    alignment: .trailing,
                    sizeScale: 1.02,
                    widthScale: 0.9
                )
            )
        }
        if !lowerTrailing.isEmpty {
            blocks.append(
                EVALyricTextBlock(
                    id: "corner-lower-trailing",
                    text: lowerTrailing,
                    frame: CGRect(x: 0.72, y: 0.39, width: 0.25, height: 0.58),
                    flow: .vertical,
                    alignment: .trailing,
                    sizeScale: 1,
                    widthScale: 0.92
                )
            )
        }
        return EVALyricComposition(blocks: blocks)
    }

    static func verticalLeadComposition(
        characters: [Character]
    ) -> EVALyricComposition {
        let parts = titleParts(from: characters)
        return EVALyricComposition(
            blocks: [
                EVALyricTextBlock(
                    id: "vertical-lead",
                    text: parts.leading,
                    frame: CGRect(x: 0.03, y: 0.05, width: 0.27, height: 0.88),
                    flow: .vertical,
                    alignment: .leading,
                    sizeScale: 1,
                    widthScale: 0.92
                ),
                punctuationBlock(
                    id: "vertical-lead-punctuation",
                    frame: CGRect(x: 0.22, y: 0.5, width: 0.2, height: 0.31)
                ),
                EVALyricTextBlock(
                    id: "vertical-lead-trailing",
                    text: parts.trailing,
                    frame: CGRect(x: 0.34, y: 0.52, width: 0.62, height: 0.4),
                    flow: .horizontal,
                    alignment: .trailing,
                    sizeScale: 1.04,
                    widthScale: 0.86
                )
            ]
        )
    }

    static func horizontalLeadComposition(
        characters: [Character]
    ) -> EVALyricComposition {
        let parts = titleParts(from: characters)
        return EVALyricComposition(
            blocks: [
                EVALyricTextBlock(
                    id: "horizontal-lead",
                    text: parts.leading,
                    frame: CGRect(x: 0.02, y: 0.06, width: 0.66, height: 0.42),
                    flow: .horizontal,
                    alignment: .leading,
                    sizeScale: 1.02,
                    widthScale: 0.88
                ),
                punctuationBlock(
                    id: "horizontal-lead-punctuation",
                    frame: CGRect(x: 0.51, y: 0.12, width: 0.19, height: 0.3)
                ),
                EVALyricTextBlock(
                    id: "horizontal-lead-trailing",
                    text: parts.trailing,
                    frame: CGRect(x: 0.7, y: 0.07, width: 0.27, height: 0.88),
                    flow: .vertical,
                    alignment: .trailing,
                    sizeScale: 1,
                    widthScale: 0.9
                )
            ]
        )
    }

    static func offsetComposition(
        characters: [Character]
    ) -> EVALyricComposition {
        let split = min(
            max(Int((Double(characters.count) * 0.78).rounded()), 1),
            characters.count - 1
        )
        let upper = cleanedText(characters[..<split])
        let lower = cleanedText(characters[split...])

        return EVALyricComposition(
            blocks: [
                EVALyricTextBlock(
                    id: "offset-upper",
                    text: upper.isEmpty ? String(characters.prefix(1)) : upper,
                    frame: CGRect(x: 0.06, y: 0.06, width: 0.88, height: 0.44),
                    flow: .horizontal,
                    alignment: .leading,
                    sizeScale: 1,
                    widthScale: 0.82
                ),
                EVALyricTextBlock(
                    id: "offset-lower",
                    text: lower.isEmpty ? String(characters.suffix(1)) : lower,
                    frame: CGRect(x: 0.08, y: 0.56, width: 0.52, height: 0.36),
                    flow: .horizontal,
                    alignment: .leading,
                    sizeScale: 1.08,
                    widthScale: 0.9
                )
            ]
        )
    }

    static func centeredVerticalComposition(text: String) -> EVALyricComposition {
        EVALyricComposition(
            blocks: [
                EVALyricTextBlock(
                    id: "centered-vertical",
                    text: text,
                    frame: CGRect(x: 0.36, y: 0.03, width: 0.28, height: 0.94),
                    flow: .vertical,
                    alignment: .center,
                    sizeScale: 1,
                    widthScale: 0.94
                )
            ]
        )
    }

    static func soloComposition(
        text: String,
        variant: Int
    ) -> EVALyricComposition {
        let origins: [(x: CGFloat, alignment: EVALyricTextBlock.Alignment)] = [
            (0.04, .leading),
            (0.31, .center),
            (0.58, .trailing)
        ]
        let origin = origins[variant]
        return EVALyricComposition(
            blocks: [
                EVALyricTextBlock(
                    id: "solo",
                    text: text,
                    frame: CGRect(x: origin.x, y: 0.03, width: 0.38, height: 0.88),
                    flow: .horizontal,
                    alignment: origin.alignment,
                    sizeScale: 1,
                    widthScale: 0.86
                )
            ]
        )
    }

    private static func punctuationBlock(
        id: String,
        frame: CGRect
    ) -> EVALyricTextBlock {
        EVALyricTextBlock(
            id: id,
            text: "、",
            frame: frame,
            flow: .horizontal,
            alignment: .center,
            sizeScale: 0.88,
            widthScale: 0.7
        )
    }
}
