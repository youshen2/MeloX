import SwiftUI

/// Hosts Text PV at the player root so its canvas is never constrained by the lyrics panel.
struct TextPVFullScreenPlayerView: View {
    @Binding var page: NowPlayingPage
    @Binding var showsControls: Bool

    let song: Song
    let lyrics: [LyricLine]
    let errorMessage: String?
    let highlightedLyricID: LyricLine.ID?
    let onDismiss: () -> Void
    let onToggleInterface: () -> Void

    var body: some View {
        Group {
            if #available(iOS 27.1, *) {
                ArrangementView {
                    chrome
                } secondary: {
                    lyricsContent
                }
                .arrangementViewStyle(.overlay)
            } else {
                ZStack {
                    lyricsContent
                    chrome
                }
            }
        }
        .background {
            Color.black.ignoresSafeArea()
        }
        .accessibilityAction(
            named: showsControls
                ? L10n.string("ui.player.hide_controls")
                : L10n.string("ui.player.show_controls")
        ) {
            onToggleInterface()
        }
    }

    private var lyricsContent: some View {
        TextPVLyricsView(
            lyrics: lyrics,
            errorMessage: errorMessage,
            highlightedLyricID: highlightedLyricID,
            onToggleInterface: onToggleInterface
        )
    }

    private var chrome: some View {
        GeometryReader { proxy in
            playerChrome(isLandscape: proxy.size.width > proxy.size.height)
        }
        .opacity(showsControls ? 1 : 0)
        .allowsHitTesting(showsControls)
        .accessibilityHidden(!showsControls)
    }

    private func playerChrome(isLandscape: Bool) -> some View {
        ZStack {
            controlBackground(isLandscape: isLandscape)

            ViewThatFits(in: .vertical) {
                chromeControls(isLandscape: isLandscape)

                ScrollView {
                    chromeControls(isLandscape: isLandscape)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, isLandscape ? 32 : 28)
            .safeAreaPadding(.top, 4)
            .safeAreaPadding(.bottom, 8)
        }
    }

    private func chromeControls(isLandscape: Bool) -> some View {
        VStack(spacing: 0) {
            dismissalHandle

            Spacer(minLength: 0)

            controls
                .frame(maxWidth: isLandscape ? 680 : .infinity)
                .frame(maxWidth: .infinity)
        }
    }

    private func controlBackground(isLandscape: Bool) -> some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0.48), .black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 112)

            Spacer(minLength: 0)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.28), location: 0.24),
                    .init(color: .black.opacity(0.82), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: isLandscape ? 282 : 330)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var controls: some View {
        VStack(spacing: 0) {
            NowPlayingProgressControl(song: song)
            NowPlayingTransportControls()
            NowPlayingVolumeControl()
            NowPlayingPageSelector(page: $page)
        }
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
        .frame(height: 52)
        .accessibilityLabel("ui.player.collapse")
        .accessibilityHint("ui.player.collapse_hint")
    }
}
