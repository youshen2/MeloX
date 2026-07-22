// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import Foundation

extension TextPVTemplateCatalog {
    static let blueBold = TextPVTemplate(
        style: .blueBold,
        palette: TextPVPalette(
            background: "#1122ee",
            primary: "#ffffff",
            secondary: "#e0e0e0",
            accent: "#0022aa",
            text: "#e0e0e0"
        ),
        effects: [
            TextPVEffect(.bigOutlineText, layer: .decoration, [
                "color": "#d8d8e0",
                "strokeColor": "#ffffff",
                "fontFamily": "Noto Sans JP",
                "staggerDelay": 0.18,
            ]),
            TextPVEffect(.shadowShapes, layer: .text, [
                "color": "#ffffff",
                "shadowColor": "#000055",
                "shadowAlpha": 0.45,
                "shadowOffX": 14,
                "shadowOffY": 16,
                "shapes": [
                    ["type": "square", "x": 0.38, "y": 0.32, "size": 0.16, "rotation": -0.08],
                    ["type": "diamond", "x": 0.55, "y": 0.58, "size": 0.15, "rotation": 0.785],
                    ["type": "rect", "x": 0.68, "y": 0.40, "size": 0.12, "rotation": 0.02],
                    ["type": "square", "x": 0.25, "y": 0.62, "size": 0.09, "rotation": 0.1],
                ],
            ]),
            TextPVEffect(.vignette, layer: .overlay, [
                "color": "#000022", "alpha": 0.35, "radius": 0.7,
            ]),
        ]
    )

    static let kineticSplit = TextPVTemplate(
        style: .kineticSplit,
        palette: TextPVPalette(
            background: "#f0ece8",
            primary: "#1a1a1a",
            secondary: "#ffffff",
            accent: "#8b1a1a",
            text: "#1a1a1a"
        ),
        effects: [
            TextPVEffect(.diagonalHatch, layer: .background, [
                "spacing": 7, "lineWidth": 0.6, "color": "$accent", "alpha": 0.1,
            ]),
            TextPVEffect(.diagonalSplit, layer: .decoration, [
                "color": "$accent",
                "alpha": 1,
                "rotSpeed": 0.25,
                "baseHalfAngle": 0.6,
                "angleVariation": 0.3,
                "initRotation": -1.5708,
                "hatchSpacing": 6,
                "centerSize": 12,
                "centerColor": "$primary",
            ]),
            TextPVEffect(.screenBorder, layer: .decoration, [
                "color": "$primary", "lineWidth": 1.5, "alpha": 0.5,
                "margin": 18, "gap": 5, "starSize": 4,
                "edgeStarCount": 4, "edgeStarCountV": 2,
            ]),
            TextPVEffect(.layeredText, layer: .text, [
                "color": "$primary", "fontSize": 90, "maxLayers": 4,
            ]),
            TextPVEffect(.vignette, layer: .overlay, ["intensity": 0.3]),
        ]
    )

    static let bluePlane = TextPVTemplate(
        style: .bluePlane,
        palette: TextPVPalette(
            background: "#f0ece6",
            primary: "#0028B4",
            secondary: "#c8c8c8",
            accent: "#3264E6",
            text: "#141414"
        ),
        effects: [
            TextPVEffect(.backgroundBlocks, layer: .background, ["count": 7, "alpha": 0.5]),
            TextPVEffect(.concentricCircles, layer: .decoration, [
                "count": 5, "maxRadius": 500, "x": 0.5, "y": 0.5,
                "color": "$secondary", "strokeWidth": 1, "alpha": 0.4,
                "animation": "none",
            ]),
            TextPVEffect(.diagonalStructure, layer: .decoration, [
                "color": "#f0f0f0", "alpha": 0.3, "step": 100,
            ]),
            TextPVEffect(.burstLines, layer: .decoration, [
                "color": "#b4b4b4", "alpha": 0.25,
                "rayCount": 8, "innerRadius": 0.08, "outerRadius": 0.65,
                "rotSpeed": 0, "x": 0.5, "y": 0.5,
            ]),
            TextPVEffect(.motionBrackets, layer: .overlay, [
                "color": "$text", "alpha": 0.7, "lineWidth": 1, "style": "medium",
                "showNodes": true, "showConnections": true, "showTrails": true,
                "nodeColor": "#3264E6", "connColor": "#888888",
                "trailColor": "#3264E6", "connMaxDist": 350,
            ]),
            TextPVEffect(.balancingCircles, layer: .decoration, [
                "count": 5, "blueColor": "#0028B4", "whiteColor": "#ffffff",
                "glowAlpha": 0.4,
            ]),
            TextPVEffect(.formulaText, layer: .text, [
                "color": "$text", "count": 18, "formulaRatio": 0.65,
                "fontFamily": "SF Mono",
            ]),
            TextPVEffect(.glowTextCards, layer: .text, [
                "cardColor": "#ffffff", "textColor": "$text",
                "fontSize": 72, "glowAlpha": 0.5, "charsPerRow": 5,
                "x": 0.5, "y": 0.45,
            ]),
        ],
        features: TextPVFeatures(motionDetection: true, invertMedia: true)
    )

    static let cyberGrunge = TextPVTemplate(
        style: .cyberGrunge,
        palette: TextPVPalette(
            background: "#000000",
            primary: "#ffffff",
            secondary: "#888888",
            accent: "#cccccc",
            text: "#ffffff"
        ),
        effects: [
            TextPVEffect(.dotScreen, layer: .overlay, [
                "spacing": 6, "dotRadius": 2, "color": "#ffffff", "alpha": 0.18, "angle": 22,
            ]),
            TextPVEffect(.scanlines, layer: .overlay, [
                "color": "#000000", "alpha": 0.2, "spacing": 3,
            ]),
            TextPVEffect(.filmGrain, layer: .overlay, [
                "alpha": 0.14, "mono": true, "frameVariants": 1,
            ]),
            TextPVEffect(.dataMonitors, layer: .decoration, [
                "count": 4, "borderColor": "#ffffff", "fillColor": "#000000",
                "dataColor": "#ffffff", "alpha": 0.65,
            ]),
            TextPVEffect(.noiseText, layer: .decoration, [
                "count": 10, "color": "#ffffff", "bgColor": "#000000",
            ]),
            TextPVEffect(.diagonalHatch, layer: .decoration, [
                "color": "#ffffff", "alpha": 0.06, "spacing": 12,
            ]),
            TextPVEffect(.scatteredShapes, layer: .decoration, [
                "color": "#ffffff", "alpha": 0.08,
            ]),
            TextPVEffect(.glitchBars, layer: .overlay, [
                "color": "#ffffff", "alpha": 0.4,
            ]),
            TextPVEffect(.glowTextCards, layer: .text, [
                "cardColor": "#ffffff", "textColor": "#000000",
                "fontSize": 64, "glowAlpha": 0.5, "charsPerRow": 5,
            ]),
            TextPVEffect(.vignette, layer: .overlay, [
                "color": "#000000", "alpha": 0.7,
            ]),
        ],
        features: TextPVFeatures(thresholdMedia: true)
    )

    static let geometric = TextPVTemplate(
        style: .geometric,
        palette: TextPVPalette(
            background: "#ffee00",
            primary: "#1a1a1a",
            secondary: "#ffffff",
            accent: "#888888",
            text: "#ffffff"
        ),
        effects: [
            TextPVEffect(.diagonalHatch, layer: .background, [
                "spacing": 8, "lineWidth": 0.7, "color": "$accent", "alpha": 0.14,
            ]),
            TextPVEffect(.screenBorder, layer: .decoration, [
                "color": "$primary", "lineWidth": 1.5, "alpha": 0.6,
                "margin": 22, "gap": 6, "starSize": 5,
                "edgeStarCount": 5, "edgeStarCountV": 3,
            ]),
            TextPVEffect(.centeredSquares, layer: .decoration, [
                "outerSize": 320, "midSize": 240, "innerSize": 170,
                "borderColor": "$primary", "midColor": "$primary",
                "innerColor": "$secondary",
            ]),
            TextPVEffect(.waveText, layer: .text, [
                "color": "#ffffff", "fontSize": 52,
                "charSpreadFrac": 0.5, "staggerY": 18,
            ]),
            TextPVEffect(.vignette, layer: .overlay, ["intensity": 0.35]),
        ]
    )

    static let rainCity = TextPVTemplate(
        style: .rainCity,
        palette: TextPVPalette(
            background: "#000000",
            primary: "#003b00",
            secondary: "#005500",
            accent: "#00ff41",
            text: "#00ff41"
        ),
        effects: [
            TextPVEffect(.gradientOverlay, layer: .background, [
                "colorTop": "#003838", "colorMid": "#004848",
                "colorBottom": "#001020", "alpha": 0.5, "mode": "linear",
            ]),
            TextPVEffect(.fallingText, layer: .decoration, [
                "color": "$accent", "count": 24, "minSize": 24, "maxSize": 62,
                "fontFamily": "Noto Serif JP",
            ]),
            TextPVEffect(.chromaticAberration, layer: .overlay, [
                "offset": 4, "flickerSpeed": 1.5,
            ]),
            TextPVEffect(.vignette, layer: .overlay, [
                "color": "#000000", "alpha": 0.7, "radius": 0.6,
            ]),
        ]
    )
}
