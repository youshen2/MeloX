import SwiftUI

struct SkylineCentralLyricsView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let lyrics: [LyricLine]
    let activeIndex: Int
    let usesPseudoTiming: Bool
    let fontScale: CGFloat
    let currentLyricFontSize: CGFloat
    let nextLyricFontSize: CGFloat
    let nextLyricOpacity: Double
    let spacing: CGFloat
    let size: CGSize
    let accentColor: Color
    let maximumPlaybackScale: CGFloat

    private struct Entry: Identifiable {
        let line: LyricLine
        let index: Int
        var id: LyricLine.ID { line.id }
    }

    var body: some View {
        SkylineLyricsLayout(
            size: size,
            previewScale: previewScale,
            maximumPlaybackScale: maximumPlaybackScale,
            spacing: spacing,
            outgoingTravel: max(currentLyricFontSize * 0.55, 28)
        ) {
            ForEach(visibleLines) { entry in
                let role = role(at: entry.index)

                SkylineCentralLyricText(
                    line: entry.line,
                    role: role,
                    focus: role == .next ? 0 : 1,
                    usesPseudoTiming: usesPseudoTiming,
                    fontScale: fontScale,
                    fontSize: currentLyricFontSize,
                    width: size.width,
                    accentColor: accentColor,
                    maximumPlaybackScale: maximumPlaybackScale,
                    entranceDuration: entranceDuration(at: entry.index)
                )
                .scaleEffect(role == .next ? previewScale : 1)
                .blur(radius: role == .previous ? max(currentLyricFontSize * 0.12, 7) : 0)
                .opacity(opacity(for: role))
                .layoutValue(key: SkylineLyricRoleKey.self, value: role)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(
                            with: .offset(y: max(nextLyricFontSize * 3.4, 72))
                        ),
                        removal: .opacity
                    )
                )
            }
        }
        .animation(
            accessibilityReduceMotion
                ? nil
                : .smooth(duration: entranceDuration(at: activeIndex)),
            value: lyrics[activeIndex].id
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("ui.lyrics.current")
    }

    private var visibleLines: [Entry] {
        let firstIndex = max(activeIndex - 1, lyrics.startIndex)
        let lastIndex = min(activeIndex + 1, lyrics.endIndex - 1)
        return (firstIndex...lastIndex).map { Entry(line: lyrics[$0], index: $0) }
    }

    private var previewScale: CGFloat {
        nextLyricFontSize / currentLyricFontSize
    }

    private var accessibilityLabel: String {
        let line = lyrics[activeIndex]
        guard lyrics.indices.contains(activeIndex + 1) else { return line.text }
        return L10n.format(
            "ui.lyrics.current_and_next",
            line.text,
            lyrics[activeIndex + 1].text
        )
    }

    private func role(at index: Int) -> SkylineLyricRole {
        if index < activeIndex { return .previous }
        return index == activeIndex ? .current : .next
    }

    private func opacity(for role: SkylineLyricRole) -> Double {
        switch role {
        case .previous: 0
        case .current: 1
        case .next: nextLyricOpacity
        }
    }

    private func entranceDuration(at index: Int) -> TimeInterval {
        let duration = lyrics.indices.contains(index + 1)
            ? lyrics[index + 1].time - lyrics[index].time
            : lyrics[index].duration
        guard let duration, duration.isFinite, duration > 0 else { return 0.46 }
        return min(max(duration * 0.72, 0.06), 0.46)
    }
}

private struct SkylineCentralLyricText: View, Animatable {
    @Environment(AppSettings.self) private var settings

    let line: LyricLine
    let role: SkylineLyricRole
    var focus: CGFloat
    let usesPseudoTiming: Bool
    let fontScale: CGFloat
    let fontSize: CGFloat
    let width: CGFloat
    let accentColor: Color
    let maximumPlaybackScale: CGFloat
    let entranceDuration: TimeInterval

    var animatableData: CGFloat {
        get { focus }
        set { focus = newValue }
    }

    var body: some View {
        // One renderer, font and wrapping width follow a line from preview
        // through playback and departure. Only drawing properties animate.
        SynchronizedLyricText(
            line: line,
            isPlaybackLine: role == .current,
            isVocalActive: role != .next,
            isAnimationActive: role == .current,
            playbackFocusProgress: focus,
            usesPseudoTiming: usesPseudoTiming,
            fontSize: fontSize,
            fontWeight: settings.lyricsFontWeight,
            alignment: .center,
            fontScale: fontScale,
            primaryColor: .white.mix(
                with: accentColor,
                by: Double(focus),
                in: .perceptual
            ),
            showsTranslation: false,
            showsRomanization: false,
            includesTranslation: false,
            includesRomanization: false,
            layoutWidth: width,
            playbackScaleRange: 1...max(maximumPlaybackScale, 1),
            playbackScaleStartDelay: entranceDuration
        )
        .frame(width: width)
    }
}
