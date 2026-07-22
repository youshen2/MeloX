import CoreGraphics
import Foundation

extension EVALyricLayoutEngine {
    static func stackedComposition(
        characters: [Character]
    ) -> EVALyricComposition {
        let targetRows = min(max(Int(ceil(Double(characters.count) / 6)), 2), 5)
        let chunkLength = Int(ceil(Double(characters.count) / Double(targetRows)))
        let chunks = stride(from: 0, to: characters.count, by: chunkLength).map { start in
            String(characters[start..<min(start + chunkLength, characters.count)])
        }
        let rowHeight = 0.88 / CGFloat(chunks.count)

        let blocks = chunks.enumerated().map { index, text in
            let isIndented = index.isMultiple(of: 3) == false
            let isTrailing = index.isMultiple(of: 2) == false
            return EVALyricTextBlock(
                id: "stacked-\(index)",
                text: text,
                frame: CGRect(
                    x: isIndented ? 0.11 : 0.04,
                    y: 0.04 + CGFloat(index) * rowHeight * 0.94,
                    width: isIndented ? 0.84 : 0.91,
                    height: rowHeight * 1.08
                ),
                flow: .horizontal,
                alignment: isTrailing ? .trailing : .leading,
                sizeScale: index == chunks.count - 1 ? 1.05 : 1,
                widthScale: isTrailing ? 0.82 : 0.9
            )
        }
        return EVALyricComposition(blocks: blocks)
    }

    static func bandedComposition(
        characters: [Character]
    ) -> EVALyricComposition {
        let middle = Int(ceil(Double(characters.count) / 2))
        let upper = Array(characters[..<middle])
        let lower = Array(characters[middle...])
        var blocks = bandBlocks(characters: upper, prefix: "upper", y: 0.03)
        blocks.append(
            contentsOf: bandBlocks(
                characters: lower,
                prefix: "lower",
                y: 0.52
            )
        )
        return EVALyricComposition(blocks: blocks)
    }

    static func columnComposition(
        characters: [Character]
    ) -> EVALyricComposition {
        let columnCount = min(max(Int(ceil(Double(characters.count) / 7)), 2), 4)
        let chunkLength = Int(ceil(Double(characters.count) / Double(columnCount)))
        let columns = stride(from: 0, to: characters.count, by: chunkLength).map { start in
            String(characters[start..<min(start + chunkLength, characters.count)])
        }
        let columnWidth = 0.82 / CGFloat(columns.count)

        let blocks = columns.enumerated().map { index, text in
            let reversedIndex = columns.count - index - 1
            return EVALyricTextBlock(
                id: "column-\(index)",
                text: text,
                frame: CGRect(
                    x: 0.09 + CGFloat(reversedIndex) * columnWidth,
                    y: index.isMultiple(of: 2) ? 0.04 : 0.13,
                    width: columnWidth * 0.78,
                    height: index.isMultiple(of: 2) ? 0.9 : 0.8
                ),
                flow: .vertical,
                alignment: .center,
                sizeScale: 1,
                widthScale: index.isMultiple(of: 2) ? 0.94 : 0.84
            )
        }
        return EVALyricComposition(blocks: blocks)
    }

    private static func bandBlocks(
        characters: [Character],
        prefix: String,
        y: CGFloat
    ) -> [EVALyricTextBlock] {
        guard let first = characters.first else { return [] }
        let remainder = String(characters.dropFirst())
        var blocks = [
            EVALyricTextBlock(
                id: "band-\(prefix)-initial",
                text: String(first),
                frame: CGRect(x: 0.03, y: y, width: 0.3, height: 0.4),
                flow: .horizontal,
                alignment: .leading,
                sizeScale: 1,
                widthScale: 0.84
            )
        ]
        if !remainder.isEmpty {
            blocks.append(
                EVALyricTextBlock(
                    id: "band-\(prefix)-remainder",
                    text: remainder,
                    frame: CGRect(x: 0.29, y: y + 0.08, width: 0.67, height: 0.29),
                    flow: .horizontal,
                    alignment: .trailing,
                    sizeScale: 1,
                    widthScale: 0.82
                )
            )
        }
        return blocks
    }
}
