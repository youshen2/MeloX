// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

struct TextPVEffectCanvas: View {
    let frame: TextPVRenderContext

    @ViewBuilder
    var body: some View {
        if frame.template.style == .cyberGrunge {
            TextPVBatchedEffectCanvas(frame: frame)
        } else {
            TextPVSingleEffectCanvas(frame: frame)
        }
    }
}

private struct TextPVSingleEffectCanvas: View {
    let frame: TextPVRenderContext

    var body: some View {
        Canvas(opaque: true, colorMode: .nonLinear, rendersAsynchronously: true) { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(frame.template.palette.backgroundColor)
            )

            for layer in TextPVLayer.allCases {
                for (index, effect) in frame.template.effects.enumerated()
                where effect.layer == layer {
                    let painter = TextPVEffectPainter(
                        frame: frame,
                        effectIndex: index
                    )
                    painter.draw(effect, in: &context, size: size)
                }
            }
        } symbols: {
            TextPVCanvasSymbols(symbols: frame.canvasSymbols)
                .equatable()
        }
        .accessibilityHidden(true)
    }
}

struct TextPVEffectPainter {
    let frame: TextPVRenderContext
    let effectIndex: Int

    var palette: TextPVPalette { frame.template.palette }
    var seed: UInt64 { frame.seed &+ UInt64(effectIndex) &* 0xD1B54A32D192ED03 }

    func draw(
        _ effect: TextPVEffect,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        switch effect.kind {
        case .backgroundBlocks: drawBackgroundBlocks(effect.config, in: &context, size: size)
        case .balancingCircles: drawBalancingCircles(effect.config, in: &context, size: size)
        case .bigOutlineText: drawBigOutlineText(effect.config, in: &context, size: size)
        case .bloodSplatter: drawBloodSplatter(effect.config, in: &context, size: size)
        case .burstLines: drawBurstLines(effect.config, in: &context, size: size)
        case .centeredSquares: drawCenteredSquares(effect.config, in: &context, size: size)
        case .checkerboard: drawCheckerboard(effect.config, in: &context, size: size)
        case .chromaticAberration: drawChromaticAberration(effect.config, in: &context, size: size)
        case .colorMask: drawColorMask(effect.config, in: &context, size: size)
        case .compositionGuides: drawCompositionGuides(effect.config, in: &context, size: size)
        case .concentricCircles: drawConcentricCircles(effect.config, in: &context, size: size)
        case .crayonShatter: drawCrayonShatter(effect.config, in: &context, size: size)
        case .crimeTape: drawCrimeTape(effect.config, in: &context, size: size)
        case .cuteOutlineText: drawCuteOutlineText(effect.config, in: &context, size: size)
        case .dataMonitors: drawDataMonitors(effect.config, in: &context, size: size)
        case .desktopIcon: drawDesktopIcon(effect.config, in: &context, size: size)
        case .diagonalHatch: drawDiagonalHatch(effect.config, in: &context, size: size)
        case .diagonalSplit: drawDiagonalSplit(effect.config, in: &context, size: size)
        case .diagonalStructure: drawDiagonalStructure(effect.config, in: &context, size: size)
        case .dotScreen: drawDotScreen(effect.config, in: &context, size: size)
        case .edgeClouds: drawEdgeClouds(effect.config, in: &context, size: size)
        case .fallingText: drawFallingText(effect.config, in: &context, size: size)
        case .filmGrain: drawFilmGrain(effect.config, in: &context, size: size)
        case .flowingLines: drawFlowingLines(effect.config, in: &context, size: size)
        case .formulaText: drawFormulaText(effect.config, in: &context, size: size)
        case .glitchBars: drawGlitchBars(effect.config, in: &context, size: size)
        case .glowTextCards: drawGlowTextCards(effect.config, in: &context, size: size)
        case .gradientOverlay: drawGradientOverlay(effect.config, in: &context, size: size)
        case .halftoneBlocks: drawHalftoneBlocks(effect.config, in: &context, size: size)
        case .heroText: drawHeroText(effect.config, in: &context, size: size)
        case .hudCorners: drawHUDCorners(effect.config, in: &context, size: size)
        case .hudInfoPanel: drawHUDInfoPanel(effect.config, in: &context, size: size)
        case .hudStatusText: drawHUDStatusText(effect.config, in: &context, size: size)
        case .layeredText: drawLayeredText(effect.config, in: &context, size: size)
        case .lightSpot: drawLightSpot(effect.config, in: &context, size: size)
        case .motionBrackets: drawMotionBrackets(effect.config, in: &context, size: size)
        case .noiseText: drawNoiseText(effect.config, in: &context, size: size)
        case .perspectiveGrid: drawPerspectiveGrid(effect.config, in: &context, size: size)
        case .pinkGrid: drawPinkGrid(effect.config, in: &context, size: size)
        case .pinkStripes: drawPinkStripes(effect.config, in: &context, size: size)
        case .pixelTypewriter: drawPixelTypewriter(effect.config, in: &context, size: size)
        case .pixelWindow: drawPixelWindow(effect.config, in: &context, size: size)
        case .planet: drawPlanet(effect.config, in: &context, size: size)
        case .pulsingCircle: drawPulsingCircle(effect.config, in: &context, size: size)
        case .radialRectangles: drawRadialRectangles(effect.config, in: &context, size: size)
        case .scalloppedBorder: drawScalloppedBorder(effect.config, in: &context, size: size)
        case .scanlines: drawScanlines(effect.config, in: &context, size: size)
        case .scatteredShapes: drawScatteredShapes(effect.config, in: &context, size: size)
        case .scatteredText: drawScatteredText(effect.config, in: &context, size: size)
        case .screenBorder: drawScreenBorder(effect.config, in: &context, size: size)
        case .shadowShapes: drawShadowShapes(effect.config, in: &context, size: size)
        case .staggeredText: drawStaggeredText(effect.config, in: &context, size: size)
        case .textureBackground: drawTextureBackground(effect.config, in: &context, size: size)
        case .triangleGrid: drawTriangleGrid(effect.config, in: &context, size: size)
        case .verticalSubText: drawVerticalSubText(effect.config, in: &context, size: size)
        case .victimOutline: drawVictimOutline(effect.config, in: &context, size: size)
        case .vignette: drawVignette(effect.config, in: &context, size: size)
        case .waveText: drawWaveText(effect.config, in: &context, size: size)
        case .webLines: drawWebLines(effect.config, in: &context, size: size)
        }
    }
}
