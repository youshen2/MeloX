import Foundation

enum LyricParser {
    static func parse(
        yrc: String,
        lrc: String,
        translatedYRC: String = "",
        translatedLRC: String = ""
    ) -> [LyricLine] {
        let synchronizedLines = parseYRC(yrc)
        let lineSynchronizedLines = parseLRC(lrc)
        let lines = synchronizedLines.isEmpty ? lineSynchronizedLines : synchronizedLines
        guard !lines.isEmpty else { return [] }

        let synchronizedTranslations = parseYRC(translatedYRC)
        let translatedYRCFallback = synchronizedTranslations.isEmpty
            ? parseLRC(translatedYRC)
            : synchronizedTranslations
        let lineSynchronizedTranslations = parseLRC(translatedLRC)

        let directlyTranslatedLines = attachTranslations(
            translatedYRCFallback,
            to: lines
        )
        guard !lineSynchronizedTranslations.isEmpty else {
            return directlyTranslatedLines
        }

        if synchronizedLines.isEmpty || lineSynchronizedLines.isEmpty {
            return attachTranslations(
                lineSynchronizedTranslations,
                to: directlyTranslatedLines
            )
        }

        let translatedOriginalLines = attachTranslations(
            lineSynchronizedTranslations,
            to: lineSynchronizedLines
        )
        let canonicallyTranslatedLines = transferTranslations(
            from: translatedOriginalLines,
            to: lines
        )
        return fillMissingTranslations(
            in: canonicallyTranslatedLines,
            from: directlyTranslatedLines
        )
    }

    static func parseLRC(_ source: String) -> [LyricLine] {
        let lines = source
            .split(whereSeparator: \Character.isNewline)
            .flatMap { parseLRCLines($0) }
            .sorted { $0.time < $1.time }
        return inferringDurations(in: lines)
    }

    static func parseYRC(_ source: String) -> [LyricLine] {
        source
            .split(whereSeparator: \Character.isNewline)
            .compactMap { rawLine in
                let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
                if line.first == "{" {
                    return parseYRCCredits(line)
                }
                return parseYRCSyllableLine(line)
            }
            .sorted { $0.time < $1.time }
    }

    private static func parseLRCLines(_ rawLine: Substring) -> [LyricLine] {
        let line = String(rawLine)
        let storage = line as NSString
        let matches = lrcTimestampExpression.matches(
            in: line,
            range: NSRange(line.startIndex..., in: line)
        )
        guard let lastMatch = matches.last else { return [] }

        let textStart = NSMaxRange(lastMatch.range)
        let text = storage.substring(from: textStart)
            .trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return [] }

        return matches.compactMap { match in
            guard let minutes = integer(in: match.range(at: 1), from: storage) else {
                return nil
            }
            let rawSeconds = storage.substring(with: match.range(at: 2))
                .replacingOccurrences(of: ":", with: ".")
            guard let seconds = Double(rawSeconds) else { return nil }
            return LyricLine(time: Double(minutes) * 60 + seconds, text: text)
        }
    }

    private static func inferringDurations(in lines: [LyricLine]) -> [LyricLine] {
        lines.enumerated().map { index, line in
            let nextLineTime = index + 1 < lines.count
                ? lines[index + 1].time
                : nil
            let inferredDuration = nextLineTime.flatMap { nextTime in
                let duration = nextTime - line.time
                return duration > 0 ? duration : nil
            } ?? estimatedLastLineDuration(for: line.text)

            return LyricLine(
                time: line.time,
                duration: inferredDuration,
                text: line.text,
                syllables: line.syllables,
                translation: line.translation
            )
        }
    }

    private static func estimatedLastLineDuration(for text: String) -> TimeInterval {
        let visibleCharacterCount = text.filter { !$0.isWhitespace }.count
        return min(max(Double(visibleCharacterCount) * 0.32, 2), 8)
    }

    private static func parseYRCSyllableLine(_ line: String) -> LyricLine? {
        guard line.first == "[",
              let closingBracket = line.firstIndex(of: "]") else { return nil }

        let lineTiming = line[line.index(after: line.startIndex)..<closingBracket]
            .split(separator: ",", omittingEmptySubsequences: false)
        guard lineTiming.count >= 2,
              let lineStartMS = Int(lineTiming[0]),
              let lineDurationMS = Int(lineTiming[1]) else { return nil }

        let content = String(line[line.index(after: closingBracket)...])
        let contentRange = NSRange(content.startIndex..., in: content)
        let matches = syllableExpression.matches(in: content, range: contentRange)
        guard !matches.isEmpty else {
            let text = content.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return LyricLine(
                time: seconds(fromMilliseconds: lineStartMS),
                duration: seconds(fromMilliseconds: lineDurationMS),
                text: text
            )
        }

        let textStorage = content as NSString
        let syllables = matches.enumerated().compactMap { index, match -> LyricSyllable? in
            guard let startMilliseconds = integer(in: match.range(at: 1), from: textStorage),
                  let durationMilliseconds = integer(in: match.range(at: 2), from: textStorage) else {
                return nil
            }

            let textStart = NSMaxRange(match.range)
            let textEnd = index + 1 < matches.count
                ? matches[index + 1].range.location
                : textStorage.length
            guard textEnd >= textStart else { return nil }

            let text = textStorage.substring(
                with: NSRange(location: textStart, length: textEnd - textStart)
            )
            guard !text.isEmpty else { return nil }

            let startTime = seconds(fromMilliseconds: startMilliseconds)
            return LyricSyllable(
                text: text,
                startTime: startTime,
                endTime: startTime + seconds(fromMilliseconds: durationMilliseconds)
            )
        }

        guard !syllables.isEmpty else { return nil }
        return LyricLine(
            time: seconds(fromMilliseconds: lineStartMS),
            duration: seconds(fromMilliseconds: lineDurationMS),
            text: syllables.map(\.text).joined(),
            syllables: syllables
        )
    }

    private static func attachTranslations(
        _ translations: [LyricLine],
        to lines: [LyricLine]
    ) -> [LyricLine] {
        guard !translations.isEmpty else { return lines }

        var lineIndex = 0
        var translationsByLineIndex: [Int: String] = [:]
        for translation in translations {
            while lineIndex + 1 < lines.count {
                let currentDistance = abs(lines[lineIndex].time - translation.time)
                let nextDistance = abs(lines[lineIndex + 1].time - translation.time)
                let shouldAdvance = nextDistance < currentDistance
                    || (nextDistance == currentDistance
                        && !lines[lineIndex].isSyllableSynced
                        && lines[lineIndex + 1].isSyllableSynced)
                guard shouldAdvance else { break }
                lineIndex += 1
            }

            let line = lines[lineIndex]
            let normalizedTranslation = translation.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard abs(line.time - translation.time) <= translationTolerance,
                  !normalizedTranslation.isEmpty,
                  normalizedTranslation != line.text.trimmingCharacters(in: .whitespacesAndNewlines),
                  translationsByLineIndex[lineIndex] == nil else { continue }
            translationsByLineIndex[lineIndex] = normalizedTranslation
        }

        return lines.enumerated().map { index, line in
            line.attachingTranslation(
                translationsByLineIndex[index] ?? line.translation
            )
        }
    }

    /// Standard translations (`tlyric`) share the ordinary LRC timeline while
    /// the displayed lyric may use YRC. Match the translated LRC back to YRC by
    /// normalized original text first, then use a narrow timestamp fallback.
    private static func transferTranslations(
        from sourceLines: [LyricLine],
        to targetLines: [LyricLine]
    ) -> [LyricLine] {
        guard !sourceLines.isEmpty, !targetLines.isEmpty else { return targetLines }

        var minimumTargetIndex = 0
        var translationsByTargetIndex: [Int: String] = [:]
        for sourceLine in sourceLines {
            guard let translation = sourceLine.translation,
                  minimumTargetIndex < targetLines.count else { continue }

            let candidateRange = minimumTargetIndex..<targetLines.count
            let normalizedSource = normalizedLyricText(sourceLine.text)
            let textMatchedIndex = candidateRange
                .filter { index in
                    guard !normalizedSource.isEmpty else { return false }
                    let targetLine = targetLines[index]
                    return abs(targetLine.time - sourceLine.time) <= textMatchWindow
                        && normalizedLyricText(targetLine.text) == normalizedSource
                }
                .min { left, right in
                    abs(targetLines[left].time - sourceLine.time)
                        < abs(targetLines[right].time - sourceLine.time)
                }

            let targetIndex = textMatchedIndex ?? candidateRange
                .filter { index in
                    let targetLine = targetLines[index]
                    return targetLine.isSyllableSynced
                        && abs(targetLine.time - sourceLine.time) <= translationTolerance
                }
                .min { left, right in
                    abs(targetLines[left].time - sourceLine.time)
                        < abs(targetLines[right].time - sourceLine.time)
                }

            guard let targetIndex else { continue }
            translationsByTargetIndex[targetIndex] = translation
            minimumTargetIndex = targetIndex + 1
        }

        return targetLines.enumerated().map { index, line in
            line.attachingTranslation(
                translationsByTargetIndex[index] ?? line.translation
            )
        }
    }

    private static func fillMissingTranslations(
        in primaryLines: [LyricLine],
        from fallbackLines: [LyricLine]
    ) -> [LyricLine] {
        guard primaryLines.count == fallbackLines.count else { return primaryLines }

        return primaryLines.indices.map { index in
            let primaryLine = primaryLines[index]
            let fallbackLine = fallbackLines[index]
            guard primaryLine.translation == nil,
                  let fallbackTranslation = fallbackLine.translation else {
                return primaryLine
            }

            let normalizedFallback = normalizedLyricText(fallbackTranslation)
            let neighboringRange = max(index - 1, 0)...min(
                index + 1,
                primaryLines.count - 1
            )
            let isDuplicateOfNeighbor = neighboringRange.contains { neighborIndex in
                guard let neighborTranslation = primaryLines[neighborIndex].translation else {
                    return false
                }
                return normalizedLyricText(neighborTranslation) == normalizedFallback
            }
            guard !isDuplicateOfNeighbor else {
                return primaryLine
            }
            return primaryLine.attachingTranslation(fallbackTranslation)
        }
    }

    private static func normalizedLyricText(_ text: String) -> String {
        text
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
    }

    private static func parseYRCCredits(_ line: String) -> LyricLine? {
        guard let data = line.data(using: .utf8),
              let credits = try? JSONDecoder().decode(YRCCredits.self, from: data) else {
            return nil
        }

        let text = credits.items.compactMap(\.text).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return LyricLine(
            time: seconds(fromMilliseconds: credits.timestamp),
            text: text
        )
    }

    private static func integer(in range: NSRange, from string: NSString) -> Int? {
        guard range.location != NSNotFound else { return nil }
        return Int(string.substring(with: range))
    }

    private static func seconds(fromMilliseconds milliseconds: Int) -> TimeInterval {
        TimeInterval(milliseconds) / 1_000
    }

    /// YRC stores each syllable as `(absoluteStartMilliseconds,durationMilliseconds,metadata)`.
    /// The metadata field is intentionally ignored, matching Lyricify Lyrics Helper's parser.
    private static let syllableExpression = try! NSRegularExpression(
        pattern: #"\((\d+),(\d+),[^)]*\)"#
    )

    private static let lrcTimestampExpression = try! NSRegularExpression(
        pattern: #"\[(\d+):(\d+(?:[\.:]\d+)?)\]"#
    )

    /// Translation tracks occasionally differ from the YRC line header by a
    /// few hundred milliseconds. A narrow tolerance preserves alignment while
    /// avoiding reuse across neighboring lyric lines.
    private static let translationTolerance: TimeInterval = 0.75
    private static let textMatchWindow: TimeInterval = 5
}

private struct YRCCredits: Decodable {
    struct Item: Decodable {
        let text: String?

        private enum CodingKeys: String, CodingKey {
            case text = "tx"
        }
    }

    let timestamp: Int
    let items: [Item]

    private enum CodingKeys: String, CodingKey {
        case timestamp = "t"
        case items = "c"
    }
}
