import SwiftUI

enum NowPlayingLyricsPresentation: Equatable {
    case portrait
    case landscape
    case tablet
}

struct NowPlayingLyricsPage: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(AppSettings.self) private var settings

    let song: Song
    let lyrics: [LyricLine]
    let errorMessage: String?
    let highlightedLyricID: LyricLine.ID?
    let isActive: Bool
    let presentation: NowPlayingLyricsPresentation
    let isInterfaceHidden: Bool
    let artworkNamespace: Namespace.ID
    let usesArtworkTransition: Bool
    let showsSongHeader: Bool
    let focusAnchorOffset: CGFloat?
    let onInterfaceInteraction: (() -> Void)?
    let onInterfaceVisibilityChange: ((Bool) -> Void)?
    let onInitialFocusPrepared: (() -> Void)?

    init(
        song: Song,
        lyrics: [LyricLine],
        errorMessage: String?,
        highlightedLyricID: LyricLine.ID?,
        isActive: Bool = true,
        presentation: NowPlayingLyricsPresentation = .portrait,
        isInterfaceHidden: Bool = false,
        artworkNamespace: Namespace.ID,
        usesArtworkTransition: Bool = true,
        showsSongHeader: Bool = true,
        focusAnchorOffset: CGFloat? = nil,
        onInterfaceInteraction: (() -> Void)? = nil,
        onInterfaceVisibilityChange: ((Bool) -> Void)? = nil,
        onInitialFocusPrepared: (() -> Void)? = nil
    ) {
        self.song = song
        self.lyrics = lyrics
        self.errorMessage = errorMessage
        self.highlightedLyricID = highlightedLyricID
        self.isActive = isActive
        self.presentation = presentation
        self.isInterfaceHidden = isInterfaceHidden
        self.artworkNamespace = artworkNamespace
        self.usesArtworkTransition = usesArtworkTransition
        self.showsSongHeader = showsSongHeader
        self.focusAnchorOffset = focusAnchorOffset
        self.onInterfaceInteraction = onInterfaceInteraction
        self.onInterfaceVisibilityChange = onInterfaceVisibilityChange
        self.onInitialFocusPrepared = onInitialFocusPrepared
    }

    var body: some View {
        VStack(spacing: lyricsContentSpacing) {
            if presentation == .portrait, showsSongHeader {
                songHeader
            }

            lyricsStyleContent
                .id(settings.lyricsStyle)
                .transition(.opacity)
        }
        .padding(.top, sharedSongHeaderInset)
        .padding(.bottom, portraitContentBottomInset)
        .animation(
            accessibilityReduceMotion ? nil : .smooth(duration: 0.3),
            value: settings.lyricsStyle
        )
    }

    private var songHeader: some View {
        NowPlayingSongHeader(
            song: song,
            artworkNamespace: artworkNamespace,
            usesReferenceLayout: usesReferencePortraitLayout,
            usesArtworkTransition: usesArtworkTransition
        )
    }

    @ViewBuilder
    private var lyricsStyleContent: some View {
        switch settings.lyricsStyle {
        case .appleMusic:
            AppleMusicLyricsView(
                lyrics: lyrics,
                errorMessage: errorMessage,
                highlightedLyricID: highlightedLyricID,
                isActive: isActive,
                isInterfaceHidden: isInterfaceHidden,
                bottomOverlayHeight: appleMusicBottomOverlayHeight,
                focusAnchorOffset: focusAnchorOffset,
                onInterfaceInteraction: onInterfaceInteraction,
                onInterfaceVisibilityChange:
                    onInterfaceVisibilityChange,
                onInitialFocusPrepared: onInitialFocusPrepared
            )
        case .eva:
            EVALyricsView(
                lyrics: lyrics,
                errorMessage: errorMessage,
                highlightedLyricID: highlightedLyricID,
                onToggleInterface: onInterfaceInteraction
            )
        case .textPV:
            TextPVLyricsView(
                lyrics: lyrics,
                errorMessage: errorMessage,
                highlightedLyricID: highlightedLyricID,
                onToggleInterface: onInterfaceInteraction
            )
        }
    }

    private var appleMusicBottomOverlayHeight: CGFloat {
        switch presentation {
        case .portrait:
            NowPlayingBottomControls.overlayHeight
        case .landscape:
            50
        case .tablet:
            0
        }
    }

    private var portraitContentBottomInset: CGFloat {
        guard presentation == .portrait else { return 0 }
        return settings.lyricsStyle == .appleMusic
            ? 12
            : NowPlayingBottomControls.coreHeight
    }

    private var usesReferencePortraitLayout: Bool {
        presentation == .portrait && settings.lyricsStyle == .appleMusic
    }

    private var lyricsContentSpacing: CGFloat {
        guard presentation == .portrait else { return 0 }
        return usesReferencePortraitLayout ? 16 : 18
    }

    private var sharedSongHeaderInset: CGFloat {
        guard presentation == .portrait, !showsSongHeader else {
            return 0
        }
        return NowPlayingSongHeader.referenceHeight
            + lyricsContentSpacing
    }

}
