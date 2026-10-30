import CoreGraphics

struct NowPlayingTabletLayout {
    let viewport: CGSize
    var fillsRegion = false

    static let chromeHeight: CGFloat = 48
    static let lyricsTopPadding: CGFloat = 40
    static let bottomBarHeight: CGFloat = 64

    private var heightProgress: CGFloat {
        min(max((viewport.height - 600) / 168, 0), 1)
    }

    var elementScale: CGFloat {
        min(
            max(viewport.height / 768, 1),
            max(viewport.width / 1_200, 1)
        )
    }

    var contentHeight: CGFloat {
        if fillsRegion { return viewport.height }
        return max(viewport.height - Self.chromeHeight - Self.bottomBarHeight, 0)
    }

    var playerWidth: CGFloat {
        if fillsRegion {
            return max(min((320 + heightProgress * 102) * elementScale, viewport.width - 48), 1)
        }
        // Preserve the desktop proportions while leaving room for both
        // columns in portrait and resizable iPad windows.
        return min((320 + heightProgress * 102) * elementScale, viewport.width * 0.5 - 40)
    }

    var playerLeading: CGFloat {
        viewport.width * 0.25 - playerWidth * 0.5
    }

    var centeredPlayerLeading: CGFloat {
        (viewport.width - playerWidth) * 0.5
    }

    var panelLeading: CGFloat {
        viewport.width * 0.5
    }

    var panelWidth: CGFloat {
        viewport.width * 0.5 - max(24, viewport.width * 0.045)
    }

    private var referenceArtworkSize: CGFloat {
        min((214 + heightProgress * 94) * elementScale, playerWidth * 0.74)
    }

    private var referenceArtworkTopInset: CGFloat {
        let compression = min(max(600 - viewport.height, 0), 50)
        return (54 - compression + heightProgress * 60) * elementScale
    }

    private var referenceMetadataTopInset: CGFloat {
        (70 + heightProgress * 10) * elementScale
    }

    private var verticalCompressionScale: CGFloat {
        // Reserve space for the native touch controls before sizing the
        // artwork and desktop-style whitespace. Short windows can scroll.
        let controlsHeight = 238 + 45 * elementScale
        let artworkSectionHeight = referenceArtworkTopInset
            + referenceArtworkSize
            + referenceMetadataTopInset
        return min(max((contentHeight - controlsHeight) / artworkSectionHeight, 0.6), 1)
    }

    var artworkSize: CGFloat {
        referenceArtworkSize * verticalCompressionScale
    }

    var artworkTopInset: CGFloat {
        referenceArtworkTopInset * verticalCompressionScale
    }

    var metadataTopInset: CGFloat {
        referenceMetadataTopInset * verticalCompressionScale
    }

    var lyricsFocusAnchorOffset: CGFloat {
        artworkTopInset + artworkSize * 0.5 - Self.lyricsTopPadding
    }
}
