import SwiftUI

struct SkylineCentralLyricsView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(AppSettings.self) private var settings

    let line: LyricLine
    let nextLine: LyricLine?
    let usesPseudoTiming: Bool
    let fontScale: CGFloat
    let currentLyricFontSize: CGFloat
    let nextLyricFontSize: CGFloat
    let nextLyricOpacity: Double
    let spacing: CGFloat
    let width: CGFloat
    let accentColor: Color
    let maximumPlaybackScale: CGFloat

    @State private var displayedLine: LyricLine?
    @State private var displayedNextLine: LyricLine?
    @State private var outgoingLine: LyricLine?
    @State private var currentLyricHeight: CGFloat = 0
    @State private var nextLyricHeight: CGFloat = 0
    @State private var promotionSourceHeight: CGFloat = 0
    @State private var currentLyricReveal = 1.0
    @State private var nextLyricReveal = 1.0
    @State private var outgoingLyricProgress = 1.0
    @State private var hasPresentedInitialLine = false

    var body: some View {
        VStack(alignment: .center, spacing: spacing) {
            if let displayedLine {
                SynchronizedLyricText(
                    line: displayedLine,
                    isPlaybackLine: true,
                    usesPseudoTiming: usesPseudoTiming,
                    fontSize: currentLyricFontSize,
                    alignment: .center,
                    fontScale: fontScale,
                    primaryColor: accentColor,
                    showsTranslation: false,
                    layoutWidth: width,
                    playbackScaleRange: 1...max(maximumPlaybackScale, 1),
                    playbackScaleStartDelay: lyricEntranceDuration
                )
                .frame(width: width, alignment: .center)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { height in
                    currentLyricHeight = height
                }
                .scaleEffect(
                    currentLyricStartingScale
                        + (1 - currentLyricStartingScale)
                            * currentLyricReveal,
                    anchor: .center
                )
                .offset(
                    y: currentLyricStartOffset * (1 - currentLyricReveal)
                )
                .opacity(
                    nextLyricOpacity
                        + (1 - nextLyricOpacity) * currentLyricReveal
                )
            }

            if let displayedNextLine {
                Text(verbatim: displayedNextLine.text)
                    .font(
                        .system(
                            size: nextLyricFontSize,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white.opacity(nextLyricOpacity))
                    .multilineTextAlignment(.center)
                    .frame(width: width, alignment: .center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.height
                    } action: { height in
                        nextLyricHeight = height
                    }
                    .offset(
                        y: nextLyricStartOffset * (1 - nextLyricReveal)
                    )
                    .opacity(nextLyricReveal)
            }
        }
        .frame(width: width, alignment: .center)
        .background {
            if let outgoingLine {
                Text(verbatim: outgoingLine.text)
                    .font(
                        .system(
                            size: currentLyricFontSize,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(accentColor)
                    .multilineTextAlignment(.center)
                    .frame(width: width, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .scaleEffect(outgoingLyricScale, anchor: .center)
                    .offset(y: outgoingLyricOffset)
                    .blur(radius: outgoingLyricBlurRadius)
                    .opacity(1 - outgoingLyricProgress)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("当前歌词")
        .task(id: line.id) {
            await presentCurrentLyrics()
        }
        .onChange(of: accessibilityReduceMotion) { _, reduceMotion in
            guard reduceMotion else { return }
            settleAnimations()
        }
    }

    private var accessibilityLabel: String {
        guard let displayedLine else { return "" }
        guard let displayedNextLine else { return displayedLine.text }
        return "\(displayedLine.text)，下一句：\(displayedNextLine.text)"
    }

    private var availableDisplayDuration: TimeInterval? {
        let duration = nextLine.map { $0.time - line.time }
            ?? line.duration
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        return duration
    }

    private var lyricEntranceDuration: TimeInterval {
        guard let availableDisplayDuration else { return 0.46 }
        return min(max(availableDisplayDuration * 0.72, 0.06), 0.46)
    }

    private var currentLyricEntranceAnimation: Animation {
        .spring(duration: lyricEntranceDuration, bounce: 0.06)
    }

    private var nextLyricEntranceAnimation: Animation {
        .easeOut(duration: lyricEntranceDuration)
    }

    private var outgoingLyricAnimation: Animation {
        .easeOut(duration: lyricEntranceDuration)
    }

    private var currentLyricStartingScale: CGFloat {
        min(
            max(nextLyricFontSize / max(currentLyricFontSize, 1), 0.35),
            0.95
        )
    }

    private var currentLyricStartOffset: CGFloat {
        let sourceHeight = max(promotionSourceHeight, nextLyricFontSize)
        return currentLyricHeight * 0.5
            + spacing
            + sourceHeight * 0.5
    }

    private var nextLyricStartOffset: CGFloat {
        max(nextLyricFontSize * 3.4, 72)
    }

    private var outgoingLyricOffset: CGFloat {
        let sourceOffset = -(spacing + promotionSourceHeight) * 0.5
        let upwardTravel = max(currentLyricFontSize * 0.55, 28)
        return sourceOffset - upwardTravel * outgoingLyricProgress
    }

    private var outgoingLyricBlurRadius: CGFloat {
        max(currentLyricFontSize * 0.12, 7) * outgoingLyricProgress
    }

    private var outgoingLyricScale: CGFloat {
        guard !accessibilityReduceMotion,
              let outgoingLine,
              usesTimedLyrics(for: outgoingLine) else {
            return 1
        }
        return max(maximumPlaybackScale, 1)
    }

    private func usesTimedLyrics(for line: LyricLine) -> Bool {
        (settings.lyricsWordByWord && line.isSyllableSynced)
            || (
                usesPseudoTiming
                    && line.duration.map { $0 > 0 } == true
                    && !line.text.isEmpty
            )
    }

    @MainActor
    private func presentCurrentLyrics() async {
        let shouldAnimate = hasPresentedInitialLine
            && !accessibilityReduceMotion
        let sourceHeight = nextLyricHeight
        let previousLine = displayedLine

        withAnimation(nil) {
            outgoingLine = shouldAnimate ? previousLine : nil
            outgoingLyricProgress = shouldAnimate ? 0 : 1
            displayedLine = line
            displayedNextLine = nextLine
            promotionSourceHeight = sourceHeight
            currentLyricReveal = shouldAnimate ? 0 : 1
            nextLyricReveal = shouldAnimate ? 0 : 1
            hasPresentedInitialLine = true
        }

        guard shouldAnimate else { return }

        do {
            try await Task.sleep(for: .milliseconds(16))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        withAnimation(currentLyricEntranceAnimation) {
            currentLyricReveal = 1
        }
        withAnimation(outgoingLyricAnimation) {
            outgoingLyricProgress = 1
        }
        withAnimation(nextLyricEntranceAnimation) {
            nextLyricReveal = 1
        }

        do {
            try await Task.sleep(for: .seconds(lyricEntranceDuration))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        withAnimation(nil) {
            outgoingLine = nil
        }
    }

    private func settleAnimations() {
        withAnimation(nil) {
        currentLyricReveal = 1
        nextLyricReveal = 1
            outgoingLyricProgress = 1
            outgoingLine = nil
        }
    }
}
