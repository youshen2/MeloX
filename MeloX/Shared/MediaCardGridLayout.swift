import SwiftUI

struct MediaCardGridLayout {
    let columns: [GridItem]
    let itemWidth: CGFloat

    init(
        containerWidth: CGFloat,
        horizontalPadding: CGFloat = 16,
        minimumItemWidth: CGFloat = 145,
        spacing: CGFloat = 16
    ) {
        let availableWidth = max(
            containerWidth - horizontalPadding * 2,
            minimumItemWidth
        )
        let columnCount = max(
            Int(
                (availableWidth + spacing)
                    / (minimumItemWidth + spacing)
            ),
            1
        )
        let totalSpacing = spacing * CGFloat(columnCount - 1)
        itemWidth = (availableWidth - totalSpacing) / CGFloat(columnCount)
        columns = Array(
            repeating: GridItem(
                .fixed(itemWidth),
                spacing: spacing,
                alignment: .top
            ),
            count: columnCount
        )
    }
}
