import SwiftUI

struct TextPV1LyricsView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.effectiveLyricsRefreshRate) private var effectiveLyricsRefreshRate
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let lyrics: [LyricLine]
    let errorMessage: String?
    let highlightedLyricID: LyricLine.ID?
    let onToggleInterface: (() -> Void)?

    @State private var sceneOffset = Int.random(in: 0..<TextPV1Scene.allCases.count)
    @State private var climaxLyricIDs: Set<LyricLine.ID> = []

    var body: some View {
        Group {
            if lyrics.isEmpty {
                emptyState
            } else {
                stage
            }
        }
        .background(.black)
        .task(id: lyricsSignature) {
            climaxLyricIDs = TextPV1ClimaxDetector.climaxLyricIDs(in: lyrics)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let errorMessage {
            ContentUnavailableView(
                "暂无歌词",
                systemImage: "textformat.size.larger",
                description: Text(errorMessage)
            )
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .onTapGesture {
                onToggleInterface?()
            }
        } else {
            ProgressView("正在编排文字PV")
                .tint(.white)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .onTapGesture {
                    onToggleInterface?()
                }
        }
    }

    @ViewBuilder
    private var stage: some View {
        if accessibilityReduceMotion {
            stageFrame(playbackTime: settledPlaybackTime)
        } else {
            TimelineView(
                .animation(
                    minimumInterval: effectiveLyricsRefreshRate.minimumInterval,
                    paused: !player.isPlaying
                )
            ) { context in
                stageFrame(
                    playbackTime: player.estimatedProgress(at: context.date)
                        + settings.lyricsAdvanceTime
                )
            }
        }
    }

    private func stageFrame(playbackTime: TimeInterval) -> some View {
        TextPV1StageView(
            line: currentLine,
            scene: currentScene,
            sceneSeed: currentSceneSeed,
            isClimax: usesClimaxImpactTransition,
            performsFullEntrance: performsFullEntrance,
            performsFullExit: performsFullExit,
            playbackTime: playbackTime,
            lineScheduledDuration: scheduledDuration,
            sceneStartTime: sceneStartTime,
            sceneScheduledDuration: sceneScheduledDuration,
            fontScale: CGFloat(settings.lyricsFontSize / 26),
            motionIntensity: CGFloat(settings.textPV1MotionIntensity),
            showsTranslation: settings.lyricsTranslationEnabled,
            reducesMotion: accessibilityReduceMotion
        )
        .id(currentLine.id)
        .contentShape(.rect)
        .gesture(lyricTapGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            currentLine.accessibilityText(
                includingTranslation: settings.lyricsTranslationEnabled
            )
        )
        .accessibilityValue("当前播放，文字PV1")
        .accessibilityHint(
            settings.lyricsTapToSeek
                ? "双击从这句歌词重新播放"
                : "歌词跳转已在设置中关闭"
        )
        .accessibilityAddTraits(settings.lyricsTapToSeek ? .isButton : [])
        .accessibilityAction {
            seekToCurrentLine()
        }
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

    private var currentScene: TextPV1Scene {
        let index = (sceneGroupIndex + sceneOffset) % TextPV1Scene.allCases.count
        return TextPV1Scene.allCases[index]
    }

    private var sceneGroupIndex: Int {
        currentIndex / 2
    }

    private var currentSceneSeed: UInt64 {
        let firstIndex = sceneStartIndex
        return TextPV1StableSeed.value(
            for: "\(lyrics[firstIndex].id)-\(currentScene.rawValue)"
        )
    }

    private var sceneStartIndex: Int {
        min(sceneGroupIndex * 2, lyrics.index(before: lyrics.endIndex))
    }

    private var sceneStartTime: TimeInterval {
        lyrics[sceneStartIndex].time
    }

    private var sceneScheduledDuration: TimeInterval? {
        let followingSceneIndex = sceneStartIndex + 2
        if followingSceneIndex < lyrics.endIndex {
            return max(
                lyrics[followingSceneIndex].time - sceneStartTime,
                0.24
            )
        }

        guard let lastLine = lyrics.last,
              let lastDuration = lastLine.duration,
              lastDuration > 0 else {
            return nil
        }
        return max(lastLine.time + lastDuration - sceneStartTime, 0.24)
    }

    private var scheduledDuration: TimeInterval? {
        let followingIndex = lyrics.index(after: currentIndex)
        if followingIndex < lyrics.endIndex {
            return max(lyrics[followingIndex].time - currentLine.time, 0.12)
        }
        if let duration = currentLine.duration, duration > 0 {
            return duration
        }
        return nil
    }

    private var settledPlaybackTime: TimeInterval {
        currentLine.time + min((scheduledDuration ?? 3.2) * 0.46, 1.1)
    }

    private var usesClimaxImpactTransition: Bool {
        guard climaxLyricIDs.contains(currentLine.id) else { return false }
        guard currentIndex > lyrics.startIndex else { return true }

        let previousLineIsClimax = climaxLyricIDs.contains(
            lyrics[currentIndex - 1].id
        )
        return !previousLineIsClimax || currentIndex.isMultiple(of: 2)
    }

    private var performsFullEntrance: Bool {
        currentIndex == sceneStartIndex || usesClimaxImpactTransition
    }

    private var performsFullExit: Bool {
        currentIndex + 1 >= lyrics.endIndex
            || (currentIndex + 1) / 2 != sceneGroupIndex
    }

    private var lyricsSignature: TextPV1LyricsSignature {
        TextPV1LyricsSignature(
            count: lyrics.count,
            firstID: lyrics.first?.id,
            lastID: lyrics.last?.id
        )
    }

    private var lyricTapGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { gesture in
                switch gesture {
                case .first:
                    seekToCurrentLine()
                case .second:
                    onToggleInterface?()
                }
            }
    }

    private func seekToCurrentLine() {
        guard settings.lyricsTapToSeek else { return }
        player.seek(to: currentLine.time)
    }
}

private struct TextPV1LyricsSignature: Hashable {
    let count: Int
    let firstID: LyricLine.ID?
    let lastID: LyricLine.ID?
}
