import CoreGraphics

struct MusicCollectionDetailMetrics {
    var viewport = CGSize.zero
    var isTablet = false
    var usesAccessibilityText = false

    static let horizontalPadding: CGFloat = 32
    static let columnSpacing: CGFloat = 32

    var usesAdaptiveHeader: Bool { isTablet || viewport.width >= 600 }
    var usesWideHeader: Bool {
        usesAdaptiveHeader && viewport.width >= 760 && viewport.height >= 420
    }
    var usesInlineHeader: Bool {
        usesAdaptiveHeader && viewport.width >= 500 && !usesAccessibilityText
    }

    var headerWidth: CGFloat {
        return max(viewport.width - Self.horizontalPadding * 2, 1)
    }

    var artworkSize: CGFloat {
        if usesWideHeader { return max(min(320, headerWidth * 0.35, viewport.height * 0.45), 96) }
        if usesInlineHeader { return max(min(180, viewport.width * 0.24, viewport.height * 0.35), 96) }
        return max(min(220, headerWidth * 0.64, viewport.height * 0.32), 96)
    }
}
