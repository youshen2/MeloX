// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Native static/dynamic Canvas batching added under the PV Tool Non-Commercial License.

import SwiftUI

struct TextPVBatchedEffectCanvas: View {
    let frame: TextPVRenderContext

    var body: some View {
        ZStack {
            ForEach(TextPVEffectBatch.make(for: frame.template)) { batch in
                if batch.isTimeInvariant {
                    TextPVStaticEffectBatchCanvas(frame: frame, batch: batch)
                        .equatable()
                } else {
                    TextPVDynamicEffectBatchCanvas(frame: frame, batch: batch)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

private struct TextPVStaticEffectBatchCanvas: View, Equatable {
    let frame: TextPVRenderContext
    let batch: TextPVEffectBatch

    static func == (
        lhs: TextPVStaticEffectBatchCanvas,
        rhs: TextPVStaticEffectBatchCanvas
    ) -> Bool {
        lhs.frame.seed == rhs.frame.seed
            && lhs.frame.template.style == rhs.frame.template.style
            && lhs.batch == rhs.batch
    }

    var body: some View {
        TextPVEffectBatchCanvas(frame: frame, batch: batch)
    }
}

private struct TextPVDynamicEffectBatchCanvas: View {
    let frame: TextPVRenderContext
    let batch: TextPVEffectBatch

    var body: some View {
        TextPVEffectBatchCanvas(frame: frame, batch: batch)
    }
}

private struct TextPVEffectBatchCanvas: View {
    let frame: TextPVRenderContext
    let batch: TextPVEffectBatch

    var body: some View {
        Canvas(
            opaque: batch.includesBackground,
            colorMode: .nonLinear,
            rendersAsynchronously: true
        ) { context, size in
            if batch.includesBackground {
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(frame.template.palette.backgroundColor)
                )
            }

            for index in batch.effectIndices {
                let effect = frame.template.effects[index]
                let painter = TextPVEffectPainter(
                    frame: frame,
                    effectIndex: index
                )
                painter.draw(effect, in: &context, size: size)
            }
        } symbols: {
            TextPVCanvasSymbols(
                symbols: batch.usesCanvasSymbols ? frame.canvasSymbols : []
            )
            .equatable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TextPVEffectBatch: Identifiable, Equatable {
    let id: Int
    let isTimeInvariant: Bool
    let effectIndices: [Int]
    let includesBackground: Bool
    let usesCanvasSymbols: Bool

    static func make(for template: TextPVTemplate) -> [Self] {
        let orderedIndices = TextPVLayer.allCases.flatMap { layer in
            template.effects.indices.filter { index in
                template.effects[index].layer == layer
            }
        }

        var batches: [Self] = []
        for effectIndex in orderedIndices {
            let effect = template.effects[effectIndex]
            let isTimeInvariant = effect.isTimeInvariant

            if let last = batches.last,
               last.isTimeInvariant == isTimeInvariant {
                batches[batches.count - 1] = Self(
                    id: last.id,
                    isTimeInvariant: isTimeInvariant,
                    effectIndices: last.effectIndices + [effectIndex],
                    includesBackground: last.includesBackground,
                    usesCanvasSymbols: last.usesCanvasSymbols
                        || effect.kind.usesCanvasSymbols
                )
            } else {
                batches.append(Self(
                    id: batches.count,
                    isTimeInvariant: isTimeInvariant,
                    effectIndices: [effectIndex],
                    includesBackground: batches.isEmpty,
                    usesCanvasSymbols: effect.kind.usesCanvasSymbols
                ))
            }
        }

        return batches
    }
}

private extension TextPVEffectKind {
    var usesCanvasSymbols: Bool {
        self == .fallingText || self == .glowTextCards
    }
}

private extension TextPVEffect {
    var isTimeInvariant: Bool {
        if kind == .filmGrain {
            return config.integer("frameVariants", default: 4) == 1
        }

        return switch kind {
        case .backgroundBlocks, .bloodSplatter, .checkerboard, .colorMask,
             .concentricCircles, .dataMonitors, .desktopIcon, .diagonalHatch,
             .diagonalStructure, .dotScreen, .edgeClouds, .gradientOverlay,
             .halftoneBlocks, .hudCorners, .hudStatusText, .lightSpot,
             .noiseText, .pixelWindow, .planet, .scanlines, .screenBorder,
             .textureBackground, .triangleGrid, .victimOutline, .vignette,
             .webLines:
            true
        default:
            false
        }
    }
}
