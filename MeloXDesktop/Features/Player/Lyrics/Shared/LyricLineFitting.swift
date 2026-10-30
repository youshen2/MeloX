import SwiftUI

enum LyricLineFitting {
    static func validWidth(_ width: CGFloat?) -> CGFloat? {
        guard let width, width.isFinite, width > 0 else {
            return nil
        }
        return width
    }

    static func drawingScale(
        for layout: Text.Layout,
        constrainedWidth: CGFloat?,
        trailingSafety: CGFloat
    ) -> CGFloat? {
        guard let width = validWidth(constrainedWidth) else {
            return nil
        }

        let widestLine = layout.reduce(CGFloat.zero) { widest, line in
            let lineWidth = line.typographicBounds.rect.width
            return lineWidth.isFinite ? max(widest, lineWidth) : widest
        }
        guard widestLine > 0 else { return nil }

        let availableWidth = max(
            width - max(trailingSafety, 0),
            1
        )
        // A wrapped lyric is one phrase: fit every visual line with the
        // same scale so shorter lines keep the same glyph size as full lines.
        return min(max(availableWidth / widestLine, 0), 1)
    }

    static func drawingTransform(
        for line: Text.Layout.Line,
        scale: CGFloat?,
        centersLine: Bool
    ) -> CGAffineTransform? {
        guard let scale else { return nil }

        let bounds = line.typographicBounds.rect
        guard bounds.width.isFinite,
              bounds.width > 0,
              bounds.minX.isFinite,
              bounds.midY.isFinite else {
            return nil
        }

        let translationX: CGFloat
        if centersLine {
            // SwiftUI has already positioned centered lines. Re-centering
            // them against the renderer width applies the alignment twice
            // and shifts the whole lyric to the right. Preserve that native
            // center and only scale around it when the line is too wide.
            guard scale < 1 else { return nil }
            translationX = bounds.midX * (1 - scale)
        } else {
            translationX = -bounds.minX * scale
        }
        let translationY = bounds.midY * (1 - scale)

        guard scale < 1
                || abs(translationX) > 0.001
                || abs(translationY) > 0.001 else {
            return nil
        }
        return CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: scale,
            tx: translationX,
            ty: translationY
        )
    }
}
