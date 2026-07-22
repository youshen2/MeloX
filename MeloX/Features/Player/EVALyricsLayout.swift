import CoreGraphics
import Foundation

struct EVALyricComposition {
    let blocks: [EVALyricTextBlock]
}

struct EVALyricTextBlock: Identifiable {
    enum Flow {
        case horizontal
        case vertical
    }

    enum Alignment {
        case leading
        case center
        case trailing
    }

    let id: String
    let text: String
    let frame: CGRect
    let flow: Flow
    let alignment: Alignment
    let sizeScale: CGFloat
    let widthScale: CGFloat
}

enum EVALyricLayoutFamily: UInt64 {
    case solo = 0xC2B2AE3D27D4EB4F
    case latin = 0x165667B19E3779F9
    case long = 0x85EBCA77C2B2AE63
    case short = 0x27D4EB2F165667C5
}

enum EVALyricLayoutEngine {
    static func composition(
        for source: String,
        sessionSeed: UInt64,
        sequence: Int
    ) -> EVALyricComposition {
        let text = LyricsTypography.normalizedDisplayText(source)
        let characters = Array(text)
        let family = family(forNormalizedText: text)

        switch family {
        case .solo:
            return soloComposition(
                text: text,
                variant: shuffledVariant(
                    sessionSeed: sessionSeed,
                    sequence: sequence,
                    count: 3,
                    family: family
                )
            )
        case .latin:
            switch shuffledVariant(
                sessionSeed: sessionSeed,
                sequence: sequence,
                count: 3,
                family: family
            ) {
            case 0: return latinComposition(text: text)
            case 1: return centeredLatinComposition(text: text)
            default: return latinPosterComposition(text: text)
            }
        case .long:
            switch shuffledVariant(
                sessionSeed: sessionSeed,
                sequence: sequence,
                count: 3,
                family: family
            ) {
            case 0: return stackedComposition(characters: characters)
            case 1: return bandedComposition(characters: characters)
            default: return columnComposition(characters: characters)
            }
        case .short:
            switch shuffledVariant(
                sessionSeed: sessionSeed,
                sequence: sequence,
                count: 5,
                family: family
            ) {
            case 0: return cornerComposition(characters: characters)
            case 1: return verticalLeadComposition(characters: characters)
            case 2: return horizontalLeadComposition(characters: characters)
            case 3: return offsetComposition(characters: characters)
            default: return centeredVerticalComposition(text: text)
            }
        }
    }

    static func family(for source: String) -> EVALyricLayoutFamily {
        family(forNormalizedText: LyricsTypography.normalizedDisplayText(source))
    }

    static func titleParts(from characters: [Character]) -> (
        leading: String,
        trailing: String
    ) {
        let split = primarySplitIndex(in: characters)
        let leading = cleanedText(characters[..<split])
        let trailingCharacters = Array(characters[split...])
            .drop(while: isSeparator)
        let trailing = cleanedText(trailingCharacters)

        return (
            leading.isEmpty ? String(characters.prefix(1)) : leading,
            trailing.isEmpty ? String(characters.suffix(1)) : trailing
        )
    }

    static func cleanedText<S: Sequence>(_ characters: S) -> String
    where S.Element == Character {
        String(characters)
            .trimmingCharacters(in: separatorCharacterSet.union(.whitespacesAndNewlines))
    }

    private static func primarySplitIndex(in characters: [Character]) -> Int {
        let middle = Double(characters.count) / 2
        let separatorIndices = characters.indices.filter { index in
            index > 0 && index < characters.count - 1 && isSeparator(characters[index])
        }

        if let separatorIndex = separatorIndices.min(by: {
            abs(Double($0) - middle) < abs(Double($1) - middle)
        }) {
            return separatorIndex
        }

        return min(
            max(Int((Double(characters.count) * 0.42).rounded()), 1),
            characters.count - 1
        )
    }

    private static func shuffledVariant(
        sessionSeed: UInt64,
        sequence: Int,
        count: Int,
        family: EVALyricLayoutFamily
    ) -> Int {
        let cycle = sequence / count
        let position = sequence % count
        var order = Array(0..<count)
        var state = DeterministicRandom.splitMix64(
            sessionSeed
                ^ family.rawValue
                ^ UInt64(cycle) &* 0x9E3779B97F4A7C15
        )

        if count > 1 {
            for index in stride(from: count - 1, through: 1, by: -1) {
                state = DeterministicRandom.splitMix64(state &+ UInt64(index))
                let swapIndex = Int(state % UInt64(index + 1))
                order.swapAt(index, swapIndex)
            }
        }
        return order[position]
    }

    private static func family(
        forNormalizedText text: String
    ) -> EVALyricLayoutFamily {
        let characterCount = text.count
        if characterCount == 1 { return .solo }
        if LyricsTypography.isPredominantlyLatin(text), characterCount > 7 { return .latin }
        if characterCount > 14 { return .long }
        return .short
    }

    nonisolated private static func isSeparator(_ character: Character) -> Bool {
        let separators = CharacterSet(charactersIn: "、，,。！？!?；;：:—–-")
        return character.unicodeScalars.allSatisfy(separators.contains)
    }

    private static let separatorCharacterSet = CharacterSet(
        charactersIn: "、，,。！？!?；;：:—–-"
    )
}
