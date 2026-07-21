import SwiftUI

struct NowPlayingLyricsPage: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let song: Song
    let lyrics: [LyricLine]
    let errorMessage: String?
    let highlightedLyricID: LyricLine.ID?
    let onShowQueue: () -> Void

    @State private var scrollPositionID: LyricLine.ID?
    @State private var isBrowsingLyrics = false
    @State private var browsingGeneration = 0

    init(
        song: Song,
        lyrics: [LyricLine],
        errorMessage: String?,
        highlightedLyricID: LyricLine.ID?,
        onShowQueue: @escaping () -> Void
    ) {
        self.song = song
        self.lyrics = lyrics
        self.errorMessage = errorMessage
        self.highlightedLyricID = highlightedLyricID
        self.onShowQueue = onShowQueue
        _scrollPositionID = State(initialValue: highlightedLyricID)
    }

    var body: some View {
        VStack(spacing: 18) {
            songHeader
            lyricsContent
        }
        .padding(.bottom, 12)
    }

    private var songHeader: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: song.album?.artworkURL, cornerRadius: 8)
                .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(song.artistText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            NowPlayingSongActions(song: song, onShowQueue: onShowQueue)
        }
    }

    @ViewBuilder
    private var lyricsContent: some View {
        if lyrics.isEmpty {
            if let errorMessage {
                ContentUnavailableView(
                    "暂无歌词",
                    systemImage: "quote.bubble",
                    description: Text(errorMessage)
                )
                .foregroundStyle(.white)
            } else {
                ProgressView("正在载入歌词")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            let focusPosition = lyricsFocusPosition
            let lyricStride = max(
                CGFloat(settings.lyricsFontSize) * 1.2 + CGFloat(settings.lyricsLineSpacing),
                1
            )
            let blurIntensity = CGFloat(settings.lyricsBlurIntensity)
            let dimAmount = settings.lyricsDimAmount

            GeometryReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CGFloat(settings.lyricsLineSpacing)) {
                        ForEach(lyrics) { line in
                            let isPlaybackLine = line.id == highlightedLyricID
                            let isBrowsingFocus = isBrowsingLyrics && line.id == scrollPositionID

                            Text(line.text)
                                .font(.system(size: CGFloat(settings.lyricsFontSize), weight: .bold))
                                .foregroundStyle(
                                    .white.opacity(
                                        isBrowsingLyrics && !isPlaybackLine ? 0.58 : 1
                                    )
                                )
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                                .visualEffect { content, geometry in
                                    let frame = geometry.frame(in: .scrollView(axis: .vertical))
                                    let distance = abs(frame.midY - proxy.size.height * focusPosition)
                                    return content
                                        .blur(
                                            radius: Self.lyricBlurRadius(
                                                forPixelDistance: distance,
                                                lyricStride: lyricStride,
                                                intensity: blurIntensity
                                            )
                                        )
                                        .opacity(
                                            Self.lyricOpacity(
                                                forPixelDistance: distance,
                                                lyricStride: lyricStride,
                                                dimAmount: dimAmount
                                            )
                                        )
                                }
                                .onTapGesture(count: 2) {
                                    seek(to: line)
                                }
                                .id(line.id)
                                .accessibilityLabel(line.text)
                                .accessibilityValue(
                                    lyricAccessibilityValue(
                                        isPlaybackLine: isPlaybackLine,
                                        isBrowsingFocus: isBrowsingFocus
                                    )
                                )
                                .accessibilityHint(settings.lyricsTapToSeek ? "双击跳转到这行歌词" : "歌词跳转已在设置中关闭")
                                .accessibilityAddTraits(settings.lyricsTapToSeek ? .isButton : [])
                                .accessibilityAction {
                                    seek(to: line)
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.top, max(proxy.size.height * focusPosition, 40))
                    .padding(.bottom, max(proxy.size.height * (1 - focusPosition), 40))
                }
                .scrollIndicators(.hidden)
                .scrollPosition(
                    id: $scrollPositionID,
                    anchor: UnitPoint(x: 0.5, y: focusPosition)
                )
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.08),
                            .init(color: .black, location: 0.84),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .onScrollPhaseChange { _, newPhase in
                    switch newPhase {
                    case .tracking, .interacting:
                        browsingGeneration += 1
                        isBrowsingLyrics = true
                    case .idle:
                        schedulePlaybackFollowing()
                    case .decelerating, .animating:
                        break
                    }
                }
                .onChange(of: highlightedLyricID) { _, newValue in
                    guard !isBrowsingLyrics, let newValue else { return }
                    moveFocus(to: newValue, animated: true)
                }
                .onAppear {
                    synchronizeFocusIfNeeded()
                }
                .onDisappear {
                    browsingGeneration += 1
                }
            }
        }
    }

    private var lyricsFocusPosition: CGFloat {
        CGFloat(min(max(settings.lyricsFocusPosition, 0.2), 0.5))
    }

    private func lyricAccessibilityValue(
        isPlaybackLine: Bool,
        isBrowsingFocus: Bool
    ) -> String {
        switch (isPlaybackLine, isBrowsingFocus) {
        case (true, true): "当前播放，浏览焦点"
        case (true, false): "当前播放"
        case (false, true): "浏览焦点"
        case (false, false): ""
        }
    }

    nonisolated private static func lyricBlurRadius(
        forPixelDistance distance: CGFloat,
        lyricStride: CGFloat,
        intensity: CGFloat
    ) -> CGFloat {
        let lineDistance = distance / lyricStride
        let blurProgress = max(lineDistance - 1.35, 0)
        let baseRadius = min(blurProgress * 3.1, 10)
        return baseRadius * intensity
    }

    nonisolated private static func lyricOpacity(
        forPixelDistance distance: CGFloat,
        lyricStride: CGFloat,
        dimAmount: Double
    ) -> Double {
        let lineDistance = Double(distance / lyricStride)
        let baseOpacity: Double
        switch lineDistance {
        case ...1:
            baseOpacity = 1 - lineDistance * 0.32
        case ...2:
            baseOpacity = 0.68 - (lineDistance - 1) * 0.26
        default:
            baseOpacity = max(0.16, 0.42 - (lineDistance - 2) * 0.08)
        }
        return 1 - (1 - baseOpacity) * dimAmount
    }

    private func schedulePlaybackFollowing() {
        guard isBrowsingLyrics, settings.lyricsAutoFollow else { return }
        let generation = browsingGeneration
        let delay = settings.lyricsFollowDelay

        Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard generation == browsingGeneration else { return }
            isBrowsingLyrics = false
            guard let highlightedLyricID else { return }
            moveFocus(to: highlightedLyricID, animated: true)
        }
    }

    private func synchronizeFocusIfNeeded() {
        let existingFocusIsValid = scrollPositionID.map { focusedID in
            lyrics.contains { $0.id == focusedID }
        } ?? false
        guard !existingFocusIsValid else { return }

        guard let initialID = highlightedLyricID ?? lyrics.first?.id else { return }
        moveFocus(to: initialID, animated: false)
    }

    private func seek(to line: LyricLine) {
        guard settings.lyricsTapToSeek else { return }
        browsingGeneration += 1
        isBrowsingLyrics = false
        moveFocus(to: line.id, animated: true)
        player.seek(to: line.time)
    }

    private func moveFocus(to id: LyricLine.ID, animated: Bool) {
        let update = {
            scrollPositionID = id
        }

        if animated {
            withAnimation(.smooth(duration: 0.45), update)
        } else {
            update()
        }
    }
}
