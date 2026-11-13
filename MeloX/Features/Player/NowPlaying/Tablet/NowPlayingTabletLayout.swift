import CoreGraphics

/// Sizes follow this window, including Split View and Stage Manager.
/// Text and touch targets do not grow with the physical screen's dimensions.
struct NowPlayingTabletLayout {
    let viewport: CGSize
    var fillsRegion = false

    static let chromeHeight: CGFloat = 56
    static let lyricsTopPadding: CGFloat = 32
    static let bottomBarHeight: CGFloat = 72

    var elementScale: CGFloat { 1 }

    var contentHeight: CGFloat {
        max(viewport.height - (fillsRegion ? 0 : Self.chromeHeight + Self.bottomBarHeight), 0)
    }

    private var horizontalMargin: CGFloat {
        min(max(viewport.width * 0.045, 28), 64)
    }

    private var contentWidth: CGFloat {
        max(min(viewport.width - horizontalMargin * 2, 1_200), 1)
    }

    private var columnSpacing: CGFloat {
        min(max(viewport.width * 0.05, 32), 80)
    }

    var playerWidth: CGFloat {
        if fillsRegion {
            return max(min(viewport.width - 48, 430), 1)
        }
        return max(min((contentWidth - columnSpacing) * 0.46, 430), 1)
    }

    var playerLeading: CGFloat {
        (viewport.width - contentWidth) * 0.5
    }

    var centeredPlayerLeading: CGFloat {
        (viewport.width - playerWidth) * 0.5
    }

    var panelLeading: CGFloat {
        playerLeading + playerWidth + columnSpacing
    }

    var panelWidth: CGFloat {
        max(contentWidth - playerWidth - columnSpacing, 1)
    }

    var artworkTopInset: CGFloat {
        min(max((contentHeight - playerWidth - 280) * 0.5, 16), 64)
    }

    var metadataTopInset: CGFloat {
        contentHeight < 600 ? 24 : 32
    }

    var artworkSize: CGFloat {
        // Reduce the cover before compressing native controls. Short windows
        // and larger accessibility text can scroll the entire player column.
        min(playerWidth, max(contentHeight - artworkTopInset - metadataTopInset - 260, 140))
    }

    var lyricsFocusAnchorOffset: CGFloat {
        artworkTopInset + artworkSize * 0.5 - Self.lyricsTopPadding
    }
}
