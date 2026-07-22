import SwiftUI

enum NowPlayingPage: String, Hashable {
    case artwork
    case details
    case lyrics
    case queue
}

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @State private var page: NowPlayingPage
    @State private var showsLyricsControls = true
    @State private var lyrics: [LyricLine] = []
    @State private var lyricError: String?
    @State private var highlightedLyricID: LyricLine.ID?
    @State private var showsTextPVLandscapeSuggestion = false
    @Namespace private var pageArtworkNamespace

    init(initialPage: NowPlayingPage = .artwork) {
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if usesMonochromeLyricsBackground {
                    Color.black
                        .ignoresSafeArea()
                } else {
                    NowPlayingBackground(
                        artworkURL: player.currentSong?.album?.artworkURL
                    )
                }

                if let song = player.currentSong {
                    if usesFullScreenTextPV {
                        TextPVFullScreenPlayerView(
                            page: $page,
                            showsControls: $showsLyricsControls,
                            song: song,
                            lyrics: lyrics,
                            errorMessage: lyricError,
                            highlightedLyricID: highlightedLyricID,
                            onDismiss: { dismiss() },
                            onToggleInterface: toggleLyricsControls
                        )
                        .transition(.opacity)
                    } else if proxy.size.width > proxy.size.height {
                        NowPlayingLandscapeView(
                            page: $page,
                            showsLyricsControls: $showsLyricsControls,
                            song: song,
                            lyrics: lyrics,
                            lyricError: lyricError,
                            highlightedLyricID: highlightedLyricID,
                            artworkNamespace: pageArtworkNamespace,
                            onDismiss: { dismiss() }
                        )
                    } else {
                        portraitContent(for: song)
                    }
                } else {
                    ContentUnavailableView("没有正在播放的歌曲", systemImage: "music.note")
                        .foregroundStyle(.white)
                }

                if usesFullScreenTextPV,
                   showsTextPVLandscapeSuggestion,
                   proxy.size.width <= proxy.size.height {
                    Label("建议切换至横屏观看文字PV", systemImage: "rectangle.landscape.rotate")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.regularMaterial, in: .capsule)
                        .shadow(color: .black.opacity(0.24), radius: 12, y: 5)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .safeAreaPadding(.top, 58)
                        .accessibilityLabel("建议切换至横屏观看文字PV")
                }
            }
        }
        .keepsScreenAwake(keepsPlayerScreenAwake)
        .preferredColorScheme(.dark)
        .task(id: player.currentSong?.id) {
            await loadLyrics()
        }
        .task(id: lyricSynchronizationTrigger) {
            await synchronizeHighlightedLyric()
        }
        .task(id: usesFullScreenTextPV) {
            guard usesFullScreenTextPV else {
                showsTextPVLandscapeSuggestion = false
                return
            }

            withAnimation(accessibilityReduceMotion ? nil : .smooth(duration: 0.25)) {
                showsTextPVLandscapeSuggestion = true
            }
            do {
                try await Task.sleep(for: .seconds(3.2))
            } catch {
                return
            }
            withAnimation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.2)) {
                showsTextPVLandscapeSuggestion = false
            }
        }
        .onChange(of: page) { _, newPage in
            if newPage != .lyrics {
                showsLyricsControls = true
            }

            guard settings.rememberNowPlayingPage else { return }
            settings.rememberedNowPlayingPage = (
                newPage == .details ? NowPlayingPage.artwork : newPage
            ).rawValue
        }
        .animation(.smooth(duration: 0.4), value: page)
    }

    private func portraitContent(for song: Song) -> some View {
        VStack(spacing: 0) {
            dismissalHandle

            if usesExpandedAppleMusicLyricsLayout {
                pageContent(for: song)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        portraitPlayerControls(for: song)
                            .opacity(hidesLyricsControls ? 0 : 1)
                            .allowsHitTesting(!hidesLyricsControls)
                            .accessibilityHidden(hidesLyricsControls)
                    }
            } else {
                pageContent(for: song)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                portraitPlayerControls(for: song)
                    .opacity(hidesLyricsControls ? 0 : 1)
                    .allowsHitTesting(!hidesLyricsControls)
                    .accessibilityHidden(hidesLyricsControls)
            }
        }
        .padding(.horizontal, 28)
        .safeAreaPadding(.top, 4)
        .safeAreaPadding(.bottom, 8)
    }

    private func portraitPlayerControls(for song: Song) -> some View {
        VStack(spacing: 0) {
            NowPlayingProgressControl(song: song)
            NowPlayingTransportControls()
            NowPlayingVolumeControl()
            NowPlayingPageSelector(page: $page)
        }
    }

    private var hidesLyricsControls: Bool {
        page == .lyrics && !showsLyricsControls
    }

    private var keepsPlayerScreenAwake: Bool {
        switch settings.playerScreenAwakeMode {
        case .disabled:
            false
        case .player:
            true
        case .lyrics:
            page == .lyrics
        case .hiddenLyricsInterface:
            hidesLyricsControls
        }
    }

    private var usesExpandedAppleMusicLyricsLayout: Bool {
        page == .lyrics && settings.lyricsStyle == .appleMusic
    }

    private var usesFullScreenTextPV: Bool {
        page == .lyrics && settings.lyricsStyle == .textPV
    }

    private var usesMonochromeLyricsBackground: Bool {
        page == .lyrics && settings.lyricsStyle.usesMonochromePlayerBackground
    }

    private var dismissalHandle: some View {
        Capsule()
            .fill(.white.opacity(0.52))
            .frame(width: 38, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(.rect)
            .onTapGesture {
                dismiss()
            }
            .gesture(dismissalDragGesture)
            .accessibilityElement()
            .accessibilityLabel("收起播放器")
            .accessibilityHint("轻点收起，或向下拖动播放器")
            .accessibilityAction {
                dismiss()
            }
    }

    private func pageContent(for song: Song) -> some View {
        ZStack {
            switch page {
            case .artwork:
                NowPlayingArtworkPage(
                    song: song,
                    artworkNamespace: pageArtworkNamespace,
                    onShowDetails: showDetails
                )
                .transition(.opacity)
            case .details:
                NowPlayingSongDetailsPage(
                    song: song,
                    showsArtworkToggle: true,
                    artworkNamespace: pageArtworkNamespace,
                    onShowArtwork: showArtwork
                )
                .transition(.opacity)
            case .lyrics:
                NowPlayingLyricsPage(
                    song: song,
                    lyrics: lyrics,
                    errorMessage: lyricError,
                    highlightedLyricID: highlightedLyricID,
                    isInterfaceHidden: hidesLyricsControls,
                    artworkNamespace: pageArtworkNamespace,
                    onToggleInterface: toggleLyricsControls,
                    onShowDetails: showDetails
                )
                .accessibilityAction(
                    named: showsLyricsControls ? "隐藏播放器控制" : "显示播放器控制"
                ) {
                    toggleLyricsControls()
                }
                .transition(.opacity)
            case .queue:
                NowPlayingQueuePage()
                    .transition(.opacity)
            }
        }
    }

    private var dismissalDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                guard value.translation.height > 60,
                      abs(value.translation.height) > abs(value.translation.width) else {
                    return
                }
                dismiss()
            }
    }

    private func showDetails() {
        withAnimation(.smooth(duration: 0.3)) {
            page = .details
        }
    }

    private func showArtwork() {
        withAnimation(.smooth(duration: 0.3)) {
            page = .artwork
        }
    }

    private func toggleLyricsControls() {
        withAnimation(accessibilityReduceMotion ? nil : .smooth(duration: 0.3)) {
            showsLyricsControls.toggle()
        }
    }

    private var lyricSynchronizationTrigger: LyricSynchronizationTrigger {
        LyricSynchronizationTrigger(
            songID: player.currentSong?.id,
            progress: player.progress,
            isPlaying: player.isPlaying,
            advanceTime: settings.lyricsAdvanceTime,
            lyricCount: lyrics.count,
            firstLyricID: lyrics.first?.id,
            lastLyricID: lyrics.last?.id
        )
    }

    private func synchronizeHighlightedLyric() async {
        let synchronizedLyrics = lyrics
        let advanceTime = settings.lyricsAdvanceTime

        while !Task.isCancelled {
            let adjustedProgress = player.estimatedProgress() + advanceTime
            let position = LyricPlaybackTimeline.position(
                at: adjustedProgress,
                in: synchronizedLyrics
            )
            if highlightedLyricID != position.highlightedLyricID {
                highlightedLyricID = position.highlightedLyricID
            }

            guard player.isPlaying,
                  let nextTransitionTime = position.nextTransitionTime else {
                return
            }

            let remainingTime = nextTransitionTime
                - (player.estimatedProgress() + advanceTime)
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

    private func loadLyrics() async {
        lyrics = []
        lyricError = nil
        guard let song = player.currentSong else { return }
        let songID = song.id

        do {
            let loadedLyrics = try await api.lyrics(id: songID)
            try Task.checkCancellation()
            guard player.currentSong?.id == songID else { return }
            lyrics = loadedLyrics
            lyricError = loadedLyrics.isEmpty ? "当前歌曲暂无滚动歌词。" : nil
        } catch is CancellationError {
            return
        } catch {
            guard player.currentSong?.id == songID else { return }
            lyricError = error.localizedDescription
        }
    }
}

private struct LyricSynchronizationTrigger: Hashable {
    let songID: Int?
    let progress: TimeInterval
    let isPlaying: Bool
    let advanceTime: TimeInterval
    let lyricCount: Int
    let firstLyricID: LyricLine.ID?
    let lastLyricID: LyricLine.ID?
}
