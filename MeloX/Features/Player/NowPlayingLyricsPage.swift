import SwiftUI

enum NowPlayingLyricsPresentation: Equatable {
    case portrait
    case landscape
}

struct NowPlayingLyricsPage: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(AppSettings.self) private var settings

    let song: Song
    let lyrics: [LyricLine]
    let errorMessage: String?
    let highlightedLyricID: LyricLine.ID?
    let presentation: NowPlayingLyricsPresentation
    let artworkNamespace: Namespace.ID
    let onToggleInterface: (() -> Void)?
    let onShowDetails: (() -> Void)?

    init(
        song: Song,
        lyrics: [LyricLine],
        errorMessage: String?,
        highlightedLyricID: LyricLine.ID?,
        presentation: NowPlayingLyricsPresentation = .portrait,
        artworkNamespace: Namespace.ID,
        onToggleInterface: (() -> Void)? = nil,
        onShowDetails: (() -> Void)? = nil
    ) {
        self.song = song
        self.lyrics = lyrics
        self.errorMessage = errorMessage
        self.highlightedLyricID = highlightedLyricID
        self.presentation = presentation
        self.artworkNamespace = artworkNamespace
        self.onToggleInterface = onToggleInterface
        self.onShowDetails = onShowDetails
    }

    var body: some View {
        VStack(spacing: presentation == .portrait ? 18 : 0) {
            if presentation == .portrait {
                songHeader
            }

            lyricsStyleContent
                .id(settings.lyricsStyle)
                .transition(.opacity)
        }
        .padding(.bottom, presentation == .portrait ? 12 : 0)
        .keepsScreenAwake(settings.lyricsKeepsScreenAwake)
        .animation(
            accessibilityReduceMotion ? nil : .smooth(duration: 0.3),
            value: settings.lyricsStyle
        )
    }

    private var songHeader: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: song.album?.artworkURL, cornerRadius: 10)
                .matchedGeometryEffect(
                    id: song.id,
                    in: artworkNamespace,
                    properties: .frame
                )
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

            NowPlayingSongActions(
                song: song,
                isShowingDetails: false,
                onToggleDetails: { onShowDetails?() }
            )
        }
    }

    @ViewBuilder
    private var lyricsStyleContent: some View {
        switch settings.lyricsStyle {
        case .appleMusic:
            AppleMusicLyricsView(
                lyrics: lyrics,
                errorMessage: errorMessage,
                highlightedLyricID: highlightedLyricID,
                onToggleInterface: onToggleInterface
            )
        case .eva:
            EVALyricsView(
                lyrics: lyrics,
                errorMessage: errorMessage,
                highlightedLyricID: highlightedLyricID,
                onToggleInterface: onToggleInterface
            )
        }
    }
}
