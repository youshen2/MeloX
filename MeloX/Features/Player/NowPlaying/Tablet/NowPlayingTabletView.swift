import SwiftUI

struct NowPlayingTabletView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(AppSettings.self) private var settings

    @Binding var page: NowPlayingPage
    let pageTransition: NowPlayingTransitionCoordinator
    let song: Song
    let lyrics: [LyricLine]
    let lyricError: String?
    let highlightedLyricID: LyricLine.ID?
    let artworkNamespace: Namespace.ID
    let onDismiss: () -> Void
    let onExpandLyrics: () -> Void
    let onLyricsContentPrepared: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if #available(iOS 27.1, *) {
                NowPlayingAdaptiveView(
                    page: $page,
                    pageTransition: pageTransition,
                    song: song,
                    lyrics: lyrics,
                    lyricError: lyricError,
                    highlightedLyricID: highlightedLyricID,
                    artworkNamespace: artworkNamespace,
                    onDismiss: onDismiss,
                    onExpandLyrics: onExpandLyrics,
                    onLyricsContentPrepared: onLyricsContentPrepared
                )
            } else {
                GeometryReader { proxy in
                    let layout = NowPlayingTabletLayout(viewport: proxy.size)

                    standardPlayer(layout: layout)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .transition(.opacity)
            }
        }
    }

    private func standardPlayer(layout: NowPlayingTabletLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                NowPlayingTabletPlayerColumn(song: song, layout: layout)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .frame(width: layout.playerWidth, height: layout.contentHeight)
            .offset(
                x: page == .artwork ? layout.centeredPlayerLeading : layout.playerLeading,
                y: NowPlayingTabletLayout.chromeHeight
            )
            .animation(
                accessibilityReduceMotion ? nil : NowPlayingPageTransition.motion.artworkResize.animation,
                value: page
            )

            NowPlayingTabletPanels(
                pageTransition: pageTransition,
                song: song,
                lyrics: lyrics,
                lyricError: lyricError,
                highlightedLyricID: highlightedLyricID,
                artworkNamespace: artworkNamespace,
                focusAnchorOffset: layout.lyricsFocusAnchorOffset,
                onLyricsContentPrepared: onLyricsContentPrepared
            )
            .frame(width: layout.panelWidth, height: layout.contentHeight)
            .offset(x: layout.panelLeading, y: NowPlayingTabletLayout.chromeHeight)

            chrome
        }
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: .circle)
                .accessibilityLabel("ui.player.collapse")

                Spacer()
            }
            .frame(height: NowPlayingTabletLayout.chromeHeight)

            Spacer(minLength: 0)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    FloatingLyricsButton()

                    if page == .lyrics {
                        if lyrics.contains(where: { $0.hasTranslation || $0.hasRomanization }) {
                            NowPlayingLyricsLanguageButton(
                                hasTranslations: lyrics.contains(where: \.hasTranslation),
                                hasRomanizations: lyrics.contains(where: \.hasRomanization)
                            )
                        }

                        if !lyrics.isEmpty {
                            Button(action: onExpandLyrics) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.clear.interactive(), in: .circle)
                            .accessibilityLabel(
                                settings.lyricsStyle == .textPV
                                    ? L10n.string("ui.settings.lyrics.style.text_pv")
                                    : L10n.string("ui.settings.skyline.title")
                            )
                        }
                    }

                    Spacer(minLength: 0)

                    NowPlayingTabletPageSwitcher(page: $page)
                }
            }
            .frame(height: NowPlayingTabletLayout.bottomBarHeight)
        }
        .padding(.horizontal, 20)
        .foregroundStyle(.white)
    }
}
