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

/// Owns the clock-driven indicator/lyric handoff. The visible slot is kept
/// separately from focus so its fixed layout row cannot be inserted or removed
/// in the same transaction that promotes the following lyric.
struct AppleMusicLyricsFocusCoordinator: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let lyrics: [LyricLine]
    let interludes: [LyricInterlude]
    let isActive: Bool
    @Binding var playbackFocus: AppleMusicLyricsPlaybackFocus?
    @Binding var timelineHighlightedLyricID: LyricLine.ID?
    @Binding var visibleInterludeID: LyricInterlude.ID?
    @Binding var activePlaybackLyricIDs: Set<LyricLine.ID>

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: synchronizationTrigger, initial: true) {
                guard isActive else { return }
                synchronizeImmediately()
            }
            .onChange(of: player.progress) {
                guard isActive else { return }
                synchronizeImmediately()
            }
            .task(id: synchronizationTrigger) {
                guard isActive else { return }
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
            isEnabled: settings.lyricsInterludeCountdownEnabled,
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
        updatePlaybackPosition(to: position)
    }

    private func synchronizeAtTransitions() async {
        while !Task.isCancelled {
            let adjustedProgress = player.estimatedProgress()
                + advanceTime
            let position = playbackPosition(at: adjustedProgress)
            updatePlaybackPosition(to: position)

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
        let interludePosition = settings.lyricsInterludeCountdownEnabled
            ? LyricInterludeTimeline.position(
                at: playbackTime,
                in: interludes
            )
            : LyricInterludePlaybackPosition(
                visibleInterludeID: nil,
                focusedInterludeID: nil,
                promotedLyricID: nil,
                nextTransitionTime: nil
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
            highlightedLyricID: lyricPosition.highlightedLyricID,
            visibleInterludeID: interludePosition.visibleInterludeID,
            activeLyricIDs: lyricPosition.activeLyricIDs,
            nextTransitionTime: nextTransitionTime
        )
    }

    private func updatePlaybackPosition(
        to position: AppleMusicLyricsPlaybackFocusPosition
    ) {
        guard playbackFocus != position.focus
                || timelineHighlightedLyricID
                    != position.highlightedLyricID
                || visibleInterludeID != position.visibleInterludeID
                || activePlaybackLyricIDs != position.activeLyricIDs else {
            return
        }
        playbackFocus = position.focus
        timelineHighlightedLyricID = position.highlightedLyricID
        visibleInterludeID = position.visibleInterludeID
        activePlaybackLyricIDs = position.activeLyricIDs
    }

    private var advanceTime: TimeInterval {
        settings.effectiveLyricsAdvanceTime(for: lyrics)
    }
}

struct AppleMusicLyricInterludeView: View {
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.effectiveLyricsRefreshRate)
    private var effectiveLyricsRefreshRate
    @Environment(\.lyricsRenderingIsActive)
    private var lyricsRenderingIsActive
    @Environment(PlayerStore.self) private var player

    let interlude: LyricInterlude
    let isVisible: Bool
    let advanceTime: TimeInterval
    let motionProfile: AppleMusicInstrumentalBreakMotionProfile
    let visualScale: CGFloat
    let onInterfaceInteraction: (() -> Void)?

    var body: some View {
        Group {
            if !isVisible {
                Color.clear
                    .frame(
                        width: contentWidth,
                        height: viewHeight
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
                        paused: !player.isPlaying
                            || !lyricsRenderingIsActive
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
            minHeight: viewHeight,
            maxHeight: viewHeight,
            alignment: .leading
        )
        .contentShape(.rect)
        .onTapGesture {
            onInterfaceInteraction?()
        }
        .accessibilityHidden(true)
    }

    private var contentWidth: CGFloat {
        motionProfile.contentWidth / effectiveVisualScale
    }

    private var dotDiameter: CGFloat {
        CGFloat(motionProfile.dotLength) / effectiveVisualScale
    }

    private var dotSpacing: CGFloat {
        CGFloat(motionProfile.dotMargin) / effectiveVisualScale
    }

    private var viewHeight: CGFloat {
        CGFloat(motionProfile.viewHeight) / effectiveVisualScale
    }

    private var effectiveVisualScale: CGFloat {
        guard visualScale.isFinite else { return 1 }
        return max(visualScale, 1)
    }

    private func dots(
        presentation: AppleMusicInterludeDotsPresentation
    ) -> some View {
        HStack(spacing: dotSpacing) {
            ForEach(presentation.dotOpacities.indices, id: \.self) {
                index in
                Circle()
                    .fill(
                        .white.opacity(
                            presentation.dotOpacities[index]
                        )
                    )
                    .frame(
                        width: dotDiameter,
                        height: dotDiameter
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
            width: contentWidth,
            height: viewHeight,
            alignment: .leading
        )
        .opacity(presentation.opacity)
    }

    private func presentation(
        at playbackTime: TimeInterval
    ) -> AppleMusicInterludeDotsPresentation {
        AppleMusicInterludeDotsPresentation.make(
            playbackTime: playbackTime,
            interlude: interlude,
            profile: motionProfile,
            reducesMotion: accessibilityReduceMotion
        )
    }
}

private struct AppleMusicLyricsFocusSynchronizationTrigger: Hashable {
    let songID: Int?
    let seekRevision: Int
    let isPlaying: Bool
    let isActive: Bool
    let isEnabled: Bool
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
    let highlightedLyricID: LyricLine.ID?
    let visibleInterludeID: LyricInterlude.ID?
    let activeLyricIDs: Set<LyricLine.ID>
    let nextTransitionTime: TimeInterval?
}
