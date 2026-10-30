import Foundation

struct LyricRubyUnit: Identifiable, Hashable {
    let id: Int
    let originalText: String
    let originalSyllables: [LyricSyllable]
    let romanizationText: String?
    let romanizationSyllables: [LyricSyllable]

    /// True only when the service supplied timing for this transliteration.
    /// Static fallbacks must never fabricate a second per-character timeline.
    let hasAuthoredRomanizationTiming: Bool
}

enum LyricRomanizationAligner {
    private static let cache = LyricRomanizationAlignmentCache()

    static func units(
        for line: LyricLine,
        activeSyllables: [LyricSyllable]
    ) -> [LyricRubyUnit] {
        guard let romanization = normalizedAnnotation(line.romanization) else {
            return []
        }

        let cacheKey = LyricRomanizationAlignmentCache.Key(
            originalText: line.text,
            romanization: romanization,
            originalSyllables: activeSyllables,
            romanizationSyllables: line.romanizationSyllables
        )
        if let cached = cache.units(for: cacheKey) {
            return cached
        }

        let result: [LyricRubyUnit]
        if !activeSyllables.isEmpty,
           !line.romanizationSyllables.isEmpty,
           let timedUnits = timedUnits(
               originals: activeSyllables,
               romanizations: line.romanizationSyllables
           ) {
            result = numbered(timedUnits)
        } else if let segmentedUnits = segmentedUnits(
            originalText: line.text,
            originalSyllables: activeSyllables,
            romanization: romanization
        ) {
            result = numbered(segmentedUnits)
        } else {
            result = numbered([
                makeUnit(
                    originalText: line.text,
                    originalSyllables: activeSyllables,
                    romanization: romanization
                ),
            ])
        }

        cache.insert(result, for: cacheKey)
        return result
    }

    private static func timedUnits(
        originals: [LyricSyllable],
        romanizations: [LyricSyllable]
    ) -> [UnitDraft]? {
        let originals = originals.filter { !$0.text.isEmpty }
        let romanizations = romanizations.filter {
            normalizedAnnotation($0.text) != nil
        }
        guard !originals.isEmpty, !romanizations.isEmpty else {
            return nil
        }

        if originals.count == romanizations.count,
           zip(originals, romanizations).allSatisfy({ original, romanization in
               temporalDistance(original, romanization)
                    <= timingTolerance(for: original, and: romanization)
           }) {
            return zip(originals, romanizations).map { original, romanization in
                makeUnit(
                    originalText: original.text,
                    originalSyllables: [original],
                    romanization: normalizedAnnotation(romanization.text),
                    authoredRomanizationSyllables: [romanization]
                )
            }
        }

        if originals.count >= romanizations.count {
            return unitsByMappingOriginals(
                originals,
                to: romanizations
            )
        }
        return unitsByMappingRomanizations(
            romanizations,
            to: originals
        )
    }

    private static func unitsByMappingOriginals(
        _ originals: [LyricSyllable],
        to romanizations: [LyricSyllable]
    ) -> [UnitDraft]? {
        let mapping = originals.map {
            bestTimedMatch(for: $0, in: romanizations)
        }
        guard mapping.allSatisfy({ $0 != nil }) else { return nil }
        let indices = mapping.compactMap { $0 }
        guard indices == indices.sorted(),
              Set(indices) == Set(romanizations.indices) else {
            return nil
        }

        var result: [UnitDraft] = []
        var lowerBound = originals.startIndex
        while lowerBound < originals.endIndex {
            let romanizationIndex = indices[lowerBound]
            var upperBound = lowerBound + 1
            while upperBound < originals.endIndex,
                  indices[upperBound] == romanizationIndex {
                upperBound += 1
            }

            let group = Array(originals[lowerBound..<upperBound])
            result.append(
                makeUnit(
                    originalText: group.map(\.text).joined(),
                    originalSyllables: group,
                    romanization: normalizedAnnotation(
                        romanizations[romanizationIndex].text
                    ),
                    authoredRomanizationSyllables: [
                        romanizations[romanizationIndex],
                    ]
                )
            )
            lowerBound = upperBound
        }
        return result
    }

    private static func unitsByMappingRomanizations(
        _ romanizations: [LyricSyllable],
        to originals: [LyricSyllable]
    ) -> [UnitDraft]? {
        let mapping = romanizations.map {
            bestTimedMatch(for: $0, in: originals)
        }
        guard mapping.allSatisfy({ $0 != nil }) else { return nil }
        let indices = mapping.compactMap { $0 }
        guard indices == indices.sorted(),
              Set(indices) == Set(originals.indices) else {
            return nil
        }

        var romanizationsByOriginal: [Int: [LyricSyllable]] = [:]
        for (romanization, originalIndex) in zip(romanizations, indices) {
            romanizationsByOriginal[originalIndex, default: []]
                .append(romanization)
        }

        return originals.enumerated().map { index, original in
            let authoredRomanizations =
                romanizationsByOriginal[index, default: []]
            let romanization = authoredRomanizations
                .map(\.text)
                .joined()
            return makeUnit(
                originalText: original.text,
                originalSyllables: [original],
                romanization: normalizedAnnotation(romanization),
                authoredRomanizationSyllables: authoredRomanizations
            )
        }
    }

    private static func bestTimedMatch(
        for source: LyricSyllable,
        in candidates: [LyricSyllable]
    ) -> Int? {
        let match = candidates.indices.min { left, right in
            temporalDistance(source, candidates[left])
                < temporalDistance(source, candidates[right])
        }
        guard let match,
              temporalDistance(source, candidates[match])
                <= timingTolerance(for: source, and: candidates[match]) else {
            return nil
        }
        return match
    }

    private static func temporalDistance(
        _ lhs: LyricSyllable,
        _ rhs: LyricSyllable
    ) -> TimeInterval {
        let overlap = min(lhs.endTime, rhs.endTime)
            - max(lhs.startTime, rhs.startTime)
        if overlap >= 0 {
            let lhsMidpoint = (lhs.startTime + lhs.endTime) / 2
            let rhsMidpoint = (rhs.startTime + rhs.endTime) / 2
            return abs(lhsMidpoint - rhsMidpoint) * 0.15
        }
        return max(lhs.startTime, rhs.startTime)
            - min(lhs.endTime, rhs.endTime)
    }

    private static func timingTolerance(
        for lhs: LyricSyllable,
        and rhs: LyricSyllable
    ) -> TimeInterval {
        let longestDuration = max(
            lhs.endTime - lhs.startTime,
            rhs.endTime - rhs.startTime
        )
        return max(min(longestDuration * 0.75, 0.55), 0.18)
    }

    private static func segmentedUnits(
        originalText: String,
        originalSyllables: [LyricSyllable],
        romanization: String
    ) -> [UnitDraft]? {
        let tokens = romanization
            .split(whereSeparator: \Character.isWhitespace)
            .map(String.init)
        guard !tokens.isEmpty else { return nil }

        if originalSyllables.count == tokens.count,
           originalSyllables.map(\.text).joined() == originalText {
            return zip(originalSyllables, tokens).map { syllable, token in
                makeUnit(
                    originalText: syllable.text,
                    originalSyllables: [syllable],
                    romanization: token
                )
            }
        }

        if let phoneticRanges = phoneticCharacterRanges(
            in: originalText,
            matching: tokens
        ) {
            return units(
                originalText: originalText,
                originalSyllables: originalSyllables,
                ranges: phoneticRanges,
                annotations: tokens
            )
        }

        let wordRanges = LyricWordSegmenter.blockRanges(in: originalText)
        if wordRanges.count == tokens.count {
            return units(
                originalText: originalText,
                originalSyllables: originalSyllables,
                ranges: wordRanges,
                annotations: tokens
            )
        }

        let characterRanges = annotationCharacterRanges(in: originalText)
        if characterRanges.count == tokens.count {
            return units(
                originalText: originalText,
                originalSyllables: originalSyllables,
                ranges: characterRanges,
                annotations: tokens
            )
        }
        return proportionallyAlignedUnits(
            originalText: originalText,
            originalSyllables: originalSyllables,
            annotations: tokens
        )
    }

    private static func phoneticCharacterRanges(
        in text: String,
        matching annotations: [String]
    ) -> [Range<Int>]? {
        let characters = Array(text)
        guard !characters.isEmpty,
              annotations.count <= characters.count else {
            return nil
        }

        var successfulMatches: [
            PhoneticMatchState: [Range<Int>]
        ] = [:]
        var failedMatches: Set<PhoneticMatchState> = []
        func match(
            characterOffset: Int,
            annotationOffset: Int
        ) -> [Range<Int>]? {
            let state = PhoneticMatchState(
                characterOffset: characterOffset,
                annotationOffset: annotationOffset
            )
            if let cached = successfulMatches[state] {
                return cached
            }
            guard !failedMatches.contains(state) else { return nil }
            guard annotationOffset < annotations.count else {
                let result: [Range<Int>]? =
                    characterOffset == characters.count ? [] : nil
                if let result {
                    successfulMatches[state] = result
                } else {
                    failedMatches.insert(state)
                }
                return result
            }

            let remainingAnnotations =
                annotations.count - annotationOffset - 1
            let maximumUpperBound =
                characters.count - remainingAnnotations
            guard characterOffset < maximumUpperBound else {
                failedMatches.insert(state)
                return nil
            }

            let normalizedAnnotation = normalizedLatin(
                annotations[annotationOffset]
            )
            for upperBound in
                (characterOffset + 1)...maximumUpperBound {
                let source = String(
                    characters[characterOffset..<upperBound]
                )
                guard normalizedLatin(
                    source.applyingTransform(
                        .toLatin,
                        reverse: false
                    ) ?? source
                ) == normalizedAnnotation else {
                    continue
                }

                if let suffix = match(
                    characterOffset: upperBound,
                    annotationOffset: annotationOffset + 1
                ) {
                    let result =
                        [characterOffset..<upperBound] + suffix
                    successfulMatches[state] = result
                    return result
                }
            }
            failedMatches.insert(state)
            return nil
        }

        return match(characterOffset: 0, annotationOffset: 0)
    }

    private static func proportionallyAlignedUnits(
        originalText: String,
        originalSyllables: [LyricSyllable],
        annotations: [String]
    ) -> [UnitDraft] {
        let characters = Array(originalText)
        guard !characters.isEmpty else { return [] }

        let baseRanges = annotationCharacterRanges(in: originalText)
        guard !baseRanges.isEmpty else {
            return [
                makeUnit(
                    originalText: originalText,
                    originalSyllables: originalSyllables,
                    romanization: annotations.joined(separator: " ")
                ),
            ]
        }

        if annotations.count <= baseRanges.count {
            let annotationWeights = annotations.map {
                max(normalizedLatin($0).count, 1)
            }
            let groupedRanges = partitionOriginalCharacters(
                count: characters.count,
                weights: annotationWeights
            )
            return units(
                originalText: originalText,
                originalSyllables: originalSyllables,
                ranges: groupedRanges,
                annotations: annotations
            )
        }

        var baseWeights: [Int] = []
        baseWeights.reserveCapacity(baseRanges.count)
        for range in baseRanges {
            let text = String(characters[range])
            var weight = 1
            for character in text {
                if isCJKIdeograph(character) {
                    weight = 2
                    break
                }
            }
            baseWeights.append(weight)
        }
        let annotationRanges = partitionAnnotations(
            count: annotations.count,
            weights: baseWeights
        )
        let groupedAnnotations = annotationRanges.map { range in
            annotations[range].joined(separator: " ")
        }
        return units(
            originalText: originalText,
            originalSyllables: originalSyllables,
            ranges: baseRanges,
            annotations: groupedAnnotations
        )
    }

    private static func partitionOriginalCharacters(
        count: Int,
        weights: [Int]
    ) -> [Range<Int>] {
        partition(count: count, weights: weights)
    }

    private static func partitionAnnotations(
        count: Int,
        weights: [Int]
    ) -> [Range<Int>] {
        partition(count: count, weights: weights)
    }

    private static func partition(
        count: Int,
        weights: [Int]
    ) -> [Range<Int>] {
        guard count > 0, !weights.isEmpty else { return [] }
        let totalWeight = max(weights.reduce(0, +), 1)
        var result: [Range<Int>] = []
        var lowerBound = 0
        var cumulativeWeight = 0

        for (index, weight) in weights.enumerated() {
            cumulativeWeight += weight
            let remainingGroups = weights.count - index - 1
            let idealUpperBound = Int(
                (Double(count) * Double(cumulativeWeight)
                    / Double(totalWeight)).rounded()
            )
            let minimumUpperBound = lowerBound + 1
            let maximumUpperBound = count - remainingGroups
            let upperBound = index == weights.count - 1
                ? count
                : min(
                    max(idealUpperBound, minimumUpperBound),
                    maximumUpperBound
                )
            result.append(lowerBound..<upperBound)
            lowerBound = upperBound
        }
        return result
    }

    private static func units(
        originalText: String,
        originalSyllables: [LyricSyllable],
        ranges: [Range<Int>],
        annotations: [String]
    ) -> [UnitDraft] {
        let characters = Array(originalText)
        let timedCharacters = characterSyllables(
            for: originalText,
            from: originalSyllables
        )

        return zip(ranges, annotations).map { range, annotation in
            let text = String(characters[range])
            let syllables = timedCharacters.map {
                Array($0[range])
            } ?? []
            return makeUnit(
                originalText: text,
                originalSyllables: syllables,
                romanization: annotation
            )
        }
    }

    private static func annotationCharacterRanges(
        in text: String
    ) -> [Range<Int>] {
        let characters = Array(text)
        let annotatedIndices = characters.indices.filter {
            !characters[$0].isWhitespace
        }
        return annotatedIndices.enumerated().map { offset, index in
            let lowerBound = offset == 0 ? characters.startIndex : index
            let upperBound = offset + 1 < annotatedIndices.count
                ? annotatedIndices[offset + 1]
                : characters.endIndex
            return lowerBound..<upperBound
        }
    }

    private static func characterSyllables(
        for text: String,
        from syllables: [LyricSyllable]
    ) -> [LyricSyllable]? {
        guard !syllables.isEmpty,
              syllables.map(\.text).joined() == text else {
            return nil
        }

        return syllables.flatMap { syllable -> [LyricSyllable] in
            let characters = Array(syllable.text)
            guard !characters.isEmpty else { return [] }

            let duration = max(
                syllable.endTime - syllable.startTime,
                0
            )
            let characterDuration = duration / Double(characters.count)
            return characters.enumerated().map { offset, character in
                let startTime = syllable.startTime
                    + Double(offset) * characterDuration
                let endTime = offset == characters.count - 1
                    ? syllable.endTime
                    : startTime + characterDuration
                return LyricSyllable(
                    text: String(character),
                    startTime: startTime,
                    endTime: max(endTime, startTime)
                )
            }
        }
    }

    private static func makeUnit(
        originalText: String,
        originalSyllables: [LyricSyllable],
        romanization: String?,
        authoredRomanizationSyllables: [LyricSyllable] = []
    ) -> UnitDraft {
        let normalizedRomanization: String?
        if let romanization {
            normalizedRomanization = normalizedAnnotation(romanization)
        } else {
            normalizedRomanization = nil
        }
        let normalizedAuthoredSyllables =
            normalizedRomanization == nil
                ? []
                : normalizedSyllables(authoredRomanizationSyllables)

        return UnitDraft(
            originalText: originalText,
            originalSyllables: originalSyllables,
            romanizationText: normalizedRomanization,
            romanizationSyllables: normalizedAuthoredSyllables,
            hasAuthoredRomanizationTiming:
                !normalizedAuthoredSyllables.isEmpty
        )
    }

    private static func normalizedSyllables(
        _ syllables: [LyricSyllable]
    ) -> [LyricSyllable] {
        guard let first = syllables.firstIndex(where: {
            normalizedAnnotation($0.text) != nil
        }), let last = syllables.lastIndex(where: {
            normalizedAnnotation($0.text) != nil
        }) else {
            return []
        }

        // Match the displayed unit's trimmed text without changing authored
        // timings or removing spaces between syllables inside the unit.
        return (first...last).compactMap { index in
            let syllable = syllables[index]
            var text = syllable.text
            if index == first {
                text = String(text.drop(while: \.isWhitespace))
            }
            if index == last {
                text = String(
                    text.reversed()
                        .drop(while: \.isWhitespace)
                        .reversed()
                )
            }
            guard !text.isEmpty else { return nil }
            return LyricSyllable(
                text: text,
                startTime: syllable.startTime,
                endTime: syllable.endTime
            )
        }
    }

    private static func numbered(
        _ units: [UnitDraft]
    ) -> [LyricRubyUnit] {
        units.enumerated().map { index, unit in
            LyricRubyUnit(
                id: index,
                originalText: unit.originalText,
                originalSyllables: unit.originalSyllables,
                romanizationText: unit.romanizationText,
                romanizationSyllables: unit.romanizationSyllables,
                hasAuthoredRomanizationTiming:
                    unit.hasAuthoredRomanizationTiming
            )
        }
    }

    private static func normalizedAnnotation(
        _ text: String?
    ) -> String? {
        let text = text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    private static func normalizedLatin(
        _ text: String
    ) -> String {
        text
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive,
                    .widthInsensitive,
                ],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
            .lowercased()
    }

    private static func isCJKIdeograph(
        _ character: Character
    ) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF,
                 0x20000...0x2FA1F:
                true
            default:
                false
            }
        }
    }
}

private struct UnitDraft {
    let originalText: String
    let originalSyllables: [LyricSyllable]
    let romanizationText: String?
    let romanizationSyllables: [LyricSyllable]
    let hasAuthoredRomanizationTiming: Bool
}

private struct PhoneticMatchState: Hashable {
    let characterOffset: Int
    let annotationOffset: Int
}

private final class LyricRomanizationAlignmentCache:
    @unchecked Sendable
{
    struct Key: Hashable {
        let originalText: String
        let romanization: String
        let originalSyllables: [LyricSyllable]
        let romanizationSyllables: [LyricSyllable]
    }

    private let lock = NSLock()
    private var storage: [Key: [LyricRubyUnit]] = [:]
    private var insertionOrder: [Key] = []
    private let capacity = 256

    func units(for key: Key) -> [LyricRubyUnit]? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func insert(
        _ units: [LyricRubyUnit],
        for key: Key
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard storage[key] == nil else { return }

        storage[key] = units
        insertionOrder.append(key)
        if insertionOrder.count > capacity {
            let expiredKey = insertionOrder.removeFirst()
            storage.removeValue(forKey: expiredKey)
        }
    }
}
