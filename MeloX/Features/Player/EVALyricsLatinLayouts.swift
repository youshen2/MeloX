import CoreGraphics
import Foundation

extension EVALyricLayoutEngine {
    static func latinComposition(text: String) -> EVALyricComposition {
        let lines = latinLines(from: text)
        let rowHeight = 0.88 / CGFloat(lines.count)
        let blocks = lines.enumerated().map { index, line in
            EVALyricTextBlock(
                id: "latin-\(index)",
                text: line.uppercased(),
                frame: CGRect(
                    x: index.isMultiple(of: 2) ? 0.03 : 0.12,
                    y: 0.05 + CGFloat(index) * rowHeight * 0.96,
                    width: index.isMultiple(of: 2) ? 0.92 : 0.83,
                    height: rowHeight * 1.08
                ),
                flow: .horizontal,
                alignment: index.isMultiple(of: 2) ? .leading : .trailing,
                sizeScale: index == 0 ? 1 : 0.88,
                widthScale: index.isMultiple(of: 2) ? 0.84 : 0.74
            )
        }
        return EVALyricComposition(blocks: blocks)
    }

    static func centeredLatinComposition(text: String) -> EVALyricComposition {
        let lines = latinLines(from: text)
        let rowHeight = 0.84 / CGFloat(lines.count)
        let blocks = lines.enumerated().map { index, line in
            EVALyricTextBlock(
                id: "latin-centered-\(index)",
                text: line.uppercased(),
                frame: CGRect(
                    x: index.isMultiple(of: 2) ? 0.1 : 0.18,
                    y: 0.08 + CGFloat(index) * rowHeight * 0.96,
                    width: index.isMultiple(of: 2) ? 0.8 : 0.64,
                    height: rowHeight * 1.06
                ),
                flow: .horizontal,
                alignment: .center,
                sizeScale: index == lines.count - 1 ? 1.05 : 1,
                widthScale: index.isMultiple(of: 2) ? 0.78 : 0.9
            )
        }
        return EVALyricComposition(blocks: blocks)
    }

    static func latinPosterComposition(text: String) -> EVALyricComposition {
        let lines = latinLines(from: text)
        guard let headline = lines.first else {
            return soloComposition(text: text, variant: 1)
        }

        var blocks = [
            EVALyricTextBlock(
                id: "latin-poster-headline",
                text: headline.uppercased(),
                frame: CGRect(x: 0.03, y: 0.05, width: 0.94, height: 0.48),
                flow: .horizontal,
                alignment: .leading,
                sizeScale: 1,
                widthScale: 0.76
            )
        ]
        let remainingLines = Array(lines.dropFirst())
        let remainingHeight = 0.4 / CGFloat(max(remainingLines.count, 1))
        blocks.append(
            contentsOf: remainingLines.enumerated().map { index, line in
                EVALyricTextBlock(
                    id: "latin-poster-support-\(index)",
                    text: line.uppercased(),
                    frame: CGRect(
                        x: index.isMultiple(of: 2) ? 0.12 : 0.26,
                        y: 0.55 + CGFloat(index) * remainingHeight,
                        width: index.isMultiple(of: 2) ? 0.82 : 0.7,
                        height: remainingHeight * 1.04
                    ),
                    flow: .horizontal,
                    alignment: .trailing,
                    sizeScale: 0.9,
                    widthScale: 0.82
                )
            }
        )
        return EVALyricComposition(blocks: blocks)
    }

    private static func latinLines(from text: String) -> [String] {
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard words.count > 1 else {
            return chunks(of: Array(text), maximumCount: 10)
        }

        let targetLength = max(Int(ceil(Double(text.count) / 3)), 6)
        var lines: [String] = []
        var current = ""

        for word in words {
            let candidate = current.isEmpty ? word : "\(current) \(word)"
            if candidate.count > targetLength, !current.isEmpty {
                lines.append(current)
                current = word
            } else {
                current = candidate
            }
        }
        if !current.isEmpty {
            lines.append(current)
        }
        return lines
    }

    private static func chunks(
        of characters: [Character],
        maximumCount: Int
    ) -> [String] {
        stride(from: 0, to: characters.count, by: maximumCount).map { start in
            String(characters[start..<min(start + maximumCount, characters.count)])
        }
    }
}
