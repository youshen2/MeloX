import Foundation

enum LyricsTypography {
    static let heavySerifFontName = "SourceHanSerifCN-Heavy"
    static let latinSerifFontName = "TimesNewRomanPS-BoldMT"

    static func normalizedDisplayText(_ source: String) -> String {
        let text = source
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "……" : text
    }

    static func isPredominantlyLatin(_ text: String) -> Bool {
        var visibleCount = 0
        var latinCount = 0

        for scalar in text.unicodeScalars {
            guard !CharacterSet.whitespacesAndNewlines.contains(scalar),
                  !CharacterSet.punctuationCharacters.contains(scalar) else {
                continue
            }
            visibleCount += 1
            if scalar.isASCII, CharacterSet.letters.contains(scalar) {
                latinCount += 1
            }
        }

        guard visibleCount > 0 else { return false }
        return Double(latinCount) / Double(visibleCount) >= 0.7
    }
}
