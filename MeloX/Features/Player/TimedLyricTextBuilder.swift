import CoreText
import SwiftUI

enum TimedLyricTextBuilder {
    static func text(
        from syllables: [LyricSyllable],
        constrainedWidth: CGFloat?,
        fontSize: CGFloat
    ) -> Text {
        let characters = timedCharacters(from: syllables)
        let source = characters.map(\.text).joined()
        let lineBreakOffsets = lineBreakCharacterOffsets(
            in: source,
            constrainedWidth: constrainedWidth,
            fontSize: fontSize
        )

        return characters.enumerated().reduce(Text(verbatim: "")) {
            result,
            entry in
            var text = result
            if lineBreakOffsets.contains(entry.offset),
               characters[entry.offset - 1].text != "\n" {
                text = Text("\(text)\(Text(verbatim: "\n"))")
            }

            let character = entry.element
            let fragment = Text(verbatim: character.text).customAttribute(
                LyricTimingTextAttribute(
                    startTime: character.startTime,
                    endTime: character.endTime,
                    syllableStartTime: character.syllableStartTime,
                    syllableEndTime: character.syllableEndTime,
                    characterIndex: character.characterIndex,
                    characterCount: character.characterCount
                )
            )
            return Text("\(text)\(fragment)")
        }
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
        fontSize: CGFloat
    ) -> Set<Int> {
        guard !source.isEmpty,
              let constrainedWidth,
              constrainedWidth.isFinite,
              constrainedWidth > 0,
              fontSize.isFinite,
              fontSize > 0 else {
            return []
        }

        guard let systemFont = CTFontCreateUIFontForLanguage(
            .system,
            fontSize,
            nil
        ) else {
            return []
        }
        let boldFont = CTFontCreateCopyWithSymbolicTraits(
            systemFont,
            fontSize,
            nil,
            .boldTrait,
            .boldTrait
        ) ?? systemFont
        let attributedText = NSAttributedString(
            string: source,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): boldFont,
            ]
        )
        let typesetter = CTTypesetterCreateWithAttributedString(
            attributedText
        )
        let utf16Length = attributedText.length
        var utf16Offset = 0
        var result: Set<Int> = []

        while utf16Offset < utf16Length {
            let suggestedLength = CTTypesetterSuggestLineBreak(
                typesetter,
                utf16Offset,
                Double(constrainedWidth)
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

private extension TimedLyricTextBuilder {
    struct TimedCharacter {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let syllableStartTime: TimeInterval
        let syllableEndTime: TimeInterval
        let characterIndex: Int
        let characterCount: Int
    }
}
