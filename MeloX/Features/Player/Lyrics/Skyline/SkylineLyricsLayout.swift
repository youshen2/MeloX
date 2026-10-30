import SwiftUI

nonisolated enum SkylineLyricRole: Equatable {
    case previous
    case current
    case next
}

nonisolated struct SkylineLyricRoleKey: LayoutValueKey {
    static let defaultValue = SkylineLyricRole.current
}

struct SkylineLyricsLayout: Layout {
    let size: CGSize
    let previewScale: CGFloat
    let maximumPlaybackScale: CGFloat
    let spacing: CGFloat
    let outgoingTravel: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        // Keep the stage independent of lyric length and the last preview.
        size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let textProposal = ProposedViewSize(width: size.width, height: nil)
        let currentHeight = subviews.first {
            $0[SkylineLyricRoleKey.self] == .current
        }?.sizeThatFits(textProposal).height ?? 0

        for subview in subviews {
            let offset: CGFloat
            switch subview[SkylineLyricRoleKey.self] {
            case .previous:
                offset = -outgoingTravel
            case .current:
                offset = 0
            case .next:
                let previewHeight = subview.sizeThatFits(textProposal).height
                offset = currentHeight * max(maximumPlaybackScale, 1) * 0.5
                    + spacing
                    + previewHeight * previewScale * 0.5
            }

            subview.place(
                at: CGPoint(x: bounds.midX, y: bounds.midY + offset),
                anchor: .center,
                proposal: textProposal
            )
        }
    }
}
