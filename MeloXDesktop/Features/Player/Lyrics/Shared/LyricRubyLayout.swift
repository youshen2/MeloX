import AppKit
import SwiftUI

nonisolated struct LyricRubyPlacementTextAttribute:
    TextAttribute,
    Hashable,
    Sendable
{
    let horizontalOffset: CGFloat
}

struct LyricRubyRow: Identifiable {
    let id: Int
    let width: CGFloat
    let originalText: Text
    let romanizationText: Text
    let plainOriginalText: String
    let originalTrailingVisualOverflow: CGFloat
    let romanizationTrailingVisualOverflow: CGFloat
}

struct LyricRubyPlacementUnit {
    let lyric: LyricRubyUnit
    let originalOffset: CGFloat
    let romanizationOffset: CGFloat
}

@MainActor
enum LyricRubyLayoutPlanner {
    private static let cache = LyricRubyLayoutCache()
    private static let glyphWidthCache =
        LyricRubyGlyphWidthCache()

    static func rows(
        for units: [LyricRubyUnit],
        fontSize: CGFloat,
        romanizationFontSize: CGFloat,
        fontWeight: LyricsFontWeight,
        availableWidth: CGFloat?
    ) -> [LyricRubyRow] {
        guard !units.isEmpty else { return [] }

        let maximumWidth = normalizedWidth(availableWidth)
        let key = LyricRubyLayoutCache.Key(
            units: units,
            fontSize: fontSize,
            romanizationFontSize: romanizationFontSize,
            fontWeight: fontWeight,
            availableWidth: maximumWidth
        )
        if let cachedRows = cache.rows(for: key) {
            return cachedRows
        }

        let originalFont = NSFont.systemFont(
            ofSize: fontSize,
            weight: fontWeight.appKitWeight
        )
        let romanizationFont = NSFont.systemFont(
            ofSize: romanizationFontSize,
            weight: fontWeight.appKitWeight
        )
        let spacing = max(romanizationFontSize * 0.18, 2)
        let measuredUnits = units.map { unit in
            MeasuredUnit(
                lyric: unit,
                originalWidth: measuredWidth(
                    unit.originalText,
                    font: originalFont
                ),
                romanizationWidth: measuredWidth(
                    unit.romanizationText ?? "",
                    font: romanizationFont
                )
            )
        }

        var rowGroups: [[MeasuredUnit]] = []
        var currentUnits: [MeasuredUnit] = []
        var currentWidth: CGFloat = 0

        func appendCurrentRow() {
            guard !currentUnits.isEmpty else { return }
            rowGroups.append(currentUnits)
            currentUnits = []
            currentWidth = 0
        }

        for unit in measuredUnits {
            let nextWidth = max(
                unit.originalWidth,
                unit.romanizationWidth,
                1
            )
            let addedWidth = currentUnits.isEmpty
                ? nextWidth
                : spacing + nextWidth
            if !currentUnits.isEmpty,
               currentWidth + addedWidth > maximumWidth {
                appendCurrentRow()
            }
            if !currentUnits.isEmpty {
                currentWidth += spacing
            }
            currentUnits.append(unit)
            currentWidth += nextWidth
        }
        appendCurrentRow()

        let rows = rowGroups.enumerated().map { rowIndex, units in
            makeRow(
                id: rowIndex,
                from: units,
                spacing: spacing
            )
        }
        cache.insert(rows, for: key)
        return rows
    }

    private static func makeRow(
        id: Int,
        from measuredUnits: [MeasuredUnit],
        spacing: CGFloat
    ) -> LyricRubyRow {
        var originX: CGFloat = 0
        var originalNaturalX: CGFloat = 0
        var romanizationNaturalX: CGFloat = 0
        var units: [LyricRubyPlacementUnit] = []
        units.reserveCapacity(measuredUnits.count)

        for (index, measuredUnit) in measuredUnits.enumerated() {
            if index > 0 {
                originX += spacing
            }
            let cellWidth = max(
                measuredUnit.originalWidth,
                measuredUnit.romanizationWidth,
                1
            )
            units.append(
                LyricRubyPlacementUnit(
                    lyric: measuredUnit.lyric,
                    originalOffset: originX - originalNaturalX,
                    romanizationOffset:
                        originX - romanizationNaturalX
                )
            )
            originX += cellWidth
            originalNaturalX += measuredUnit.originalWidth
            romanizationNaturalX +=
                measuredUnit.romanizationWidth
        }

        let width = max(originX, 1)
        return LyricRubyRow(
            id: id,
            width: width,
            originalText:
                LyricRubyTextBuilder.originalText(from: units),
            romanizationText:
                LyricRubyTextBuilder.romanizationText(from: units),
            plainOriginalText:
                units.map(\.lyric.originalText).joined(),
            originalTrailingVisualOverflow:
                units.map(\.originalOffset).max() ?? 0,
            romanizationTrailingVisualOverflow:
                units.map(\.romanizationOffset).max() ?? 0
        )
    }

    private static func measuredWidth(
        _ text: String,
        font: NSFont
    ) -> CGFloat {
        guard !text.isEmpty else { return 0 }

        // Timed lyrics are split into attributed character runs. Measuring
        // each character mirrors that layout and avoids kerning differences
        // that could otherwise make adjacent ruby cells overlap.
        return max(
            ceil(
                text.reduce(CGFloat.zero) { width, character in
                    width
                        + glyphWidthCache.width(
                            for: String(character),
                            font: font
                        )
                }
            ),
            1
        )
    }

    private static func normalizedWidth(
        _ width: CGFloat?
    ) -> CGFloat {
        guard let width, width.isFinite, width > 0 else {
            return .greatestFiniteMagnitude
        }
        return width
    }
}

private struct MeasuredUnit {
    let lyric: LyricRubyUnit
    let originalWidth: CGFloat
    let romanizationWidth: CGFloat
}

@MainActor
private final class LyricRubyGlyphWidthCache {
    struct Key: Hashable {
        let text: String
        let fontName: String
        let pointSize: CGFloat
    }

    private var storage: [Key: CGFloat] = [:]
    private var insertionOrder: [Key] = []
    private let capacity = 4_096

    func width(
        for text: String,
        font: NSFont
    ) -> CGFloat {
        let key = Key(
            text: text,
            fontName: font.fontName,
            pointSize: font.pointSize
        )
        if let cachedWidth = storage[key] {
            return cachedWidth
        }

        let width = (text as NSString).size(
            withAttributes: [.font: font]
        ).width
        storage[key] = width
        insertionOrder.append(key)
        if insertionOrder.count > capacity {
            let expiredKey = insertionOrder.removeFirst()
            storage.removeValue(forKey: expiredKey)
        }
        return width
    }
}

@MainActor
private final class LyricRubyLayoutCache {
    struct Key: Hashable {
        let units: [LyricRubyUnit]
        let fontSize: CGFloat
        let romanizationFontSize: CGFloat
        let fontWeight: LyricsFontWeight
        let availableWidth: CGFloat
    }

    private var storage: [Key: [LyricRubyRow]] = [:]
    private var insertionOrder: [Key] = []
    private let capacity = 512

    func rows(for key: Key) -> [LyricRubyRow]? {
        storage[key]
    }

    func insert(
        _ rows: [LyricRubyRow],
        for key: Key
    ) {
        guard storage[key] == nil else { return }

        storage[key] = rows
        insertionOrder.append(key)
        if insertionOrder.count > capacity {
            let expiredKey = insertionOrder.removeFirst()
            storage.removeValue(forKey: expiredKey)
        }
    }
}
