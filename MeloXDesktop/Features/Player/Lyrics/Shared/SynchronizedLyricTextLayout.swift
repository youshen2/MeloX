import SwiftUI

/// Reuses the complete text/ruby layout during display-clock updates. Playback,
/// focus, and interaction values do not participate in this bounded cache.
@MainActor
struct SynchronizedLyricTextLayout {
    let synchronizedText: Text
    let pseudoSynchronizedText: Text
    let layoutStableText: Text
    let hasPseudoSyllables: Bool
    let timedPlaybackRange: ClosedRange<TimeInterval>?
    let romanizationRows: [LyricRubyRow]

    private struct Key: Hashable {
        let lineID: LyricLine.ID
        let usesPseudoTiming: Bool
        let fontSize: CGFloat
        let romanizationFontSize: CGFloat
        let fontWeight: LyricsFontWeight
        let includesRomanization: Bool
        let showsRomanization: Bool
        let layoutWidth: CGFloat?
        let promotedLayoutScale: CGFloat
        let playbackScaleRange: ClosedRange<CGFloat>?
    }

    private struct Entry {
        let line: LyricLine
        let layout: SynchronizedLyricTextLayout
    }

    private static var entries: [Key: Entry] = [:]
    private static let capacity = 256

    static func resolve(
        line: LyricLine,
        usesPseudoTiming: Bool,
        fontSize: CGFloat,
        romanizationFontSize: CGFloat,
        fontWeight: LyricsFontWeight,
        includesRomanization: Bool,
        showsRomanization: Bool,
        layoutWidth: CGFloat?,
        promotedLayoutScale: CGFloat,
        playbackScaleRange: ClosedRange<CGFloat>?
    ) -> SynchronizedLyricTextLayout {
        let key = Key(
            lineID: line.id,
            usesPseudoTiming: usesPseudoTiming,
            fontSize: fontSize,
            romanizationFontSize: romanizationFontSize,
            fontWeight: fontWeight,
            includesRomanization: includesRomanization,
            showsRomanization: showsRomanization,
            layoutWidth: layoutWidth,
            promotedLayoutScale: promotedLayoutScale,
            playbackScaleRange: playbackScaleRange
        )
        if let entry = entries[key], entry.line == line {
            return entry.layout
        }
        let layout = SynchronizedLyricTextLayout(
            line: line,
            usesPseudoTiming: usesPseudoTiming,
            fontSize: fontSize,
            romanizationFontSize: romanizationFontSize,
            fontWeight: fontWeight,
            includesRomanization: includesRomanization,
            showsRomanization: showsRomanization,
            layoutWidth: layoutWidth,
            promotedLayoutScale: promotedLayoutScale,
            playbackScaleRange: playbackScaleRange
        )
        if entries[key] == nil, entries.count >= capacity {
            entries.remove(at: entries.startIndex)
        }
        entries[key] = Entry(line: line, layout: layout)
        return layout
    }

    private init(
        line: LyricLine,
        usesPseudoTiming: Bool,
        fontSize: CGFloat,
        romanizationFontSize: CGFloat,
        fontWeight: LyricsFontWeight,
        includesRomanization: Bool,
        showsRomanization: Bool,
        layoutWidth: CGFloat?,
        promotedLayoutScale: CGFloat,
        playbackScaleRange: ClosedRange<CGFloat>?
    ) {
        let pseudoSyllables = usesPseudoTiming
            ? line.makePseudoSyllables()
            : []
        let activeSyllables = line.syllables.isEmpty
            ? pseudoSyllables
            : line.syllables
        let timedLayoutWidth = layoutWidth.map {
            $0 / max(playbackScaleRange?.upperBound ?? 1, 1)
        }
        let calculationScale = promotedLayoutScale.isFinite
            ? max(promotedLayoutScale, 1)
            : 1
        let rubyLayoutWidth = timedLayoutWidth.map {
            $0 / calculationScale
        }
        synchronizedText = TimedLyricTextBuilder.text(
            from: line.syllables,
            constrainedWidth: timedLayoutWidth,
            fontSize: fontSize * calculationScale,
            fontWeight: fontWeight
        )
        pseudoSynchronizedText = TimedLyricTextBuilder.text(
            from: pseudoSyllables,
            constrainedWidth: timedLayoutWidth,
            fontSize: fontSize * calculationScale,
            fontWeight: fontWeight
        )
        layoutStableText = TimedLyricTextBuilder.text(
            from: line.text,
            constrainedWidth: layoutWidth,
            fontSize: fontSize * calculationScale,
            fontWeight: fontWeight
        )
        hasPseudoSyllables = !pseudoSyllables.isEmpty
        let romanizationUnits =
            includesRomanization && showsRomanization
                ? LyricRomanizationAligner.units(
                    for: line,
                    activeSyllables: activeSyllables
                )
                : []
        romanizationRows = LyricRubyLayoutPlanner.rows(
            for: romanizationUnits,
            fontSize: fontSize,
            romanizationFontSize:
                romanizationFontSize,
            fontWeight: fontWeight,
            availableWidth: rubyLayoutWidth
        )
        if let firstSyllable = activeSyllables.first,
           let lastSyllable = activeSyllables.last,
           lastSyllable.endTime > firstSyllable.startTime {
            timedPlaybackRange = firstSyllable.startTime...lastSyllable.endTime
        } else {
            timedPlaybackRange = nil
        }
    }
}
