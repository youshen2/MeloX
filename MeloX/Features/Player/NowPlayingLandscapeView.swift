import SwiftUI

struct NowPlayingLandscapeView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @Binding var page: NowPlayingPage
    @Binding var showsLyricsControls: Bool

    let song: Song
    let lyrics: [LyricLine]
    let lyricError: String?
    let highlightedLyricID: LyricLine.ID?
    let artworkNamespace: Namespace.ID
    let onDismiss: () -> Void

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
        .gesture(dismissalDragGesture)
    }

    private func artwork(side: CGFloat) -> some View {
        ArtworkImage(url: song.album?.artworkURL, cornerRadius: 12)
            .frame(width: side, height: side)
            .scaleEffect(player.isPlaying || !settings.shrinksPausedArtwork ? 1 : 0.9)
            .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
            .animation(.smooth(duration: 0.45), value: player.isPlaying)
            .contentShape(.rect)
            .onTapGesture(perform: toggleArtworkDetails)
            .accessibilityElement()
            .accessibilityLabel(page == .details ? "返回封面" : "查看歌曲资料")
            .accessibilityHint("轻点切换封面和歌曲资料")
            .accessibilityAction {
                toggleArtworkDetails()
            }
    }

    private var rightPanel: some View {
        VStack(spacing: 0) {
            songHeader

            if usesExpandedAppleMusicLyricsLayout {
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        pageSelector
                    }
            } else {
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                pageSelector
            }
        }
    }

    private var pageSelector: some View {
        NowPlayingPageSelector(page: $page)
            .opacity(hidesLyricsControls ? 0 : 1)
            .allowsHitTesting(!hidesLyricsControls)
            .accessibilityHidden(hidesLyricsControls)
    }

    private var hidesLyricsControls: Bool {
        page == .lyrics && !showsLyricsControls
    }

    private var usesExpandedAppleMusicLyricsLayout: Bool {
        page == .lyrics && settings.lyricsStyle == .appleMusic
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

            NowPlayingSongActions(
                song: song,
                isShowingDetails: page == .details,
                onToggleDetails: toggleArtworkDetails
            )
        }
        .frame(height: 52)
    }

    private var pageContent: some View {
        Group {
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
            case .details:
                NowPlayingSongDetailsPage(
                    song: song,
                    showsArtworkToggle: false,
                    artworkNamespace: artworkNamespace,
                    onShowArtwork: toggleArtworkDetails
                )
                .transition(.opacity)
            case .lyrics:
                NowPlayingLyricsPage(
                    song: song,
                    lyrics: lyrics,
                    errorMessage: lyricError,
                    highlightedLyricID: highlightedLyricID,
                    presentation: .landscape,
                    isInterfaceHidden: hidesLyricsControls,
                    artworkNamespace: artworkNamespace,
                    onToggleInterface: toggleLyricsControls,
                    onShowDetails: { page = .details }
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

    private func toggleArtworkDetails() {
        withAnimation(accessibilityReduceMotion ? nil : .smooth(duration: 0.3)) {
            page = page == .details ? .artwork : .details
        }
    }

    private var dismissalDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                guard value.translation.height > 60,
                      abs(value.translation.height) > abs(value.translation.width) else {
                    return
                }
                onDismiss()
            }
    }
}
