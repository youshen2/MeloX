import SwiftUI

struct WatchLyricTimingTextAttribute:
    TextAttribute,
    Hashable,
    Sendable
{
    let startTime: TimeInterval
    let endTime: TimeInterval
    let syllableStartTime: TimeInterval
    let syllableEndTime: TimeInterval
    let characterIndex: Int
    let characterCount: Int
    let wordStartTime: TimeInterval
    let wordEndTime: TimeInterval
    let wordCharacterIndex: Int
    let wordCharacterCount: Int
    let usesWordTimingForLongTone: Bool
    let isWhitespace: Bool
}

@MainActor
enum WatchTimedLyricTextBuilder {
    private static var cache: [
        [WatchLyricSyllable]: Text
    ] = [:]
    private static var insertionOrder: [
        [WatchLyricSyllable]
    ] = []
    private static let cacheCapacity = 256

    static func text(
        from syllables: [WatchLyricSyllable]
    ) -> Text {
        if let cached = cache[syllables] {
            return cached
        }

        let characters = timedCharacters(from: syllables)
        let wordTimings = wordTimings(
            for: characters,
            source: characters.map(\.text).joined()
        )
        let result = characters.enumerated().reduce(
            Text(verbatim: "")
        ) { result, entry in
            let character = entry.element
            let wordTiming = wordTimings[entry.offset]
            let fragment = Text(verbatim: character.text)
                .customAttribute(
                    WatchLyricTimingTextAttribute(
                        startTime: character.startTime,
                        endTime: character.endTime,
                        syllableStartTime:
                            character.syllableStartTime,
                        syllableEndTime:
                            character.syllableEndTime,
                        characterIndex: character.characterIndex,
                        characterCount: character.characterCount,
                        wordStartTime: wordTiming.startTime,
                        wordEndTime: wordTiming.endTime,
                        wordCharacterIndex:
                            wordTiming.characterIndex,
                        wordCharacterCount:
                            wordTiming.characterCount,
                        usesWordTimingForLongTone:
                            wordTiming.usesWordTimingForLongTone,
                        isWhitespace: character.isWhitespace
                    )
                )
            return Text("\(result)\(fragment)")
        }
        insert(result, for: syllables)
        return result
    }

    private static func timedCharacters(
        from syllables: [WatchLyricSyllable]
    ) -> [TimedCharacter] {
        syllables.flatMap { syllable -> [TimedCharacter] in
            let characters = Array(syllable.text)
            guard !characters.isEmpty else { return [] }

            let duration = max(
                syllable.endTime - syllable.startTime,
                0
            )
            let characterDuration = duration
                / Double(characters.count)
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

    private static func wordTimings(
        for characters: [TimedCharacter],
        source: String
    ) -> [WordTiming] {
        var result = characters.map {
            WordTiming(
                startTime: $0.startTime,
                endTime: $0.endTime,
                characterIndex: 0,
                characterCount: 1,
                usesWordTimingForLongTone: false
            )
        }

        for range in WatchLyricWordSegmenter.blockRanges(in: source) {
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
            let positions = Dictionary(
                keepingFirst: timedIndices.enumerated().map {
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
                        positions[index]
                            ?? max(timedIndices.count - 1, 0),
                    characterCount: max(timedIndices.count, 1),
                    usesWordTimingForLongTone:
                        usesWordTimingForLongTone
                )
            }
        }
        return result
    }

    private static func insert(
        _ text: Text,
        for key: [WatchLyricSyllable]
    ) {
        guard cache[key] == nil else { return }
        cache[key] = text
        insertionOrder.append(key)
        if insertionOrder.count > cacheCapacity {
            cache.removeValue(forKey: insertionOrder.removeFirst())
        }
    }
}

private extension WatchTimedLyricTextBuilder {
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

    struct WordTiming {
        let startTime: TimeInterval
        let endTime: TimeInterval
        let characterIndex: Int
        let characterCount: Int
        let usesWordTimingForLongTone: Bool
    }
}
