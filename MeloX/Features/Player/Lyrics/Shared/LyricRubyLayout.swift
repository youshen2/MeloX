import SwiftUI
import UIKit

/// Moves a transliteration run to its mapped logical position without
/// introducing placeholder whitespace into the attributed string.
nonisolated struct LyricRubyPlacementTextAttribute:
    TextAttribute,
    Hashable,
    Sendable
{
    let horizontalOffset: CGFloat
}

/// One visual line of the supplemental transliteration stream.
///
/// The primary lyric is deliberately not stored here. Apple Music lays the
/// transliteration out as a separate text line below the primary lyric; the
/// source text is used only to preserve its mapped width and wrap points.
struct LyricRubyRow: Identifiable {
    let id: Int
    let width: CGFloat
    let romanizationText: Text
    let plainRomanizationText: String
    let romanizationTrailingVisualOverflow: CGFloat
    let hasTimedContent: Bool
}

/// A single wrap plan shared by the primary and transliteration streams.
/// Offsets are expressed in Characters of the original lyric, before any
/// visual newlines are inserted.
struct LyricRubyLayoutPlan {
    let rows: [LyricRubyRow]
    /// `nil` means a single mapped unit is wider than the viewport, so the
    /// primary text must keep its own Core Text wrapping fallback. An empty
    /// set is a reliable one-line plan and intentionally suppresses extra
    /// automatic breaks in the primary stream.
    let sourceLineBreakCharacterOffsets: Set<Int>?
    /// Horizontal space inserted before a source unit after a wider
    /// transliteration token expands its mapped source range.
    let sourceHorizontalOffsetsByCharacterOffset: [Int: CGFloat]
}

struct LyricRubyPlacementUnit {
    let lyric: LyricRubyUnit
    let romanizationOffset: CGFloat
}

@MainActor
enum LyricRubyLayoutPlanner {
    private static let cache = LyricRubyLayoutCache()
    private static let stringWidthCache = LyricRubyStringWidthCache()

    static func plan(
        for units: [LyricRubyUnit],
        fontSize: CGFloat,
        romanizationFontSize: CGFloat,
        primaryFontWeight: LyricsFontWeight,
        romanizationFontWeight: LyricsFontWeight,
        availableWidth: CGFloat?,
        minimumWordSpacing: CGFloat
    ) -> LyricRubyLayoutPlan {
        guard !units.isEmpty else {
            return LyricRubyLayoutPlan(
                rows: [],
                sourceLineBreakCharacterOffsets: [],
                sourceHorizontalOffsetsByCharacterOffset: [:]
            )
        }

        let maximumWidth = normalizedWidth(availableWidth)
        let spacing = normalizedSpacing(minimumWordSpacing)
        let key = LyricRubyLayoutCache.Key(
            units: units,
            fontSize: fontSize,
            romanizationFontSize: romanizationFontSize,
            primaryFontWeight: primaryFontWeight,
            romanizationFontWeight: romanizationFontWeight,
            availableWidth: maximumWidth,
            minimumWordSpacing: spacing
        )
        if let cachedPlan = cache.plan(for: key) {
            return cachedPlan
        }

        let originalFont = UIFont.systemFont(
            ofSize: fontSize,
            weight: primaryFontWeight.uiKitWeight
        )
        let romanizationFont = UIFont.systemFont(
            ofSize: romanizationFontSize,
            weight: romanizationFontWeight.uiKitWeight
        )
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

        var rows: [LyricRubyRow] = []
        var sourceLineBreakCharacterOffsets: Set<Int> = []
        var sourceHorizontalOffsetsByCharacterOffset: [Int: CGFloat] = [:]
        var sourceCharacterOffset = 0
        var hasOversizedUnit = false
        var rowBuilder = RowBuilder(
            id: 0,
            minimumWordSpacing: spacing
        )

        for measuredUnit in measuredUnits {
            if let offset = rowBuilder.sourceOffsetForNextUnit,
               sourceCharacterOffset > 0 {
                sourceHorizontalOffsetsByCharacterOffset[
                    sourceCharacterOffset
                ] = offset
            }
            var standaloneBuilder = RowBuilder(
                id: 0,
                minimumWordSpacing: spacing
            )
            standaloneBuilder.append(measuredUnit)
            if !standaloneBuilder.fits(within: maximumWidth) {
                hasOversizedUnit = true
            }
            if rowBuilder.containsContent,
               !rowBuilder.canAppend(
                   measuredUnit,
                   within: maximumWidth
               ) {
                if let row = rowBuilder.makeRow() {
                    rows.append(row)
                }
                sourceLineBreakCharacterOffsets.insert(
                    sourceCharacterOffset
                )
                sourceHorizontalOffsetsByCharacterOffset[
                    sourceCharacterOffset
                ] = nil
                rowBuilder = RowBuilder(
                    id: rows.count,
                    minimumWordSpacing: spacing
                )
            }
            rowBuilder.append(measuredUnit)
            sourceCharacterOffset += measuredUnit.lyric.originalText.count
        }
        if let row = rowBuilder.makeRow() {
            rows.append(row)
        }

        let plan = LyricRubyLayoutPlan(
            rows: rows,
            sourceLineBreakCharacterOffsets:
                hasOversizedUnit
                    ? nil
                    : sourceLineBreakCharacterOffsets,
            sourceHorizontalOffsetsByCharacterOffset:
                hasOversizedUnit
                    ? [:]
                    : sourceHorizontalOffsetsByCharacterOffset
        )
        cache.insert(plan, for: key)
        return plan
    }

    private static func measuredWidth(
        _ text: String,
        font: UIFont
    ) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return max(
            ceil(
                stringWidthCache.width(
                    for: text,
                    font: font
                )
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

    private static func normalizedSpacing(
        _ spacing: CGFloat
    ) -> CGFloat {
        guard spacing.isFinite else { return 0 }
        return max(spacing, 0)
    }
}

private struct MeasuredUnit {
    let lyric: LyricRubyUnit
    let originalWidth: CGFloat
    let romanizationWidth: CGFloat

    var hasRomanization: Bool {
        romanizationWidth > 0
            && !(lyric.romanizationText ?? "").isEmpty
    }
}

/// Builds a logical source row and a separate transliteration row together.
/// The source cursor only determines wrapping and the row's mapped width. A
/// pronunciation token itself starts after the previous pronunciation token;
/// it is never centered or distributed inside the source range.
private struct RowBuilder {
    let id: Int
    let minimumWordSpacing: CGFloat

    private(set) var measuredUnits: [MeasuredUnit] = []
    private(set) var placements: [LyricRubyPlacementUnit] = []
    private(set) var sourceEnd: CGFloat = 0
    private(set) var romanizationEnd: CGFloat = 0
    private(set) var naturalRomanizationEnd: CGFloat = 0
    private var hasPlacedRomanization = false

    init(
        id: Int,
        minimumWordSpacing: CGFloat
    ) {
        self.id = id
        self.minimumWordSpacing = minimumWordSpacing
    }

    var containsContent: Bool {
        !measuredUnits.isEmpty
    }

    var sourceOffsetForNextUnit: CGFloat? {
        let naturalSourceWidth = measuredUnits.reduce(CGFloat.zero) {
            $0 + $1.originalWidth
        }
        let offset = sourceEnd - naturalSourceWidth
        return offset > 0.001 ? offset : nil
    }

    func canAppend(
        _ measuredUnit: MeasuredUnit,
        within maximumWidth: CGFloat
    ) -> Bool {
        guard maximumWidth.isFinite else { return true }
        var candidate = self
        candidate.append(measuredUnit)
        return candidate.mappedWidth <= maximumWidth
    }

    func fits(within maximumWidth: CGFloat) -> Bool {
        !maximumWidth.isFinite || mappedWidth <= maximumWidth
    }

    mutating func append(_ measuredUnit: MeasuredUnit) {
        measuredUnits.append(measuredUnit)

        let mappedSourceEnd = sourceEnd + measuredUnit.originalWidth
        guard measuredUnit.hasRomanization else {
            sourceEnd = mappedSourceEnd
            return
        }

        let romanizationStart = hasPlacedRomanization
            ? romanizationEnd + minimumWordSpacing
            : 0
        let nextRomanizationEnd =
            romanizationStart + measuredUnit.romanizationWidth

        placements.append(
            LyricRubyPlacementUnit(
                lyric: measuredUnit.lyric,
                romanizationOffset:
                    romanizationStart - naturalRomanizationEnd
            )
        )
        naturalRomanizationEnd += measuredUnit.romanizationWidth
        romanizationEnd = nextRomanizationEnd
        hasPlacedRomanization = true

        if nextRomanizationEnd > mappedSourceEnd {
            // Apple expands an overflowing source span by the overflow plus
            // the minimum inter-word gap, shifting all later source ranges.
            sourceEnd = mappedSourceEnd
                + (nextRomanizationEnd - mappedSourceEnd)
                + minimumWordSpacing
        } else {
            sourceEnd = mappedSourceEnd
        }
    }

    func makeRow() -> LyricRubyRow? {
        guard !placements.isEmpty else { return nil }

        return LyricRubyRow(
            id: id,
            width: max(mappedWidth, 1),
            romanizationText:
                LyricRubyTextBuilder.romanizationText(
                    from: placements
                ),
            plainRomanizationText: placements.compactMap {
                $0.lyric.romanizationText
            }.joined(separator: " "),
            romanizationTrailingVisualOverflow: max(
                romanizationEnd - naturalRomanizationEnd,
                0
            ),
            hasTimedContent: placements.contains {
                LyricRubyTextBuilder.hasTimedRomanization(
                    $0.lyric
                )
            }
        )
    }

    private var mappedWidth: CGFloat {
        max(sourceEnd, romanizationEnd, 1)
    }
}

@MainActor
private final class LyricRubyStringWidthCache {
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
        font: UIFont
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
        let primaryFontWeight: LyricsFontWeight
        let romanizationFontWeight: LyricsFontWeight
        let availableWidth: CGFloat
        let minimumWordSpacing: CGFloat
    }

    private var storage: [Key: LyricRubyLayoutPlan] = [:]
    private var insertionOrder: [Key] = []
    private let capacity = 512

    func plan(for key: Key) -> LyricRubyLayoutPlan? {
        storage[key]
    }

    func insert(
        _ plan: LyricRubyLayoutPlan,
        for key: Key
    ) {
        guard storage[key] == nil else { return }

        storage[key] = plan
        insertionOrder.append(key)
        if insertionOrder.count > capacity {
            let expiredKey = insertionOrder.removeFirst()
            storage.removeValue(forKey: expiredKey)
        }
    }
}
