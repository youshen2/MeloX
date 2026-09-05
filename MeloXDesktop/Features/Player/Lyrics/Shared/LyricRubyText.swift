import SwiftUI

struct LyricRubyText: View {
    let rows: [LyricRubyRow]
    let fontSize: CGFloat
    let romanizationFontSize: CGFloat
    let fontWeight: LyricsFontWeight
    let primaryColor: Color
    let romanizationOpacity: Double
    let alignment: SynchronizedLyricTextAlignment
    let annotationSpacing: CGFloat
    /// Geometry and opacity are intentionally separate. Music.app's LyricsX
    /// lays out primary/transliteration/translation layers independently;
    /// retaining this slot prevents a focused-line pronunciation reveal from
    /// changing the lyric row's anchor.
    let annotationLayoutExpansion: CGFloat
    let annotationVisibility: CGFloat
    let playbackTime: TimeInterval
    let rendererStyle: LyricGlowTextRenderer.Style
    let appliesTimingEffects: Bool
    let timingEffectsStrength: Double

    var body: some View {
        VStack(
            alignment: alignment.horizontalAlignment,
            spacing: max(fontSize * 0.06, 2)
        ) {
            ForEach(rows) { row in
                LyricAnnotationLayout(
                    expansion: annotationLayoutExpansion,
                    spacing: annotationSpacing
                ) {
                    originalView(for: row)
                    romanizationView(for: row)
                }
                .frame(
                    width: row.width,
                    alignment: .leading
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: alignment.frameAlignment
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.plainOriginalText)
            }
        }
    }

    private func originalView(
        for row: LyricRubyRow
    ) -> some View {
        row.originalText
            .font(
                .system(
                    size: fontSize,
                    weight: fontWeight.swiftUIWeight
                )
            )
            .foregroundStyle(primaryColor)
            // Ruby runs are positioned by explicit horizontal offsets, so
            // they must always start at the row's leading edge. The inherited
            // trailing alignment would otherwise shift the line to the right
            // and let the offsets push the final character out of the lyric
            // panel for right-aligned duet lines.
            .multilineTextAlignment(.leading)
            .fixedSize()
            .textRenderer(
                LyricGlowTextRenderer(
                    playbackTime: playbackTime,
                    style: rendererStyle,
                    layoutConfiguration: .init(
                        width: nil,
                        centersLines: false,
                        trailingVisualOverflow:
                            row.originalTrailingVisualOverflow
                    ),
                    appliesTimingEffects: appliesTimingEffects,
                    timingEffectsStrength: timingEffectsStrength
                )
            )
            .transaction { $0.animation = nil }
            .frame(
                width: row.width,
                alignment: .leading
            )
    }

    private func romanizationView(
        for row: LyricRubyRow
    ) -> some View {
        row.romanizationText
            .font(
                .system(
                    size: romanizationFontSize,
                    weight: fontWeight.swiftUIWeight
                )
            )
            .foregroundStyle(
                primaryColor.opacity(romanizationOpacity)
            )
            // Same as the primary row: ruby placement owns its horizontal
            // offsets, so keep line alignment leading to avoid pushing a
            // trailing-aligned duet row past the panel's right edge.
            .multilineTextAlignment(.leading)
            .fixedSize()
            .textRenderer(
                LyricRomanizationTextRenderer(
                    playbackTime: playbackTime,
                    unplayedOpacity: rendererStyle.unplayedOpacity,
                    trailingVisualOverflow:
                        row.romanizationTrailingVisualOverflow,
                    appliesTimingEffects: appliesTimingEffects,
                    timingEffectsStrength: timingEffectsStrength
                )
            )
            .transaction { $0.animation = nil }
            .frame(
                width: row.width,
                alignment: .leading
            )
            .opacity(annotationVisibility)
            .accessibilityHidden(true)
    }
}
