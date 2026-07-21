import SwiftUI

struct NowPlayingLandscapeView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @Binding var page: NowPlayingPage

    let song: Song
    let lyrics: [LyricLine]
    let lyricError: String?
    let highlightedLyricID: LyricLine.ID?
    let onDismiss: () -> Void
    let onShowAudioOutputHelp: () -> Void

    @State private var showsLyricsControls = true
    @State private var showsSkylineLyrics = false

    var body: some View {
        ZStack {
            if showsSkylineLyrics, page == .lyrics {
                SkylineLyricsView(
                    artworkURL: song.album?.artworkURL,
                    lyrics: lyrics,
                    errorMessage: lyricError,
                    highlightedLyricID: highlightedLyricID,
                    onExit: exitSkylineLyrics
                )
                .transition(.opacity)
            } else {
                standardPlayer
                    .transition(.opacity)
            }
        }
        .onChange(of: page) { _, newPage in
            if newPage != .lyrics {
                showsLyricsControls = true
                showsSkylineLyrics = false
            }
        }
        .animation(
            accessibilityReduceMotion ? nil : .smooth(duration: 0.4),
            value: showsSkylineLyrics
        )
    }

    private var standardPlayer: some View {
        VStack(spacing: 0) {
            dismissalHandle

            GeometryReader { proxy in
                let artworkSide = min(
                    proxy.size.height,
                    proxy.size.width * 0.43,
                    460
                )

                HStack(spacing: landscapeSpacing(for: proxy.size.width)) {
                    artwork(side: artworkSide)

                    rightPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: 1_100, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .safeAreaPadding(.top, 2)
        .safeAreaPadding(.bottom, 8)
    }

    private var dismissalHandle: some View {
        Button(action: onDismiss) {
            Capsule()
                .fill(.white.opacity(0.52))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(height: 28)
        .accessibilityLabel("收起播放器")
        .accessibilityHint("轻点收起，或向下拖动播放器")
    }

    private func artwork(side: CGFloat) -> some View {
        ArtworkImage(url: song.album?.artworkURL, cornerRadius: 12)
            .frame(width: side, height: side)
            .scaleEffect(player.isPlaying || !settings.shrinksPausedArtwork ? 1 : 0.9)
            .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
            .animation(.smooth(duration: 0.45), value: player.isPlaying)
    }

    private var rightPanel: some View {
        VStack(spacing: 0) {
            songHeader

            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if page != .lyrics || showsLyricsControls {
                NowPlayingPageSelector(
                    page: $page,
                    onShowAudioOutputHelp: onShowAudioOutputHelp
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var songHeader: some View {
        HStack(spacing: 12) {
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

            if page == .lyrics, !lyrics.isEmpty {
                Button(action: enterSkylineLyrics) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title3.weight(.medium))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.13), in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开全屏天际歌词")
            }

            NowPlayingSongActions(song: song)
        }
        .frame(height: 52)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .artwork:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                NowPlayingProgressControl(song: song)
                NowPlayingTransportControls()
                NowPlayingVolumeControl()
                Spacer(minLength: 0)
            }
            .transition(.opacity)
        case .lyrics:
            NowPlayingLyricsPage(
                song: song,
                lyrics: lyrics,
                errorMessage: lyricError,
                highlightedLyricID: highlightedLyricID,
                presentation: .landscape,
                onToggleInterface: toggleLyricsControls
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

    private func landscapeSpacing(for width: CGFloat) -> CGFloat {
        min(max(width * 0.035, 18), 38)
    }

    private func toggleLyricsControls() {
        withAnimation(accessibilityReduceMotion ? nil : .smooth(duration: 0.3)) {
            showsLyricsControls.toggle()
        }
    }

    private func enterSkylineLyrics() {
        showsSkylineLyrics = true
    }

    private func exitSkylineLyrics() {
        showsSkylineLyrics = false
    }
}
