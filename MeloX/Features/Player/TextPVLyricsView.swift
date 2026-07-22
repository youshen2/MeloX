import SwiftUI

struct TextPVLyricsView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.effectiveLyricsRefreshRate) private var effectiveLyricsRefreshRate
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let lyrics: [LyricLine]
    let errorMessage: String?
    let highlightedLyricID: LyricLine.ID?
    let onToggleInterface: (() -> Void)?

    var body: some View {
        Group {
            if lyrics.isEmpty {
                TextPVEmptyState(
                    errorMessage: errorMessage,
                    onToggleInterface: onToggleInterface
                )
            } else {
                stage
            }
        }
        .background(.black)
    }

    @ViewBuilder
    private var stage: some View {
        let snapshot = makeSnapshot()

        if accessibilityReduceMotion {
            stageFrame(
                snapshot: snapshot,
                playbackTime: snapshot.settledPlaybackTime
            )
        } else {
            TimelineView(
                .animation(
                    minimumInterval: textPVMinimumInterval,
                    paused: !player.isPlaying || settings.textPV.animationSpeed <= 0
                )
            ) { timeline in
                stageFrame(
                    snapshot: snapshot,
                    playbackTime: player.estimatedProgress(at: timeline.date)
                        + settings.lyricsAdvanceTime
                )
            }
        }
    }

    private var textPVMinimumInterval: TimeInterval {
        max(effectiveLyricsRefreshRate.minimumInterval, 1.0 / 60.0)
    }

    private func stageFrame(
        snapshot: TextPVFrameSnapshot,
        playbackTime: TimeInterval
    ) -> some View {
        TextPVStageView(
            frame: snapshot.renderContext(
                at: playbackTime,
                animationSpeed: CGFloat(settings.textPV.animationSpeed),
                motionIntensity: CGFloat(settings.textPV.motionIntensity)
            )
        )
        .id(snapshot.identity)
        .contentShape(.rect)
        .gesture(lyricTapGesture(for: snapshot.line))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            snapshot.line.accessibilityText(
                includingTranslation: settings.lyricsTranslationEnabled
            )
        )
        .accessibilityValue("当前播放，文字PV，\(snapshot.template.style.title)")
        .accessibilityHint(
            settings.lyricsTapToSeek
                ? "双击从这句歌词重新播放"
                : "歌词跳转已在设置中关闭"
        )
        .accessibilityAddTraits(settings.lyricsTapToSeek ? .isButton : [])
        .accessibilityAction { seek(to: snapshot.line) }
    }

    private func makeSnapshot() -> TextPVFrameSnapshot {
        let index = highlightedLyricID.flatMap { id in
            lyrics.firstIndex { $0.id == id }
        } ?? lyrics.startIndex
        let line = lyrics[index]
        let previousText = index > lyrics.startIndex ? lyrics[index - 1].text : ""
        let scheduledDuration: TimeInterval
        if index + 1 < lyrics.endIndex {
            scheduledDuration = max(lyrics[index + 1].time - line.time, 0.12)
        } else {
            scheduledDuration = max(line.duration ?? 3, 0.12)
        }
        let template = TextPVTemplate.resolve(style: settings.textPV.style)
        let normalizedText = LyricsTypography.normalizedDisplayText(line.text)
        return TextPVFrameSnapshot(
            line: line,
            previousText: previousText,
            normalizedText: normalizedText,
            normalizedCharacters: Array(normalizedText),
            visibleCharacters: normalizedText.filter { !$0.isWhitespace },
            previousCharacters: previousText.filter { !$0.isWhitespace },
            template: template,
            scheduledDuration: scheduledDuration,
            seed: TextPVSeed.value(
                line.id,
                previousText,
                template.style.rawValue
            )
        )
    }

    private func lyricTapGesture(for line: LyricLine) -> some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { gesture in
                switch gesture {
                case .first: seek(to: line)
                case .second: onToggleInterface?()
                }
            }
    }

    private func seek(to line: LyricLine) {
        guard settings.lyricsTapToSeek else { return }
        player.seek(to: line.time)
    }
}

private struct TextPVEmptyState: View {
    let errorMessage: String?
    let onToggleInterface: (() -> Void)?

    var body: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView(
                    "暂无歌词",
                    systemImage: "textformat.size.larger",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("正在生成文字PV")
                    .tint(.white)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .onTapGesture { onToggleInterface?() }
    }
}

private struct TextPVFrameSnapshot {
    let line: LyricLine
    let previousText: String
    let normalizedText: String
    let normalizedCharacters: [Character]
    let visibleCharacters: [Character]
    let previousCharacters: [Character]
    let template: TextPVTemplate
    let scheduledDuration: TimeInterval
    let seed: UInt64

    var identity: TextPVFrameIdentity {
        TextPVFrameIdentity(lineID: line.id, style: template.style)
    }

    var settledPlaybackTime: TimeInterval {
        line.time + min(scheduledDuration * 0.58, 1.4)
    }

    func renderContext(
        at playbackTime: TimeInterval,
        animationSpeed: CGFloat,
        motionIntensity: CGFloat
    ) -> TextPVRenderContext {
        TextPVRenderContext(
            template: template,
            currentText: line.text,
            previousText: previousText,
            normalizedText: normalizedText,
            normalizedCharacters: normalizedCharacters,
            visibleCharacters: visibleCharacters,
            previousCharacters: previousCharacters,
            time: CGFloat(max(playbackTime, 0)),
            segmentTime: CGFloat(max(playbackTime - line.time, 0)),
            animationSpeed: animationSpeed,
            motionIntensity: motionIntensity,
            fontScale: 1,
            seed: seed
        )
    }
}

private struct TextPVFrameIdentity: Hashable {
    let lineID: LyricLine.ID
    let style: TextPVStyle
}
