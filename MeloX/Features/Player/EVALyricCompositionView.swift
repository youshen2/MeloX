import SwiftUI

struct EVALyricCompositionView: View {
    let text: String
    let fontScale: CGFloat
    let layoutSeed: UInt64
    let layoutSequence: Int

    var body: some View {
        GeometryReader { proxy in
            let composition = EVALyricLayoutEngine.composition(
                for: text,
                sessionSeed: layoutSeed,
                sequence: layoutSequence
            )

            ZStack(alignment: .topLeading) {
                ForEach(composition.blocks) { block in
                    blockView(block, in: proxy.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    private func blockView(
        _ block: EVALyricTextBlock,
        in canvasSize: CGSize
    ) -> some View {
        let frame = CGRect(
            x: block.frame.minX * canvasSize.width,
            y: block.frame.minY * canvasSize.height,
            width: block.frame.width * canvasSize.width,
            height: block.frame.height * canvasSize.height
        )

        return Group {
            switch block.flow {
            case .horizontal:
                EVAHorizontalTitleText(
                    block: block,
                    size: frame.size,
                    fontScale: fontScale
                )
            case .vertical:
                EVAVerticalTitleText(
                    block: block,
                    size: frame.size,
                    fontScale: fontScale
                )
            }
        }
        .frame(
            width: frame.width,
            height: frame.height,
            alignment: block.swiftUIAlignment
        )
        .position(x: frame.midX, y: frame.midY)
    }
}

private struct EVAHorizontalTitleText: View {
    let block: EVALyricTextBlock
    let size: CGSize
    let fontScale: CGFloat

    var body: some View {
        let scale = min(max(fontScale, 0.78), 1.35)
        let fontSize = size.height * 0.94 * block.sizeScale * scale
        let glyphWidth = isLatin ? 0.63 : 0.94
        let naturalWidth = max(
            fontSize * glyphWidth * CGFloat(max(block.text.count, 1)),
            1
        )
        let fittedWidthScale = min(
            block.widthScale,
            size.width / naturalWidth
        )

        Text(verbatim: block.text)
            .font(.custom(fontName, fixedSize: fontSize))
            .tracking(-fontSize * (isLatin ? 0.035 : 0.065))
            .foregroundStyle(EVATheme.warmWhite)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .scaleEffect(
                x: max(fittedWidthScale, 0.18),
                y: 1,
                anchor: block.unitPoint
            )
            .shadow(color: EVATheme.glow.opacity(0.82), radius: 9)
            .shadow(color: EVATheme.warmWhite.opacity(0.42), radius: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: block.swiftUIAlignment)
    }

    private var isLatin: Bool {
        LyricsTypography.isPredominantlyLatin(block.text)
    }

    private var fontName: String {
        isLatin
            ? LyricsTypography.latinSerifFontName
            : LyricsTypography.heavySerifFontName
    }
}

private struct EVAVerticalTitleText: View {
    let block: EVALyricTextBlock
    let size: CGSize
    let fontScale: CGFloat

    var body: some View {
        let characters = Array(block.text)
        let scale = min(max(fontScale, 0.78), 1.35)
        let fontSize = min(
            size.width * 1.05,
            size.height / CGFloat(max(characters.count, 1)) * 1.14
        ) * block.sizeScale * scale

        VStack(spacing: -fontSize * 0.13) {
            ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                Text(verbatim: String(character))
                    .font(
                        .custom(
                            LyricsTypography.heavySerifFontName,
                            fixedSize: fontSize
                        )
                    )
                    .foregroundStyle(EVATheme.warmWhite)
                    .frame(width: fontSize, height: fontSize)
            }
        }
        .fixedSize()
        .scaleEffect(x: block.widthScale, y: 1, anchor: block.unitPoint)
        .shadow(color: EVATheme.glow.opacity(0.82), radius: 9)
        .shadow(color: EVATheme.warmWhite.opacity(0.42), radius: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: block.swiftUIAlignment)
    }
}

enum EVATheme {
    static let warmWhite = Color(red: 1, green: 0.98, blue: 0.91)
    static let glow = Color(red: 0.88, green: 0.57, blue: 0.12)
}

private extension EVALyricTextBlock {
    var swiftUIAlignment: SwiftUI.Alignment {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var unitPoint: UnitPoint {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}
