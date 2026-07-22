import SwiftUI

struct TextPV1TextBlock: Identifiable {
    let id: Int
    let text: String
    let position: UnitPoint
    let width: CGFloat
    let fontScale: CGFloat
    let rotation: Angle
}

enum TextPV1TextLayoutEngine {
    static func blocks(
        for source: String,
        scene: TextPV1Scene,
        seed: UInt64
    ) -> [TextPV1TextBlock] {
        let fragments = fragments(for: normalized(source))
        return fragments.enumerated().map { index, fragment in
            descriptor(
                text: fragment,
                index: index,
                count: fragments.count,
                scene: scene,
                seed: seed
            )
        }
    }

    private static func descriptor(
        text: String,
        index: Int,
        count: Int,
        scene: TextPV1Scene,
        seed: UInt64
    ) -> TextPV1TextBlock {
        let safeCount = max(count, 1)
        let position = safeCount == 1
            ? CGFloat(0.5)
            : CGFloat(index) / CGFloat(safeCount - 1)
        let jitter = TextPV1StableSeed.unit(index + 70, seed: seed) - 0.5
        let baseFontScale: CGFloat = safeCount <= 2
            ? 0.34
            : safeCount <= 5 ? 0.27 : 0.2

        switch scene {
        case .impactDark:
            return TextPV1TextBlock(
                id: index,
                text: text,
                position: UnitPoint(
                    x: 0.12 + position * 0.76,
                    y: 0.48 + sin(CGFloat(index) * 1.72) * 0.13
                ),
                width: safeCount == 1 ? 0.9 : min(0.48, 1.45 / CGFloat(safeCount)),
                fontScale: baseFontScale * (0.92 + abs(jitter) * 0.34),
                rotation: .degrees(Double(jitter * 12))
            )
        case .editorialWhite:
            let columns = safeCount > 4 ? 3 : 2
            let rows = Int(ceil(Double(safeCount) / Double(columns)))
            let column = index % columns
            let row = index / columns
            let x = columns == 2
                ? 0.3 + CGFloat(column) * 0.4
                : 0.2 + CGFloat(column) * 0.3
            let y = rows == 1
                ? 0.48
                : 0.25 + CGFloat(row) / CGFloat(max(rows - 1, 1)) * 0.46
            return TextPV1TextBlock(
                id: index,
                text: text,
                position: UnitPoint(x: x + jitter * 0.035, y: y),
                width: columns == 2 ? 0.44 : 0.31,
                fontScale: baseFontScale * 0.98,
                rotation: .degrees(Double(jitter * 8))
            )
        case .aperture:
            let alternating = CGFloat(index.isMultiple(of: 2) ? -1 : 1)
            return TextPV1TextBlock(
                id: index,
                text: text,
                position: UnitPoint(
                    x: 0.34 + position * 0.32 + alternating * 0.035,
                    y: 0.29 + position * 0.4
                ),
                width: safeCount == 1 ? 0.78 : min(0.48, 1.6 / CGFloat(safeCount)),
                fontScale: baseFontScale * 1.02,
                rotation: .degrees(Double(alternating * (5 + abs(jitter) * 12)))
            )
        case .wireframe:
            let alternating = CGFloat(index.isMultiple(of: 2) ? -1 : 1)
            return TextPV1TextBlock(
                id: index,
                text: text,
                position: UnitPoint(
                    x: 0.24 + position * 0.53,
                    y: 0.23 + position * 0.5 + alternating * 0.045
                ),
                width: safeCount == 1 ? 0.84 : min(0.46, 1.5 / CGFloat(safeCount)),
                fontScale: baseFontScale,
                rotation: .degrees(Double(jitter * 15 - 4))
            )
        case .splitScreen:
            let columns = safeCount > 4 ? 3 : 2
            let column = index % columns
            let row = index / columns
            let rowCount = Int(ceil(Double(safeCount) / Double(columns)))
            return TextPV1TextBlock(
                id: index,
                text: text,
                position: UnitPoint(
                    x: 0.2 + CGFloat(column) * (columns == 2 ? 0.38 : 0.25),
                    y: rowCount == 1
                        ? 0.48
                        : 0.26 + CGFloat(row) / CGFloat(max(rowCount - 1, 1)) * 0.46
                ),
                width: columns == 2 ? 0.38 : 0.27,
                fontScale: baseFontScale * 0.94,
                rotation: .degrees(Double(jitter * 5))
            )
        case .verticalColumns:
            let alternating = CGFloat(index.isMultiple(of: 2) ? -1 : 1)
            return TextPV1TextBlock(
                id: index,
                text: text,
                position: UnitPoint(
                    x: 0.16 + position * 0.68,
                    y: 0.48 + alternating * (0.12 + abs(jitter) * 0.08)
                ),
                width: safeCount == 1 ? 0.82 : min(0.34, 1.25 / CGFloat(safeCount)),
                fontScale: baseFontScale * 0.96,
                rotation: .degrees(
                    safeCount <= 3
                        ? Double(alternating * 7)
                        : Double(alternating * 90)
                )
            )
        case .targetLock:
            guard safeCount > 1 else {
                return TextPV1TextBlock(
                    id: index,
                    text: text,
                    position: .center,
                    width: 0.82,
                    fontScale: 0.36,
                    rotation: .zero
                )
            }
            let angle = position * 2 * .pi - .pi / 2
            let radius: CGFloat = safeCount > 5 ? 0.27 : 0.22
            return TextPV1TextBlock(
                id: index,
                text: text,
                position: UnitPoint(
                    x: 0.5 + cos(angle) * radius,
                    y: 0.48 + sin(angle) * radius
                ),
                width: min(0.36, 1.38 / CGFloat(safeCount)),
                fontScale: baseFontScale * 0.92,
                rotation: .degrees(Double(angle * 10 + jitter * 8))
            )
        case .staggeredBands:
            let row = index % 2
            let column = index / 2
            let columnCount = Int(ceil(Double(safeCount) / 2))
            let columnProgress = columnCount == 1
                ? CGFloat(0.5)
                : CGFloat(column) / CGFloat(columnCount - 1)
            return TextPV1TextBlock(
                id: index,
                text: text,
                position: UnitPoint(
                    x: 0.18 + columnProgress * 0.64 + CGFloat(row) * 0.035,
                    y: row == 0 ? 0.34 : 0.64
                ),
                width: min(0.42, 1.28 / CGFloat(max(columnCount, 1))),
                fontScale: baseFontScale * (row == 0 ? 1.02 : 0.9),
                rotation: .degrees(Double(jitter * 6))
            )
        }
    }

    private static func fragments(for text: String) -> [String] {
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if words.count > 1, words.count <= 8 {
            return words
        }

        let characters = Array(text.filter { !$0.isWhitespace })
        guard characters.count > 1 else { return [text] }
        let chunkSize = max(Int(ceil(Double(characters.count) / 8)), 1)
        return stride(from: 0, to: characters.count, by: chunkSize).map { start in
            let end = min(start + chunkSize, characters.count)
            return String(characters[start..<end])
        }
    }

    private static func normalized(_ source: String) -> String {
        let text = source
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "……" : text
    }
}

struct TextPV1KineticTextLayer: View {
    let text: String
    let scene: TextPV1Scene
    let motion: TextPV1MotionFrame
    let fontScale: CGFloat
    let intensity: CGFloat
    let seed: UInt64
    let isClimax: Bool
    let performsFullEntrance: Bool
    let performsFullExit: Bool

    var body: some View {
        GeometryReader { proxy in
            let blocks = TextPV1TextLayoutEngine.blocks(
                for: text,
                scene: scene,
                seed: seed
            )

            ZStack {
                ForEach(blocks) { block in
                    TextPV1KineticTextBlockView(
                        block: block,
                        scene: scene,
                        motion: motion,
                        canvasSize: proxy.size,
                        fontScale: fontScale,
                        intensity: intensity,
                        isClimax: isClimax,
                        performsFullEntrance: performsFullEntrance,
                        performsFullExit: performsFullExit,
                        randomValue: TextPV1StableSeed.unit(
                            block.id + 120,
                            seed: seed
                        )
                    )
                    .zIndex(Double(block.id))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rotation3DEffect(
                .degrees(
                    isClimax
                        ? Double((1 - motion.entry) * 68 * intensity)
                        : 0
                ),
                axis: (x: 0.18, y: 0.82, z: 0.12)
            )
            .rotationEffect(.degrees(globalRotation))
            .scaleEffect(globalScale)
        }
        .accessibilityHidden(true)
    }

    private var globalRotation: Double {
        if isClimax {
            return Double(
                (1 - motion.entry) * -260 * intensity
                    + motion.entryBounce * 52 * intensity
            )
        }
        let bounceDegrees: CGFloat = performsFullEntrance ? 8 : 2.5
        return Double(motion.entryBounce * bounceDegrees * intensity)
    }

    private var globalScale: CGFloat {
        let bounceScale: CGFloat
        if isClimax {
            bounceScale = 0.17
        } else {
            bounceScale = performsFullEntrance ? 0.08 : 0.025
        }
        return 1 + motion.entryBounce * bounceScale * intensity
    }
}

private struct TextPV1KineticTextBlockView: View {
    let block: TextPV1TextBlock
    let scene: TextPV1Scene
    let motion: TextPV1MotionFrame
    let canvasSize: CGSize
    let fontScale: CGFloat
    let intensity: CGFloat
    let isClimax: Bool
    let performsFullEntrance: Bool
    let performsFullExit: Bool
    let randomValue: CGFloat

    var body: some View {
        let minimumSide = min(canvasSize.width, canvasSize.height)
        let effectiveFontScale = min(max(fontScale, 0.76), 1.36)
        let fontSize = max(20, minimumSide * block.fontScale * effectiveFontScale)
        let targetX = canvasSize.width * block.position.x
        let targetY = canvasSize.height * block.position.y
        let angle = randomValue * 2 * .pi
        let climaxBoost: CGFloat = isClimax ? 1.42 : 1
        let entranceStrength: CGFloat = performsFullEntrance ? 1 : 0.16
        let exitStrength: CGFloat = performsFullExit ? 1 : 0.18
        let distance = minimumSide
            * (0.58 + randomValue * 0.48)
            * intensity
            * climaxBoost
        let entryRemainder = 1 - motion.entry
        let exitVector = motion.exit * distance * 0.7 * exitStrength
        let bounceDistance = minimumSide
            * motion.entryBounce
            * (performsFullEntrance ? 0.07 : 0.025)
            * intensity
        let offsetX = cos(angle) * distance * entryRemainder * entranceStrength
            - cos(angle * 1.7) * exitVector
            + cos(angle) * bounceDistance
            + motion.pulse * 2.5 * intensity
        let offsetY = sin(angle) * distance * entryRemainder * entranceStrength
            - sin(angle * 1.7) * exitVector
            + sin(angle) * bounceDistance
            - motion.pulse * 1.6 * intensity
        let entryScale = performsFullEntrance
            ? initialScale
            : (randomValue > 0.5 ? 0.84 : 1.16)
        let boostedEntryScale = isClimax ? entryScale * 1.24 : entryScale
        let scale = (boostedEntryScale + (1 - boostedEntryScale) * motion.entry)
            * (1 + motion.entryKick * 0.36 * intensity)
            * (
                1 + motion.entryBounce
                    * (performsFullEntrance ? 0.18 : 0.07)
                    * intensity
            )
            * (1 + motion.pulse * 0.018 * intensity)
            * (1 - motion.exit * 0.72 * exitStrength)
        let spin = (randomValue - 0.5)
            * 150
            * entryRemainder
            * intensity
            * climaxBoost
            * entranceStrength
            + motion.exit * (randomValue - 0.5) * 110 * exitStrength
            + motion.entryBounce
                * (randomValue - 0.5)
                * (performsFullEntrance ? 34 : 9)
        let opacity = min(motion.entry * 1.8, 1) * (1 - motion.exit)
        let blurRadius = (
            entryRemainder * 15 * intensity * entranceStrength
                + motion.exit * 8 * exitStrength
        ) * climaxBoost

        ZStack {
            blockText(fontSize: fontSize)
                .offset(x: 7 * intensity * climaxBoost, y: -2)
                .opacity(0.2 + abs(motion.pulse) * 0.12)

            blockText(fontSize: fontSize)
                .offset(x: -4 * intensity * climaxBoost, y: 3)
                .opacity(0.16)

            blockText(fontSize: fontSize)
        }
        .frame(
            width: max(canvasSize.width * block.width, 44),
            height: fontSize * 1.36
        )
        .rotation3DEffect(
            .degrees(
                Double(
                    entryRemainder
                        * (randomValue - 0.5)
                        * 72
                        * intensity
                        * entranceStrength
                )
            ),
            axis: (x: 0.18, y: 1, z: 0)
        )
        .rotationEffect(block.rotation + .degrees(Double(spin)))
        .scaleEffect(
            x: isClimax
                ? 1 - motion.transitionActivity * 0.38
                : 1,
            y: isClimax
                ? 1 + motion.transitionActivity * 0.24
                : 1
        )
        .scaleEffect(scale)
        .blur(radius: blurRadius)
        .opacity(opacity)
        .position(x: targetX + offsetX, y: targetY + offsetY)
    }

    private func blockText(fontSize: CGFloat) -> some View {
        Text(verbatim: block.text)
            .font(.custom(fontName, fixedSize: fontSize))
            .tracking(-fontSize * (isLatin ? 0.035 : 0.075))
            .foregroundStyle(scene.foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.24)
            .allowsTightening(true)
            .shadow(
                color: scene.foregroundColor.opacity(scene.isDark ? 0.48 : 0.16),
                radius: scene.isDark ? 7 : 1
            )
    }

    private var initialScale: CGFloat {
        switch scene {
        case .impactDark: 2.9
        case .editorialWhite: 0.08
        case .aperture: 3.4
        case .wireframe: 0.22
        case .splitScreen: 2.2
        case .verticalColumns: 0.12
        case .targetLock: 2.6
        case .staggeredBands: 0.16
        }
    }

    private var isLatin: Bool {
        TextPV1Typography.isPredominantlyLatin(block.text)
    }

    private var fontName: String {
        isLatin ? TextPV1Typography.latinFontName : TextPV1Typography.fontName
    }
}

private enum TextPV1Typography {
    static let fontName = "SourceHanSerifCN-Heavy"
    static let latinFontName = "TimesNewRomanPS-BoldMT"

    static func isPredominantlyLatin(_ text: String) -> Bool {
        let visibleScalars = text.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
                && !CharacterSet.punctuationCharacters.contains($0)
        }
        guard !visibleScalars.isEmpty else { return false }
        let latinScalars = visibleScalars.filter {
            $0.isASCII && CharacterSet.letters.contains($0)
        }
        return Double(latinScalars.count) / Double(visibleScalars.count) >= 0.7
    }
}
