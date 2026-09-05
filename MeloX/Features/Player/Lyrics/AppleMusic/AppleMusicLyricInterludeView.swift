import SwiftUI

enum AppleMusicLyricsPlaybackFocus: Hashable {
    case lyric(LyricLine.ID)
    case interlude(LyricInterlude.ID)

    var lyricID: LyricLine.ID? {
        guard case let .lyric(id) = self else { return nil }
        return id
    }

    var interludeID: LyricInterlude.ID? {
        guard case let .interlude(id) = self else { return nil }
        return id
    }
}

struct AppleMusicLyricsFocusCoordinator: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let lyrics: [LyricLine]
    let interludes: [LyricInterlude]
    let isActive: Bool
    @Binding var playbackFocus: AppleMusicLyricsPlaybackFocus?
    @Binding var visibleInterludeID: LyricInterlude.ID?
    @Binding var activePlaybackLyricIDs: Set<LyricLine.ID>

    init(
        lyrics: [LyricLine],
        interludes: [LyricInterlude],
        isActive: Bool = true,
        playbackFocus: Binding<AppleMusicLyricsPlaybackFocus?>,
        visibleInterludeID: Binding<LyricInterlude.ID?>,
        activePlaybackLyricIDs: Binding<Set<LyricLine.ID>>
    ) {
        self.lyrics = lyrics
        self.interludes = interludes
        self.isActive = isActive
        _playbackFocus = playbackFocus
        _visibleInterludeID = visibleInterludeID
        _activePlaybackLyricIDs = activePlaybackLyricIDs
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: player.progress, initial: true) {
                guard isActive else { return }
                synchronizeImmediately()
            }
            .onChange(of: isActive) { _, isActive in
                guard isActive else { return }
                synchronizeImmediately()
            }
            .task(id: synchronizationTrigger) {
                await synchronizeAtTransitions()
            }
    }

    private var synchronizationTrigger:
        AppleMusicLyricsFocusSynchronizationTrigger {
        AppleMusicLyricsFocusSynchronizationTrigger(
            songID: player.currentSong?.id,
            seekRevision: player.seekRevision,
            isPlaying: player.isPlaying,
            isActive: isActive,
            interludeMode: settings.lyricsInterlude.mode,
            minimumInferredGapDuration:
                settings.lyricsInterlude.minimumInferredGapDuration,
            advanceTime: advanceTime,
            lyricCount: lyrics.count,
            firstLyricID: lyrics.first?.id,
            lastLyricID: lyrics.last?.id,
            interludeCount: interludes.count,
            firstInterludeID: interludes.first?.id,
            lastInterludeID: interludes.last?.id
        )
    }

    private func synchronizeImmediately() {
        let position = playbackPosition(
            at: player.estimatedProgress()
                + advanceTime
        )
        updatePlaybackState(to: position)
    }

    private func synchronizeAtTransitions() async {
        guard isActive else { return }
        while !Task.isCancelled {
            let adjustedProgress = player.estimatedProgress()
                + advanceTime
            let position = playbackPosition(at: adjustedProgress)
            updatePlaybackState(to: position)

            guard player.isPlaying,
                  let nextTransitionTime = position.nextTransitionTime else {
                return
            }

            let remainingTime = nextTransitionTime
                - (
                    player.estimatedProgress()
                        + advanceTime
                )
            guard remainingTime > 0 else {
                await Task.yield()
                continue
            }

            do {
                try await Task.sleep(for: .seconds(remainingTime))
            } catch {
                return
            }
        }
    }

    private func playbackPosition(
        at playbackTime: TimeInterval
    ) -> AppleMusicLyricsPlaybackFocusPosition {
        let lyricPosition = LyricPlaybackTimeline.position(
            at: playbackTime,
            in: lyrics
        )
        let interludePosition = LyricInterludeTimeline.position(
            at: playbackTime,
            in: interludes
        )
        let focus = interludePosition.focusedInterludeID.map {
            AppleMusicLyricsPlaybackFocus.interlude($0)
        } ?? interludePosition.promotedLyricID.map {
            AppleMusicLyricsPlaybackFocus.lyric($0)
        } ?? lyricPosition.highlightedLyricID.map {
            AppleMusicLyricsPlaybackFocus.lyric($0)
        }
        let nextTransitionTime = [
            lyricPosition.nextTransitionTime,
            interludePosition.nextTransitionTime,
        ]
        .compactMap { $0 }
        .min()

        return AppleMusicLyricsPlaybackFocusPosition(
            focus: focus,
            visibleInterludeID:
                interludePosition.visibleInterludeID,
            activeLyricIDs: lyricPosition.activeLyricIDs,
            nextTransitionTime: nextTransitionTime
        )
    }

    private func updatePlaybackState(
        to position: AppleMusicLyricsPlaybackFocusPosition
    ) {
        guard playbackFocus != position.focus
                || visibleInterludeID != position.visibleInterludeID
                || activePlaybackLyricIDs != position.activeLyricIDs else {
            return
        }
        playbackFocus = position.focus
        visibleInterludeID = position.visibleInterludeID
        activePlaybackLyricIDs = position.activeLyricIDs
    }

    private var advanceTime: TimeInterval {
        settings.effectiveLyricsAdvanceTime(for: lyrics)
    }
}

struct AppleMusicLyricInterludeView: View {
    private let motionProfile = AppleMusicInterludeMotionProfile.iOS26_6

    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.effectiveLyricsRefreshRate)
    private var effectiveLyricsRefreshRate
    @Environment(PlayerStore.self) private var player

    let interlude: LyricInterlude
    let isVisible: Bool
    let isAnimationActive: Bool
    let advanceTime: TimeInterval
    let onInterfaceInteraction: (() -> Void)?

    init(
        interlude: LyricInterlude,
        isVisible: Bool,
        isAnimationActive: Bool = true,
        advanceTime: TimeInterval,
        onInterfaceInteraction: (() -> Void)?
    ) {
        self.interlude = interlude
        self.isVisible = isVisible
        self.isAnimationActive = isAnimationActive
        self.advanceTime = advanceTime
        self.onInterfaceInteraction = onInterfaceInteraction
    }

    var body: some View {
        Group {
            if !isVisible {
                Color.clear
                    .frame(
                        width: motionProfile.contentWidth,
                        height: motionProfile.viewHeight
                    )
            } else if accessibilityReduceMotion {
                dots(
                    presentation: presentation(
                        at: player.estimatedProgress()
                            + advanceTime
                    )
                )
            } else {
                TimelineView(
                    .animation(
                        minimumInterval:
                            effectiveLyricsRefreshRate.minimumInterval,
                        paused: !player.isPlaying || !isAnimationActive
                    )
                ) { timeline in
                    dots(
                        presentation: presentation(
                            at: player.estimatedProgress(
                                at: timeline.date
                            ) + advanceTime
                        )
                    )
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: motionProfile.viewHeight,
            maxHeight: motionProfile.viewHeight,
            alignment: .leading
        )
        .contentShape(.rect)
        .onTapGesture {
            onInterfaceInteraction?()
        }
        .accessibilityHidden(true)
    }

    private func dots(
        presentation: AppleMusicInterludeDotsPresentation
    ) -> some View {
        HStack(spacing: motionProfile.dotMargin) {
            ForEach(presentation.dotOpacities.indices, id: \.self) {
                index in
                Circle()
                    .fill(
                        .white.opacity(
                            presentation.dotOpacities[index]
                        )
                    )
                    .frame(
                        width: motionProfile.dotLength,
                        height: motionProfile.dotLength
                    )
                    .scaleEffect(
                        presentation.scale,
                        anchor: UnitPoint(
                            x: motionProfile.dotAnchorX(at: index),
                            y: 0.5
                        )
                    )
            }
        }
        .frame(
            width: motionProfile.contentWidth,
            height: motionProfile.viewHeight,
            alignment: .leading
        )
        .opacity(presentation.opacity)
    }

    private func presentation(
        at playbackTime: TimeInterval
    ) -> AppleMusicInterludeDotsPresentation {
        return AppleMusicInterludeDotsPresentation.make(
            playbackTime: playbackTime,
            interlude: interlude,
            reducesMotion: accessibilityReduceMotion,
            profile: motionProfile
        )
    }
}

private struct AppleMusicLyricsFocusSynchronizationTrigger: Hashable {
    let songID: Int?
    let seekRevision: Int
    let isPlaying: Bool
    let isActive: Bool
    let interludeMode: LyricsInterludePresentationMode
    let minimumInferredGapDuration: TimeInterval
    let advanceTime: TimeInterval
    let lyricCount: Int
    let firstLyricID: LyricLine.ID?
    let lastLyricID: LyricLine.ID?
    let interludeCount: Int
    let firstInterludeID: LyricInterlude.ID?
    let lastInterludeID: LyricInterlude.ID?
}

private struct AppleMusicLyricsPlaybackFocusPosition {
    let focus: AppleMusicLyricsPlaybackFocus?
    let visibleInterludeID: LyricInterlude.ID?
    let activeLyricIDs: Set<LyricLine.ID>
    let nextTransitionTime: TimeInterval?
}
