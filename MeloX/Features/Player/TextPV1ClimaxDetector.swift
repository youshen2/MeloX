import Foundation

enum TextPV1ClimaxDetector {
    static func climaxLyricIDs(in lyrics: [LyricLine]) -> Set<LyricLine.ID> {
        guard lyrics.count >= 6 else { return [] }

        let normalizedLines = lyrics.map { normalized($0.text) }
        let frequencies = Dictionary(
            grouping: normalizedLines.indices,
            by: { normalizedLines[$0] }
        )
        let repeatedIndices = Set(
            frequencies.values
                .filter { indices in
                    guard indices.count > 1, let first = indices.first else {
                        return false
                    }
                    return normalizedLines[first].count >= 3
                }
                .flatMap { $0 }
        )

        let densities = lyrics.indices.map { index in
            lyricDensity(at: index, in: lyrics)
        }
        let densityThreshold = percentile(densities, fraction: 0.58)
        var climaxIndices = Set<Int>()

        for index in lyrics.indices {
            let songPosition = Double(index) / Double(max(lyrics.count - 1, 1))
            let isLikelyChorusWindow = (0.3...0.62).contains(songPosition)
                || (0.68...0.92).contains(songPosition)
            let isDense = densities[index] >= densityThreshold

            if repeatedIndices.contains(index) {
                climaxIndices.insert(index)
                if index > lyrics.startIndex {
                    climaxIndices.insert(index - 1)
                }
                if index + 1 < lyrics.endIndex {
                    climaxIndices.insert(index + 1)
                }
            } else if repeatedIndices.isEmpty,
                      isLikelyChorusWindow,
                      isDense {
                climaxIndices.insert(index)
            }
        }

        return Set(climaxIndices.map { lyrics[$0].id })
    }

    private static func lyricDensity(
        at index: Int,
        in lyrics: [LyricLine]
    ) -> Double {
        let line = lyrics[index]
        let duration: TimeInterval
        if index + 1 < lyrics.endIndex {
            duration = max(lyrics[index + 1].time - line.time, 0.35)
        } else {
            duration = max(line.duration ?? 3, 0.35)
        }
        return Double(normalized(line.text).count) / duration
    }

    private static func percentile(
        _ values: [Double],
        fraction: Double
    ) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(
            max(Int((Double(sorted.count - 1) * fraction).rounded()), 0),
            sorted.count - 1
        )
        return sorted[index]
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().unicodeScalars
            .filter {
                !CharacterSet.whitespacesAndNewlines.contains($0)
                    && !CharacterSet.punctuationCharacters.contains($0)
                    && !CharacterSet.symbols.contains($0)
            }
            .map(String.init)
            .joined()
    }
}
