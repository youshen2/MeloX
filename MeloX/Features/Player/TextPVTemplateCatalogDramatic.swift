// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import Foundation

extension TextPVTemplateCatalog {
    static let cyberpunkHUD = TextPVTemplate(
        style: .cyberpunkHUD,
        palette: TextPVPalette(
            background: "#0a0a0a",
            primary: "#FFFF00",
            secondary: "#323200",
            accent: "#FF0000",
            text: "#FFFFFF"
        ),
        effects: [
            TextPVEffect(.triangleGrid, layer: .background, [
                "color": "$secondary", "alpha": 0.3, "cols": 9,
            ]),
            TextPVEffect(.scanlines, layer: .overlay, [
                "color": "#001414", "alpha": 0.15, "spacing": 4,
            ]),
            TextPVEffect(.hudCorners, layer: .decoration, [
                "color": "$primary", "alpha": 0.9,
                "margin": 20, "armLength": 40, "lineWidth": 2,
            ]),
            TextPVEffect(.hudStatusText, layer: .text, [
                "textColor": "$text", "alertColor": "$accent",
                "centerText": "SYS.MONITOR // ONLINE",
                "rightText": "NETWATCH // PROTOCOL V.2.0.77",
                "fontSize": 13,
            ]),
            TextPVEffect(.motionBrackets, layer: .overlay, [
                "color": "$accent", "alpha": 0.85, "lineWidth": 2, "style": "high",
            ]),
            TextPVEffect(.hudInfoPanel, layer: .overlay, [
                "primaryColor": "$primary", "alertColor": "$accent",
                "textColor": "$text", "gridColor": "#323200",
                "panelWidth": 240, "panelHeight": 420,
            ]),
            TextPVEffect(.heroText, layer: .text, [
                "fontSize": 36, "x": 0.5, "y": 0.92,
                "color": "$primary", "fontWeight": "bold",
                "fontFamily": "Courier New", "animation": "breathe",
                "animationSpeed": 0.5, "animationAmount": 0.03,
            ]),
        ],
        bpm: 140,
        features: TextPVFeatures(motionDetection: true)
    )

    static let emotionCinema = TextPVTemplate(
        style: .emotionCinema,
        palette: TextPVPalette(
            background: "#0d1018",
            primary: "#c8c8d0",
            secondary: "#4455aa",
            accent: "#7788cc",
            text: "#e0e0e8"
        ),
        effects: [
            TextPVEffect(.gradientOverlay, layer: .background, [
                "colorTop": "#141828", "colorBottom": "#080c14", "alpha": 0.7,
            ]),
            TextPVEffect(.flowingLines, layer: .decoration, [
                "count": 4, "color": "$secondary", "alpha": 0.15,
                "strokeWidth": 0.5, "amplitude": 80, "speed": 0.08,
            ]),
            TextPVEffect(.scatteredText, layer: .text, [
                "count": 6, "color": "$secondary", "minSize": 12, "maxSize": 20,
                "chars": "MELANCHOLY SOLITUDE VOID FADING ECHO 虚無 薄れゆく 永劫回帰",
            ]),
            TextPVEffect(.motionBrackets, layer: .overlay, [
                "color": "$primary", "alpha": 0.5, "lineWidth": 1, "style": "medium",
            ]),
            TextPVEffect(.heroText, layer: .text, [
                "fontSize": 60, "x": 0.5, "y": 0.5, "color": "$text",
                "animation": "breathe", "animationSpeed": 0.15,
                "animationAmount": 0.02, "fontFamily": "Noto Serif JP",
            ]),
            TextPVEffect(.vignette, layer: .overlay, [
                "color": "#000000", "alpha": 0.8,
            ]),
            TextPVEffect(.colorMask, layer: .overlay, [
                "color": "#1a2040", "alpha": 0.15,
            ]),
        ],
        features: TextPVFeatures(motionDetection: true)
    )

    static let hystericNight = TextPVTemplate(
        style: .hystericNight,
        palette: TextPVPalette(
            background: "#ffffff",
            primary: "#1133aa",
            secondary: "#2244cc",
            accent: "#cccc00",
            text: "#1a1a1a"
        ),
        effects: [
            TextPVEffect(.radialRectangles, layer: .decoration, [
                "count": 14, "baseColor": "#1133aa", "edgeColor": "#cccc00",
                "edgeBlur": 8, "x": 0.47, "y": 0.48,
                "rotSpeed": 0.08, "growSpeed": 0.03,
            ]),
            TextPVEffect(.gradientOverlay, layer: .overlay, [
                "mode": "radial", "colorTop": "#0a1535",
                "colorBottom": "#000000", "alpha": 0.55,
            ]),
            TextPVEffect(.glowTextCards, layer: .text, [
                "cardColor": "#ffffff", "textColor": "#1a1a1a",
                "glowColor": "#ffffff", "glowAlpha": 0.6,
                "fontSize": 68, "charsPerRow": 5, "sizeVariance": 0.25,
                "staggerX": 10, "staggerY": 6, "cardPadding": 16,
                "staggerDelay": 0.07, "x": 0.47, "y": 0.48,
                "fontFamily": "Noto Serif JP",
            ]),
            TextPVEffect(.verticalSubText, layer: .text, [
                "color": "#ffffff", "fontSize": 13, "x": 0.65, "y": 0.33,
                "charsPerCol": 5, "fontFamily": "Noto Serif JP",
            ]),
            TextPVEffect(.vignette, layer: .overlay, [
                "color": "#000000", "alpha": 0.45,
            ]),
            TextPVEffect(.scatteredShapes, layer: .decoration, [
                "count": 30, "color": "#4466cc", "shapes": ["circle"],
                "minSize": 1, "maxSize": 3, "alpha": 0.3,
            ]),
        ],
        bpm: 130
    )

    static let spiderWeb = TextPVTemplate(
        style: .spiderWeb,
        palette: TextPVPalette(
            background: "#000000",
            primary: "#ff2222",
            secondary: "#cc0000",
            accent: "#ff4444",
            text: "#ffffff"
        ),
        effects: [
            TextPVEffect(.scanlines, layer: .overlay, [
                "color": "#cc0000", "alpha": 0.18, "spacing": 3,
            ]),
            TextPVEffect(.dotScreen, layer: .overlay, [
                "spacing": 7, "dotRadius": 1.8, "color": "#ff2222",
                "alpha": 0.1, "angle": 30,
            ]),
            TextPVEffect(.webLines, layer: .decoration, [
                "count": 24, "color": "#ff2222", "glowColor": "#ff4444",
                "focalX": 0.5, "focalY": 0.45, "spread": 0.2,
                "rebuildChance": 0.01,
            ]),
            TextPVEffect(.webLines, layer: .decoration, [
                "count": 8, "color": "#cc0000", "glowColor": "#ff2222",
                "focalX": 0.5, "focalY": 0.5, "spread": 0.6,
                "rebuildChance": 0.005,
            ]),
            TextPVEffect(.chromaticAberration, layer: .overlay, [
                "amount": 4, "angle": 0.2,
            ]),
            TextPVEffect(.glitchBars, layer: .overlay, [
                "color": "#ff1111", "alpha": 0.35,
            ]),
            TextPVEffect(.heroText, layer: .text, [
                "color": "#ffffff", "fontSize": 52,
                "strokeColor": "#000000", "strokeWidth": 2,
                "letterSpacing": 8,
            ]),
            TextPVEffect(.vignette, layer: .overlay, [
                "color": "#000000", "alpha": 0.5,
            ]),
        ]
    )

    static let staggeredText = TextPVTemplate(
        style: .staggeredText,
        palette: TextPVPalette(
            background: "#1a2a6c",
            primary: "#ffffff",
            secondary: "#8899cc",
            accent: "#4466dd",
            text: "#ffffff"
        ),
        effects: [
            TextPVEffect(.staggeredText, layer: .text, [
                "color": "#ffffff", "fontSize": 68, "modeDuration": 3.5,
                "transition": 0.5, "colChars": 5,
                "fontFamily": "Noto Serif JP", "frameColor": "#ffffff",
                "frameAlpha": 0.5, "framePadding": 35,
            ]),
            TextPVEffect(.chromaticAberration, layer: .overlay, [
                "amount": 3, "angle": 0.1,
            ]),
            TextPVEffect(.vignette, layer: .overlay, [
                "color": "#0a1440", "alpha": 0.4,
            ]),
        ],
        animationSpeed: 3.4
    )

    static let calmVillain = TextPVTemplate(
        style: .calmVillain,
        palette: TextPVPalette(
            background: "#f5c6d0",
            primary: "#2255cc",
            secondary: "#1a3388",
            accent: "#3377ff",
            text: "#1a2266"
        ),
        effects: [
            TextPVEffect(.textureBackground, layer: .background, [
                "pattern": "dots", "color": "$secondary", "alpha": 0.6,
            ]),
            TextPVEffect(.checkerboard, layer: .background, [
                "cellSize": 64, "color1": "#f0b8c4", "color2": "#e8a0b0", "alpha": 0.08,
            ]),
            TextPVEffect(.perspectiveGrid, layer: .decoration, [
                "color": "$line", "alpha": 0.5, "lineWidth": 1.5,
                "mode": "floor", "scrollSpeed": 0.25,
            ]),
            TextPVEffect(.burstLines, layer: .decoration, [
                "color": "$line", "alpha": 0.35, "rayCount": 20,
                "lineWidth": 2.5, "rotSpeed": 0.03,
            ]),
            TextPVEffect(.diagonalHatch, layer: .decoration, [
                "color": "$line", "alpha": 0.28, "spacing": 18, "lineWidth": 1.2,
            ]),
            TextPVEffect(.compositionGuides, layer: .decoration, [
                "color": "$line", "alpha": 0.35, "lineWidth": 1.5,
                "guides": ["thirds"],
            ]),
            TextPVEffect(.compositionGuides, layer: .decoration, [
                "color": "$line", "alpha": 0.4, "lineWidth": 1.8,
                "guides": ["goldenSpiral"], "rotSpeed": 0.06,
            ]),
            TextPVEffect(.screenBorder, layer: .decoration, [
                "color": "$line", "lineWidth": 2, "alpha": 0.75,
                "margin": 20, "gap": 6, "starSize": 4,
                "edgeStarCount": 4, "edgeStarCountV": 2,
            ]),
            TextPVEffect(.formulaText, layer: .text, [
                "color": "$line", "count": 14, "alpha": 0.4,
            ]),
            TextPVEffect(.glowTextCards, layer: .text, [
                "cardColor": "#ffffff", "textColor": "$text",
                "glowColor": "$accent", "glowAlpha": 0.6,
                "fontSize": 68, "charsPerRow": 5, "sizeVariance": 0.18,
                "staggerX": 8, "staggerY": 5, "cardPadding": 16,
                "staggerDelay": 0.06, "x": 0.47, "y": 0.48,
                "fontFamily": "Noto Serif JP",
            ]),
            TextPVEffect(.verticalSubText, layer: .text, [
                "color": "$line", "fontSize": 12, "x": 0.7, "y": 0.3,
                "fontFamily": "Noto Serif JP",
            ]),
            TextPVEffect(.lightSpot, layer: .overlay, [
                "color": "#ffffff", "x": 0.5, "y": 0.08,
                "alpha": 0.5, "radius": 0.4,
            ]),
            TextPVEffect(.dotScreen, layer: .overlay, [
                "spacing": 10, "dotRadius": 1, "color": "$line", "alpha": 0.07, "angle": 20,
            ]),
            TextPVEffect(.scanlines, layer: .overlay, [
                "color": "#002244", "alpha": 0.18, "spacing": 4,
            ]),
            TextPVEffect(.glitchBars, layer: .overlay, [
                "color": "$accent", "alpha": 0.28,
            ]),
            TextPVEffect(.vignette, layer: .overlay, [
                "color": "#d898a8", "alpha": 0.5,
            ]),
        ]
    )
}
