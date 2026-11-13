import CoreGraphics
import Foundation

@main
struct ValidateTabletLayout {
    static func main() {
        let viewports: [CGSize] = [
            CGSize(width: 700, height: 500),
            CGSize(width: 744, height: 1_080),
            CGSize(width: 768, height: 1_024),
            CGSize(width: 834, height: 1_194),
            CGSize(width: 1_024, height: 768),
            CGSize(width: 1_194, height: 834),
            CGSize(width: 1_366, height: 1_024),
            CGSize(width: 1_600, height: 900),
        ]
        for size in viewports {
            let layout = NowPlayingTabletLayout(viewport: size)
            precondition(layout.playerWidth > 0 && layout.panelWidth > 0)
            precondition(layout.artworkSize > 0 && layout.artworkSize <= layout.playerWidth)
            precondition(layout.playerLeading >= 0)
            precondition(layout.panelLeading >= layout.playerLeading + layout.playerWidth)
            precondition(layout.panelLeading + layout.panelWidth <= size.width)
            precondition(layout.centeredPlayerLeading >= 0)
            precondition(layout.elementScale == 1, "Native controls must remain a consistent size.")
        }
        for width in [CGFloat(320), 420, 600, 900] {
            let layout = NowPlayingTabletLayout(viewport: CGSize(width: width, height: 700), fillsRegion: true)
            precondition(layout.artworkSize <= layout.playerWidth)
            precondition(layout.playerWidth + 48 <= width)
        }
        for size in [CGSize(width: 320, height: 500), CGSize(width: 700, height: 500), CGSize(width: 760, height: 420), CGSize(width: 1_280, height: 750)] {
            let detail = MusicCollectionDetailMetrics(viewport: size, isTablet: true)
            precondition(detail.artworkSize > 0 && detail.artworkSize <= 320)
            precondition(detail.artworkSize <= detail.headerWidth)
            precondition(detail.headerWidth <= size.width)
        }
        for size in [CGSize(width: 440, height: 700), CGSize(width: 740, height: 900), CGSize(width: 900, height: 650), CGSize(width: 1_000, height: 650), CGSize(width: 1_280, height: 800), CGSize(width: 1_600, height: 900)] {
            let discovery = ExploreFeaturedMetrics(viewport: size, isTablet: true)
            precondition(discovery.cardWidth <= 280)
            precondition(discovery.cardHeight <= 360)
            precondition(discovery.cardHeight <= size.height * 0.5)
            precondition(discovery.featuredCount > 1)
            let visibleShelfWidth = discovery.cardWidth * CGFloat(discovery.visibleCardCount) + discovery.spacing * CGFloat(discovery.visibleCardCount - 1)
            precondition(abs(visibleShelfWidth - (size.width - discovery.horizontalPadding * 2)) < 0.5, "Complete cards should fill the same content width as the playlist grid.")
        }
        print("PASS: iPad portrait, landscape, short windows, and divided display layout bounds.")
    }
}
