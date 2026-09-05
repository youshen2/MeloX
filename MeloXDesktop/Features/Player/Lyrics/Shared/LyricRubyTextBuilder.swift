import SwiftUI

@MainActor
enum LyricRubyTextBuilder {
    static func originalText(
        from units: [LyricRubyPlacementUnit]
    ) -> Text {
        units.reduce(into: LyricAttributedText(verbatim: "")) { result, unit in
            let fragment = timedText(
                source: unit.lyric.originalText,
                syllables: unit.lyric.originalSyllables
            )
            let placedFragment = fragment.customAttribute(
                LyricRubyPlacementTextAttribute(
                    horizontalOffset: unit.originalOffset
                )
            )
            result.append(placedFragment)
        }.text
    }

    static func romanizationText(
        from units: [LyricRubyPlacementUnit]
    ) -> Text {
        units.reduce(into: LyricAttributedText(verbatim: "")) { result, unit in
            guard let romanization = unit.lyric.romanizationText else {
                return
            }
            let fragment = timedText(
                source: romanization,
                syllables: unit.lyric.romanizationSyllables
            )
            let placedFragment = fragment.customAttribute(
                LyricRubyPlacementTextAttribute(
                    horizontalOffset: unit.romanizationOffset
                )
            )
            result.append(placedFragment)
        }.text
    }

    private static func timedText(
        source: String,
        syllables: [LyricSyllable]
    ) -> LyricAttributedText {
        let characters = timedCharacters(from: syllables)
        guard !characters.isEmpty,
              characters.map(\.text).joined() == source else {
            return LyricAttributedText(verbatim: source)
        }

        let timedIndices = characters.indices.filter {
            !characters[$0].isWhitespace
        }
        let wordStartTime = timedIndices
            .map { characters[$0].startTime }
            .min() ?? 0
        let wordEndTime = timedIndices
            .map { characters[$0].endTime }
            .max() ?? wordStartTime
        let wordPositions = Dictionary(
            uniqueKeysWithValues: timedIndices.enumerated().map {
                ($0.element, $0.offset)
            }
        )
        let usesWordTimingForLongTone =
            timedIndices.count > 1
                && timedIndices.allSatisfy {
                    characters[$0].isLatinLetter
                }

        return characters.enumerated().reduce(into:
            LyricAttributedText(verbatim: "")
        ) { result, entry in
            let index = entry.offset
            let character = entry.element
            let fragment = LyricAttributedText(verbatim: character.text)
                .customAttribute(
                    LyricTimingTextAttribute(
                        startTime: character.startTime,
                        endTime: character.endTime,
                        syllableStartTime:
                            character.syllableStartTime,
                        syllableEndTime:
                            character.syllableEndTime,
                        characterIndex: character.characterIndex,
                        characterCount: character.characterCount,
                        wordStartTime: wordStartTime,
                        wordEndTime: wordEndTime,
                        wordCharacterIndex:
                            wordPositions[index]
                                ?? max(timedIndices.count - 1, 0),
                        wordCharacterCount:
                            max(timedIndices.count, 1),
                        usesWordTimingForLongTone:
                            usesWordTimingForLongTone,
                        isWhitespace: character.isWhitespace
                    )
                )
            result.append(fragment)
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
            let characterDuration =
                duration / Double(characters.count)
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
}

private extension LyricRubyTextBuilder {
    struct TimedCharacter {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let syllableStartTime: TimeInterval
        let syllableEndTime: TimeInterval
        let characterIndex: Int
        let characterCount: Int

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
