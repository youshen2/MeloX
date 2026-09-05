import AppKit
import CoreText
import SwiftUI

@MainActor
enum TimedLyricTextBuilder {
    private static let cache = LyricTextCache()

    static func text(
        from syllables: [LyricSyllable],
        constrainedWidth: CGFloat?,
        fontSize: CGFloat,
        fontWeight: LyricsFontWeight = .bold
    ) -> Text {
        let key = LyricTextCache.Key.timed(
            syllables: syllables,
            constrainedWidth: constrainedWidth,
            fontSize: fontSize,
            fontWeight: fontWeight.rawValue
        )
        if let cachedText = cache.text(for: key) {
            return cachedText
        }

        let text = makeText(
            from: syllables,
            constrainedWidth: constrainedWidth,
            fontSize: fontSize,
            fontWeight: fontWeight
        )
        cache.insert(text, for: key)
        return text
    }

    static func text(
        from source: String,
        constrainedWidth: CGFloat?,
        fontSize: CGFloat,
        fontWeight: LyricsFontWeight = .bold
    ) -> Text {
        let key = LyricTextCache.Key.plain(
            source: source,
            constrainedWidth: constrainedWidth,
            fontSize: fontSize,
            fontWeight: fontWeight.rawValue
        )
        if let cachedText = cache.text(for: key) {
            return cachedText
        }

        let text = makeText(
            from: source,
            constrainedWidth: constrainedWidth,
            fontSize: fontSize,
            fontWeight: fontWeight
        )
        cache.insert(text, for: key)
        return text
    }

    private static func makeText(
        from syllables: [LyricSyllable],
        constrainedWidth: CGFloat?,
        fontSize: CGFloat,
        fontWeight: LyricsFontWeight
    ) -> Text {
        let characters = timedCharacters(from: syllables)
        let source = characters.map(\.text).joined()
        let wordTimings = wordTimings(
            for: characters,
            source: source
        )
        let lineBreakOffsets = lineBreakCharacterOffsets(
            in: source,
            constrainedWidth: constrainedWidth,
            fontSize: fontSize,
            fontWeight: fontWeight,
            usesTimedRunBoundaries: true
        )

        return characters.enumerated().reduce(into: LyricAttributedText(verbatim: "")) {
            text,
            entry in
            let offset = entry.offset
            if lineBreakOffsets.contains(offset),
               offset > 0,
               !characters[offset - 1].isLineBreak {
                text.append(LyricAttributedText(verbatim: "\n"))
            }

            let character = entry.element
            let wordTiming = wordTimings[offset]
            let fragment = LyricAttributedText(verbatim: character.text).customAttribute(
                LyricTimingTextAttribute(
                    startTime: character.startTime,
                    endTime: character.endTime,
                    syllableStartTime: character.syllableStartTime,
                    syllableEndTime: character.syllableEndTime,
                    characterIndex: character.characterIndex,
                    characterCount: character.characterCount,
                    wordStartTime: wordTiming.startTime,
                    wordEndTime: wordTiming.endTime,
                    wordCharacterIndex: wordTiming.characterIndex,
                    wordCharacterCount: wordTiming.characterCount,
                    usesWordTimingForLongTone:
                        wordTiming.usesWordTimingForLongTone,
                    isWhitespace: character.isWhitespace
                )
            )
            text.append(fragment)
        }.text
    }

    private static func makeText(
        from source: String,
        constrainedWidth: CGFloat?,
        fontSize: CGFloat,
        fontWeight: LyricsFontWeight
    ) -> Text {
        let lineBreakOffsets = lineBreakCharacterOffsets(
            in: source,
            constrainedWidth: constrainedWidth,
            fontSize: fontSize,
            fontWeight: fontWeight,
            usesTimedRunBoundaries: false
        )
        guard !lineBreakOffsets.isEmpty else {
            return Text(verbatim: source)
        }

        let characters = Array(source)
        var plannedSource = ""
        plannedSource.reserveCapacity(
            source.utf8.count + lineBreakOffsets.count
        )
        for (offset, character) in characters.enumerated() {
            if lineBreakOffsets.contains(offset),
               offset > 0,
               !characters[offset - 1].isNewline,
               !character.isNewline {
                plannedSource.append("\n")
            }
            plannedSource.append(character)
        }
        return Text(verbatim: plannedSource)
    }

    private static func wordTimings(
        for characters: [TimedCharacter],
        source: String
    ) -> [WordTiming] {
        var result = characters.map { character in
            WordTiming(
                startTime: character.startTime,
                endTime: character.endTime,
                characterIndex: 0,
                characterCount: 1,
                usesWordTimingForLongTone: false
            )
        }

        for range in LyricWordSegmenter.blockRanges(in: source) {
            guard range.lowerBound >= characters.startIndex,
                  range.upperBound <= characters.endIndex,
                  range.lowerBound < range.upperBound else {
                continue
            }

            let timedIndices = range.filter {
                !characters[$0].isWhitespace
            }
            guard let startTime = timedIndices
                .map({ characters[$0].startTime })
                .min(),
                let endTime = timedIndices
                    .map({ characters[$0].endTime })
                    .max() else {
                continue
            }
            let characterPositions = Dictionary(
                uniqueKeysWithValues: timedIndices.enumerated().map {
                    ($0.element, $0.offset)
                }
            )
            let usesWordTimingForLongTone =
                timedIndices.count > 1
                    && timedIndices.allSatisfy {
                        characters[$0].isLatinLetter
                    }
            for index in range {
                result[index] = WordTiming(
                    startTime: startTime,
                    endTime: endTime,
                    characterIndex:
                        characterPositions[index]
                            ?? max(timedIndices.count - 1, 0),
                    characterCount: max(timedIndices.count, 1),
                    usesWordTimingForLongTone:
                        usesWordTimingForLongTone
                )
            }
        }
        return result
    }

    private static func timedCharacters(
        from syllables: [LyricSyllable]
    ) -> [TimedCharacter] {
        syllables.flatMap { syllable -> [TimedCharacter] in
            let characters = Array(syllable.text)
            guard !characters.isEmpty else { return [] }

            let duration = max(
                syllable.endTime - syllable.startTime,
                0
            )
            let characterDuration = duration / Double(characters.count)

            return characters.enumerated().map { entry in
                let startTime = syllable.startTime
                    + Double(entry.offset) * characterDuration
                let endTime = entry.offset == characters.count - 1
                    ? max(syllable.endTime, startTime)
                    : startTime + characterDuration
                return TimedCharacter(
                    text: String(entry.element),
                    startTime: startTime,
                    endTime: endTime,
                    syllableStartTime: syllable.startTime,
                    syllableEndTime: syllable.endTime,
                    characterIndex: entry.offset,
                    characterCount: characters.count
                )
            }
        }
    }

    private static func lineBreakCharacterOffsets(
        in source: String,
        constrainedWidth: CGFloat?,
        fontSize: CGFloat,
        fontWeight: LyricsFontWeight,
        usesTimedRunBoundaries: Bool
    ) -> Set<Int> {
        guard !source.isEmpty,
              let constrainedWidth,
              constrainedWidth.isFinite,
              constrainedWidth > 0,
              fontSize.isFinite,
              fontSize > 0 else {
            return []
        }

        let appFont = NSFont.systemFont(
            ofSize: fontSize,
            weight: fontWeight.appKitWeight
        )
        let layoutFont = CTFontCreateWithName(
            appFont.fontName as CFString,
            fontSize,
            nil
        )
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String):
                layoutFont,
        ]
        if usesTimedRunBoundaries {
            attributes[
                NSAttributedString.Key(kCTLigatureAttributeName as String)
            ] = 0
        }
        let attributedText = NSMutableAttributedString(
            string: source,
            attributes: attributes
        )
        if usesTimedRunBoundaries {
            addTimedRunBoundaries(to: attributedText, source: source)
        }
        let typesetter = CTTypesetterCreateWithAttributedString(
            attributedText
        )
        let utf16Length = attributedText.length
        var utf16Offset = 0
        var result: Set<Int> = []
        let layoutWidth = effectiveLayoutWidth(
            source: source,
            constrainedWidth: constrainedWidth,
            fontSize: fontSize,
            usesTimedRunBoundaries: usesTimedRunBoundaries
        )

        while utf16Offset < utf16Length {
            let suggestedLength = CTTypesetterSuggestLineBreak(
                typesetter,
                utf16Offset,
                Double(layoutWidth)
            )
            let consumedLength = max(
                suggestedLength,
                nextCharacterLength(
                    in: source,
                    atUTF16Offset: utf16Offset
                )
            )
            let nextOffset = min(
                utf16Offset + consumedLength,
                utf16Length
            )
            guard nextOffset > utf16Offset else { break }
            utf16Offset = nextOffset

            if utf16Offset < utf16Length,
               let characterOffset = characterOffset(
                    in: source,
                    utf16Offset: utf16Offset
               ),
               characterOffset > 0 {
                result.insert(characterOffset)
            }
        }
        return result
    }

    private static func effectiveLayoutWidth(
        source: String,
        constrainedWidth: CGFloat,
        fontSize: CGFloat,
        usesTimedRunBoundaries: Bool
    ) -> CGFloat {
        let containsLatinText = source.unicodeScalars.contains { scalar in
            (65...90).contains(scalar.value)
                || (97...122).contains(scalar.value)
        }
        let containsWordSpacing = source.contains { $0.isWhitespace }
        let safetyMargin: CGFloat
        if usesTimedRunBoundaries,
           containsLatinText,
           containsWordSpacing {
            // SwiftUI's individually attributed Latin glyph runs measure
            // wider than Core Text's typesetter near word boundaries.
            safetyMargin = max(
                constrainedWidth * 0.05,
                fontSize * 0.5
            )
        } else {
            safetyMargin = max(fontSize * 0.02, 0.5)
        }
        return max(constrainedWidth - safetyMargin, 1)
    }

    private static func addTimedRunBoundaries(
        to attributedText: NSMutableAttributedString,
        source: String
    ) {
        let runBoundaryAttribute = NSAttributedString.Key(
            "MeloXTimedLyricRunBoundary"
        )
        var utf16Offset = 0
        for (characterOffset, character) in source.enumerated() {
            let utf16Length = String(character).utf16.count
            attributedText.addAttribute(
                runBoundaryAttribute,
                value: characterOffset,
                range: NSRange(
                    location: utf16Offset,
                    length: utf16Length
                )
            )
            utf16Offset += utf16Length
        }
    }

    private static func nextCharacterLength(
        in source: String,
        atUTF16Offset offset: Int
    ) -> Int {
        guard offset < source.utf16.count else { return 0 }
        let range = (source as NSString).rangeOfComposedCharacterSequence(
            at: offset
        )
        return max(range.location + range.length - offset, 1)
    }

    private static func characterOffset(
        in source: String,
        utf16Offset: Int
    ) -> Int? {
        let utf16 = source.utf16
        guard let utf16Index = utf16.index(
            utf16.startIndex,
            offsetBy: utf16Offset,
            limitedBy: utf16.endIndex
        ),
        let stringIndex = String.Index(utf16Index, within: source) else {
            return nil
        }
        return source.distance(from: source.startIndex, to: stringIndex)
    }
}

@MainActor
private final class LyricTextCache {
    enum Key: Hashable {
        case timed(
            syllables: [LyricSyllable],
            constrainedWidth: CGFloat?,
            fontSize: CGFloat,
            fontWeight: String
        )
        case plain(
            source: String,
            constrainedWidth: CGFloat?,
            fontSize: CGFloat,
            fontWeight: String
        )
    }

    private static let maximumEntryCount = 256
    private var storage: [Key: Text] = [:]
    private var insertionOrder: [Key] = []

    func text(for key: Key) -> Text? {
        storage[key]
    }

    func insert(_ text: Text, for key: Key) {
        guard storage[key] == nil else { return }
        storage[key] = text
        insertionOrder.append(key)

        let overflow = insertionOrder.count - Self.maximumEntryCount
        guard overflow > 0 else { return }
        for expiredKey in insertionOrder.prefix(overflow) {
            storage.removeValue(forKey: expiredKey)
        }
        insertionOrder.removeFirst(overflow)
    }
}

private extension TimedLyricTextBuilder {
    struct WordTiming {
        let startTime: TimeInterval
        let endTime: TimeInterval
        let characterIndex: Int
        let characterCount: Int
        let usesWordTimingForLongTone: Bool
    }

    struct TimedCharacter {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let syllableStartTime: TimeInterval
        let syllableEndTime: TimeInterval
        let characterIndex: Int
        let characterCount: Int

        var isLineBreak: Bool {
            text == "\n" || text == "\r" || text == "\r\n"
        }

        var isWhitespace: Bool {
            text.allSatisfy(\.isWhitespace)
        }

        var isLatinLetter: Bool {
            !text.isEmpty
                && text.unicodeScalars.allSatisfy { scalar in
                    (65...90).contains(scalar.value)
                        || (97...122).contains(scalar.value)
                }
        }
    }
}
