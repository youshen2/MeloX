import SwiftUI

enum NowPlayingPage: String, Hashable {
    case artwork
    case details
    case lyrics
    case queue
}

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @State private var page: NowPlayingPage
    @State private var lyrics: [LyricLine] = []
    @State private var lyricError: String?
    @State private var highlightedLyricID: LyricLine.ID?
    @State private var showsAudioOutputHelp = false
    @Namespace private var pageArtworkNamespace

    init(initialPage: NowPlayingPage = .artwork) {
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                NowPlayingBackground(artworkURL: player.currentSong?.album?.artworkURL)

                if let song = player.currentSong {
                    if proxy.size.width > proxy.size.height {
                        NowPlayingLandscapeView(
                            page: $page,
                            song: song,
                            lyrics: lyrics,
                            lyricError: lyricError,
                            highlightedLyricID: highlightedLyricID,
                            artworkNamespace: pageArtworkNamespace,
                            onDismiss: { dismiss() },
                            onShowAudioOutputHelp: {
                                showsAudioOutputHelp = true
                            }
                        )
                    } else {
                        portraitContent(for: song)
                    }
                } else {
                    ContentUnavailableView("没有正在播放的歌曲", systemImage: "music.note")
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("音频输出", isPresented: $showsAudioOutputHelp) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请从控制中心选择 AirPlay 或蓝牙播放设备。")
        }
        .task(id: player.currentSong?.id) {
            await loadLyrics()
        }
        .task(id: lyricSynchronizationTrigger) {
            await synchronizeHighlightedLyric()
        }
        .onChange(of: page) { _, newPage in
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

            pageContent(for: song)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            NowPlayingProgressControl(song: song)
            NowPlayingTransportControls()
            NowPlayingVolumeControl()
            NowPlayingPageSelector(
                page: $page,
                onShowAudioOutputHelp: {
                    showsAudioOutputHelp = true
                }
            )
        }
        .padding(.horizontal, 28)
        .safeAreaPadding(.top, 4)
        .safeAreaPadding(.bottom, 8)
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
                    artworkNamespace: pageArtworkNamespace,
                    onShowDetails: showDetails
                )
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
