import SwiftUI

struct SkylineAmbientLyricsView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let line: LyricLine
    let size: CGSize
    let accentColor: Color
    let baseFontSize: CGFloat
    let maximumCharacters: Int
    let maximumVisibleTexts: Int
    let opacityScale: Double
    let blurScale: CGFloat
    let maximumTilt: Double
    let driftScale: CGFloat
    let transitionDuration: TimeInterval

    @State private var items: [SkylineAmbientLyricItem] = []
    @State private var nextItemID = 0
    @State private var hasSeededField = false

    private static let maximumGrowthStage = 3
    private static let maximumNewTextsPerLine = 4

    var body: some View {
        ZStack {
            ForEach(items) { item in
                SkylineAmbientLyricText(
                    item: item,
                    size: size,
                    accentColor: accentColor,
                    baseFontSize: baseFontSize,
                    opacityScale: opacityScale,
                    blurScale: blurScale,
                    driftScale: driftScale
                )
                .transition(Self.textTransition)
            }
        }
        .accessibilityHidden(true)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.06),
                    .init(color: .black, location: 0.92),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .task(id: line.id) {
            advanceField()
        }
        .onChange(of: maximumVisibleTexts) { _, maximumVisibleTexts in
            trimToVisibleLimit(maximumVisibleTexts)
        }
    }

    private static var textTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: SkylineAmbientChangeModifier(
                    blurRadius: 12,
                    opacity: 0,
                    scale: 0.72
                ),
                identity: SkylineAmbientChangeModifier(
                    blurRadius: 0,
                    opacity: 1,
                    scale: 1
                )
            ),
            removal: .modifier(
                active: SkylineAmbientChangeModifier(
                    blurRadius: 9,
                    opacity: 0,
                    scale: 1.2
                ),
                identity: SkylineAmbientChangeModifier(
                    blurRadius: 0,
                    opacity: 1,
                    scale: 1
                )
            )
        )
    }

    private func advanceField() {
        var nextItems = items.compactMap { item -> SkylineAmbientLyricItem? in
            guard item.growthStage < Self.maximumGrowthStage else { return nil }
            var grownItem = item
            grownItem.growthStage += 1
            return grownItem
        }
        nextItems.append(contentsOf: makeNewItems())
        nextItems = Array(nextItems.suffix(max(maximumVisibleTexts, 1)))

        let animation: Animation? = hasSeededField && !accessibilityReduceMotion
            ? .smooth(duration: transitionDuration)
            : nil
        withAnimation(animation) {
            items = nextItems
            hasSeededField = true
        }
    }

    private func makeNewItems() -> [SkylineAmbientLyricItem] {
        var randomGenerator = SystemRandomNumberGenerator()

        return selectedFragments().map { fragment in
            defer { nextItemID += 1 }

            let identifier = nextItemID
            let seed = UInt64(identifier + 1) &* 0x9E3779B97F4A7C15
            let randomX = CGFloat.random(in: 0...1, using: &randomGenerator)
            let randomY = CGFloat.random(in: 0...1, using: &randomGenerator)
            let scaleVariation = 0.82
                + DeterministicRandom.unit(seed ^ 0xBF58476D1CE4E5B9) * 0.36
            let opacityVariation = 0.15
                + Double(DeterministicRandom.unit(seed ^ 0xD6E8FEB86659FD93)) * 0.09
            let signedRotation = Double(
                DeterministicRandom.unit(seed ^ 0xA0761D6478BD642F)
            ) * 2 - 1
            let driftDirectionX: CGFloat = randomX < 0.5 ? 1 : -1
            let driftDirectionY: CGFloat = randomY < 0.5 ? -1 : 1

            return SkylineAmbientLyricItem(
                id: identifier,
                text: fragment,
                x: randomX,
                y: randomY,
                baseScale: scaleVariation,
                baseOpacity: opacityVariation,
                rotation: signedRotation * maximumTilt,
                driftX: driftDirectionX
                    * (6 + DeterministicRandom.unit(seed ^ 0xE7037ED1A0B428DB) * 12),
                driftY: driftDirectionY
                    * (2 + DeterministicRandom.unit(seed ^ 0x8EBC6AF09C88C6E3) * 4),
                growthStage: 0
            )
        }
    }

    private func selectedFragments() -> [String] {
        let fragments = lyricFragments(from: line.text)
        guard fragments.count > Self.maximumNewTextsPerLine else {
            return fragments
        }

        let stride = Double(fragments.count)
            / Double(Self.maximumNewTextsPerLine)
        return (0..<Self.maximumNewTextsPerLine).map { index in
            fragments[min(Int(Double(index) * stride), fragments.count - 1)]
        }
    }

    private func lyricFragments(from text: String) -> [String] {
        let fragmentLength = max(maximumCharacters, 1)
        let groups = text.split { character in
            character.isWhitespace || character.isPunctuation
        }

        return groups.flatMap { group in
            let characters = Array(group)
            return stride(
                from: characters.startIndex,
                to: characters.endIndex,
                by: fragmentLength
            ).map { startIndex in
                let endIndex = min(
                    startIndex + fragmentLength,
                    characters.endIndex
                )
                return String(characters[startIndex..<endIndex])
            }
        }
    }

    private func trimToVisibleLimit(_ limit: Int) {
        guard items.count > limit else { return }
        withAnimation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.35)) {
            items = Array(items.suffix(max(limit, 1)))
        }
    }

}

private struct SkylineAmbientLyricText: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let item: SkylineAmbientLyricItem
    let size: CGSize
    let accentColor: Color
    let baseFontSize: CGFloat
    let opacityScale: Double
    let blurScale: CGFloat
    let driftScale: CGFloat

    @State private var isDrifting = false

    var body: some View {
        Text(verbatim: item.text)
            .font(.system(size: baseFontSize, weight: .bold))
            .foregroundStyle(
                accentColor.opacity(item.visibleOpacity * opacityScale)
            )
            .blur(radius: item.blurRadius * blurScale)
            .scaleEffect(item.baseScale * item.growthScale)
            .rotationEffect(.degrees(item.rotation))
            .position(x: size.width * item.x, y: size.height * item.y)
            .offset(
                x: item.driftX * driftScale * driftDirection,
                y: item.driftY * driftScale * driftDirection
            )
            .onAppear {
                startDrifting()
            }
            .onChange(of: accessibilityReduceMotion) { _, reduceMotion in
                guard reduceMotion else {
                    startDrifting()
                    return
                }
                withAnimation(nil) {
                    isDrifting = false
                }
            }
    }

    private var driftDirection: CGFloat {
        isDrifting ? 1 : -1
    }

    private func startDrifting() {
        guard !accessibilityReduceMotion else { return }
        withAnimation(
            .easeInOut(duration: 9)
                .repeatForever(autoreverses: true)
        ) {
            isDrifting = true
        }
    }
}

private struct SkylineAmbientLyricItem: Identifiable {
    let id: Int
    let text: String
    let x: CGFloat
    let y: CGFloat
    let baseScale: CGFloat
    let baseOpacity: Double
    let rotation: Double
    let driftX: CGFloat
    let driftY: CGFloat
    var growthStage: Int

    var growthScale: CGFloat {
        switch growthStage {
        case 0: 0.78
        case 1: 1
        case 2: 1.26
        default: 1.6
        }
    }

    var blurRadius: CGFloat {
        switch growthStage {
        case 0: 0.4
        case 1: 1.1
        case 2: 2.4
        default: 4.6
        }
    }

    var visibleOpacity: Double {
        switch growthStage {
        case 0: baseOpacity
        case 1: baseOpacity * 0.86
        case 2: baseOpacity * 0.62
        default: baseOpacity * 0.36
        }
    }
}

private struct SkylineAmbientChangeModifier: ViewModifier {
    let blurRadius: CGFloat
    let opacity: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: blurRadius)
            .opacity(opacity)
            .scaleEffect(scale)
    }
}
