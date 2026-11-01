import CoreGraphics

/// Apple Music's iPad Top Picks uses portrait cards in a horizontal shelf.
/// Fit complete cards to this window while reserving room for the following section.
struct ExploreFeaturedMetrics {
    var viewport = CGSize(width: 390, height: 700)
    var isTablet = false

    var usesPortraitCards: Bool { isTablet || viewport.width >= 600 }
    var horizontalPadding: CGFloat { usesPortraitCards ? 24 : 16 }
    var spacing: CGFloat { usesPortraitCards ? 20 : 16 }
    var aspectRatio: CGFloat { usesPortraitCards ? 0.75 : 1.55 }
    var featuredCount: Int { usesPortraitCards ? max(4, visibleCardCount) : 1 }

    var contentWidth: CGFloat { max(viewport.width - horizontalPadding * 2, 1) }

    private var maximumCardWidth: CGFloat {
        let heightLimit = min(max(viewport.height * 0.48, 180), 360)
        return min(280, heightLimit * aspectRatio)
    }

    var visibleCardCount: Int {
        guard usesPortraitCards else { return 1 }
        return max(Int(((contentWidth + spacing) / (maximumCardWidth + spacing)).rounded(.up)), 1)
    }

    var cardWidth: CGFloat {
        guard usesPortraitCards else { return contentWidth }
        let totalSpacing = spacing * CGFloat(visibleCardCount - 1)
        let fittedWidth = (contentWidth - totalSpacing) / CGFloat(visibleCardCount)
        return max(min(fittedWidth, maximumCardWidth), 1)
    }

    var cardHeight: CGFloat { cardWidth / aspectRatio }
}
