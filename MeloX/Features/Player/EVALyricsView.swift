import SwiftUI

struct EVALyricsView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let lyrics: [LyricLine]
    let errorMessage: String?
    let highlightedLyricID: LyricLine.ID?
    let onToggleInterface: (() -> Void)?

    @State private var layoutSessionSeed = UInt64.random(in: 0...UInt64.max)

    var body: some View {
        Group {
            if lyrics.isEmpty {
                emptyState
            } else {
                titleCard
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let errorMessage {
            ContentUnavailableView(
                "暂无歌词",
                systemImage: "rectangle.split.3x1.fill",
                description: Text(errorMessage)
            )
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .contentShape(.rect)
            .onTapGesture {
                onToggleInterface?()
            }
        } else {
            ProgressView("正在载入歌词")
                .tint(.white)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .contentShape(.rect)
                .onTapGesture {
                    onToggleInterface?()
                }
        }
    }

    private var titleCard: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 360
            let horizontalInset = compact ? 16.0 : 20.0

            ZStack {
                Color.black

                VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                    EVALyricCompositionView(
                        text: currentLine.text,
                        fontScale: CGFloat(settings.lyricsFontSize / 26),
                        layoutSeed: layoutSessionSeed,
                        layoutSequence: currentLayoutSequence
                    )
                    .id(currentLine.id)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
                    .gesture(lyricTapGesture(for: currentLine))
                    .accessibilityElement()
                    .accessibilityLabel(
                        currentLine.accessibilityText(
                            includingTranslation: settings.lyricsTranslationEnabled
                        )
                    )
                    .accessibilityValue("当前播放，EVA 标题卡")
                    .accessibilityHint(
                        settings.lyricsTapToSeek
                            ? "双击从这句歌词重新播放"
                            : "歌词跳转已在设置中关闭"
                    )
                    .accessibilityAddTraits(settings.lyricsTapToSeek ? .isButton : [])
                    .accessibilityAction {
                        seek(to: currentLine)
                    }

                    if let footer {
                        EVAFooterLyric(
                            eyebrow: footer.eyebrow,
                            text: footer.text,
                            isTranslation: footer.isTranslation
                        )
                        .contentShape(.rect)
                        .gesture(lyricTapGesture(for: footer.line))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(footer.text)
                        .accessibilityValue(footer.accessibilityValue)
                        .accessibilityHint(
                            settings.lyricsTapToSeek
                                ? footer.accessibilityHint
                                : "歌词跳转已在设置中关闭"
                        )
                        .accessibilityAddTraits(settings.lyricsTapToSeek ? .isButton : [])
                        .accessibilityAction {
                            seek(to: footer.line)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, compact ? 8 : 12)
            }
        }
        .animation(
            accessibilityReduceMotion ? nil : .easeOut(duration: 0.14),
            value: currentLine.id
        )
    }

    private var currentIndex: Int {
        guard let highlightedLyricID,
              let index = lyrics.firstIndex(where: { $0.id == highlightedLyricID }) else {
            return lyrics.startIndex
        }
        return index
    }

    private var currentLine: LyricLine {
        lyrics[currentIndex]
    }

    private var currentLayoutSequence: Int {
        let currentFamily = EVALyricLayoutEngine.family(for: currentLine.text)
        var sequence = 0
        for line in lyrics[..<currentIndex]
        where EVALyricLayoutEngine.family(for: line.text) == currentFamily {
            sequence += 1
        }
        return sequence
    }

    private var nextLine: LyricLine? {
        let index = lyrics.index(after: currentIndex)
        guard index < lyrics.endIndex else { return nil }
        return lyrics[index]
    }

    private var footer: EVAFooterContent? {
        if settings.lyricsTranslationEnabled,
           let translation = currentLine.translation {
            return EVAFooterContent(
                eyebrow: "TRANSLATION",
                text: translation,
                line: currentLine,
                isTranslation: true,
                accessibilityValue: "当前歌词翻译",
                accessibilityHint: "双击从当前歌词重新播放"
            )
        }

        guard let nextLine else { return nil }
        return EVAFooterContent(
            eyebrow: "UP NEXT",
            text: nextLine.text,
            line: nextLine,
            isTranslation: false,
            accessibilityValue: "下一句歌词",
            accessibilityHint: "双击跳转到下一句歌词"
        )
    }

    private func lyricTapGesture(for line: LyricLine) -> some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { gesture in
                switch gesture {
                case .first:
                    seek(to: line)
                case .second:
                    onToggleInterface?()
                }
            }
    }

    private func seek(to line: LyricLine) {
        guard settings.lyricsTapToSeek else { return }
        player.seek(to: line.time)
    }
}

private struct EVAFooterLyric: View {
    let eyebrow: String
    let text: String
    let isTranslation: Bool

    var body: some View {
        Text(verbatim: text)
            .font(
                .custom(
                    LyricsTypography.heavySerifFontName,
                    fixedSize: isTranslation ? 24 : 27
                )
            )
            .tracking(-0.8)
            .foregroundStyle(EVATheme.warmWhite)
            .lineLimit(2)
            .minimumScaleFactor(0.58)
            .allowsTightening(true)
            .shadow(color: EVATheme.glow.opacity(0.72), radius: 7)
            .accessibilityLabel("\(eyebrow)，\(text)")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EVAFooterContent {
    let eyebrow: String
    let text: String
    let line: LyricLine
    let isTranslation: Bool
    let accessibilityValue: String
    let accessibilityHint: String
}
