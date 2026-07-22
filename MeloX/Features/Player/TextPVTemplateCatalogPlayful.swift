// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import Foundation

extension TextPVTemplateCatalog {
    static let girlyClouds = TextPVTemplate(
        style: .girlyClouds,
        palette: TextPVPalette(
            background: "#fef5f8",
            primary: "#fbbdbe",
            secondary: "#f8d7da",
            accent: "#ff9eb5",
            text: "#5a3a3f"
        ),
        effects: [
            TextPVEffect(.pinkStripes, layer: .background, [
                "pinkColor": "#fbbdbe", "stripeWidth": 150,
                "speed": 0.3, "angle": -45, "alpha": 1,
            ]),
            TextPVEffect(.edgeClouds, layer: .decoration, [
                "color": "#ffffff", "alpha": 1, "cloudCount": 5,
                "baseRadius": 100, "minCircles": 6, "maxCircles": 10,
                "shadowOffsetX": 4, "shadowOffsetY": 4,
                "shadowAlpha": 0.25, "shadowColor": "#fbbdbe",
            ]),
            TextPVEffect(.heroText, layer: .text, [
                "color": "#5a3a3f", "fontSize": 72,
                "fontFamily": "Noto Sans JP",
            ]),
        ],
        bpm: 120,
        animationSpeed: 1.5
    )

    static let sweetPink = TextPVTemplate(
        style: .sweetPink,
        palette: TextPVPalette(
            background: "#fef5f8",
            primary: "#fab2b5",
            secondary: "#f8c7ca",
            accent: "#ecbfc0",
            text: "#fab2b5"
        ),
        effects: [
            TextPVEffect(.pinkGrid, layer: .background, [
                "color": "#f8c7ca", "cellSize": 50,
                "lineColor": "#ffffff", "lineWidth": 2,
                "speed": 30, "alpha": 1,
            ]),
            TextPVEffect(.pulsingCircle, layer: .background, [
                "strokeColor": "#ffffff", "strokeAlpha": 0.8, "strokeWidth": 8,
                "outerStrokeColor": "#ecbfc0", "outerStrokeWidth": 3,
                "outerStrokeAlpha": 0.6, "radius": 250, "x": 0.5, "y": 0.5,
                "animSpeed": 0.2, "strokePulseAmount": 0.5,
                "radiusPulseAmount": 0.08, "enableBeatReact": false,
            ]),
            TextPVEffect(.scalloppedBorder, layer: .decoration, [
                "color": "#ffffff", "shadowColor": "#ecbfc0",
                "shadowAlpha": 0.6, "shadowOffsetX": 0, "shadowOffsetY": 8,
                "circleRadius": 80, "animSpeed": 0.2,
                "moveAmount": 15, "alpha": 1,
            ]),
            TextPVEffect(.cuteOutlineText, layer: .text, [
                "fillColor": "#fab2b5", "strokeColor": "#ffffff",
                "fontSize": 80, "strokeWidth": 8, "fontWeight": "900",
                "letterSpacing": 4, "x": 0.5, "y": 0.5,
            ]),
        ],
        bpm: 120,
        animationSpeed: 1
    )

    static let flyMeToTheMoon = TextPVTemplate(
        style: .flyMeToTheMoon,
        palette: TextPVPalette(
            background: "#1122ee",
            primary: "#c0c0d0",
            secondary: "#888899",
            accent: "#6a6a8a",
            text: "#e0e0e0"
        ),
        effects: [
            TextPVEffect(.textureBackground, layer: .background),
            TextPVEffect(.gradientOverlay, layer: .background, [
                "colorTop": "#0a0a18", "colorBottom": "#000008",
                "alpha": 0.55, "mode": "radial",
            ]),
            TextPVEffect(.scatteredShapes, layer: .decoration, ["color": "$primary"]),
            TextPVEffect(.planet, layer: .decoration, [
                "color": "#ffffff", "radius": 120, "coreRadius": 12,
            ]),
            TextPVEffect(.verticalSubText, layer: .text, [
                "color": "#ffffff", "fontSize": 13,
            ]),
            TextPVEffect(.vignette, layer: .overlay, [
                "color": "#000010", "alpha": 0.35, "radius": 0.7,
            ]),
            TextPVEffect(.dotScreen, layer: .overlay),
        ],
        animationSpeed: 3.7,
        postFX: TextPVPostFX(zoom: 0.65, tilt: -0.52, hueShift: -10)
    )

    static let kawaiPixel = TextPVTemplate(
        style: .kawaiPixel,
        palette: TextPVPalette(
            background: "#fef0f5",
            primary: "#ffb3d9",
            secondary: "#b3e5fc",
            accent: "#c8f7dc",
            text: "#5a3a5a"
        ),
        effects: [
            TextPVEffect(.dotScreen, layer: .background, [
                "color": "#ffb3d9", "dotSize": 4, "spacing": 12, "alpha": 0.15,
            ]),
            TextPVEffect(.checkerboard, layer: .background, [
                "color1": "#ffffff", "color2": "#fef5f8",
                "cellSize": 40, "alpha": 0.3,
            ]),
            TextPVEffect(.desktopIcon, layer: .decoration, [
                "x": 30, "y": 30, "size": 64, "iconType": "paint",
                "label": "Paint.exe", "labelColor": "#5a3a5a",
            ]),
            TextPVEffect(.desktopIcon, layer: .decoration, [
                "x": 30, "y": 120, "size": 64, "iconType": "notes",
                "label": "Notes", "labelColor": "#5a3a5a",
            ]),
            pixelWindow([
                "x": 0.22, "y": 0.18, "anchorX": 0.5, "anchorY": 0.5,
                "width": 320, "height": 260, "bgColor": "#ffffff",
                "borderColor": "#ffb3d9", "borderWidth": 4,
                "titleBgColor": "#ffb3d9", "titleColor": "#ffffff",
                "title": "Pixel Paint", "titleBarHeight": 28,
                "icon": "heart", "iconColor": "#ffb3d9", "iconSize": 70,
                "alpha": 0.95,
            ]),
            pixelWindow([
                "x": 0.75, "y": 0.15, "anchorX": 0.5, "anchorY": 0.5,
                "width": 280, "height": 180, "bgColor": "#f0f8ff",
                "borderColor": "#b3e5fc", "borderWidth": 4,
                "titleBgColor": "#b3e5fc", "titleColor": "#ffffff",
                "title": "Welcome!!", "titleBarHeight": 28,
                "icon": "paint", "iconColor": "#b3e5fc", "iconSize": 50,
                "alpha": 0.92,
            ]),
            pixelWindow([
                "x": 0.82, "y": 0.28, "anchorX": 0.5, "anchorY": 0.5,
                "width": 260, "height": 160, "bgColor": "#fff5f8",
                "borderColor": "#ffc0e0", "borderWidth": 4,
                "titleBgColor": "#ffc0e0", "titleColor": "#ffffff",
                "title": "Messages ♡", "titleBarHeight": 28,
                "content": "You have 3 new\nmessages! (◕‿◕)",
                "contentColor": "#5a3a5a", "alpha": 0.90,
            ]),
            pixelWindow([
                "x": 0.18, "y": 0.78, "anchorX": 0.5, "anchorY": 0.5,
                "width": 300, "height": 200, "bgColor": "#f5f0ff",
                "borderColor": "#c8b3ff", "borderWidth": 4,
                "titleBgColor": "#c8b3ff", "titleColor": "#ffffff",
                "title": "Music Player", "titleBarHeight": 28,
                "content": "♪ Now Playing...\n\n▶ Track 01\n━━━━━━━━━━ 2:34",
                "contentColor": "#5a3a5a", "alpha": 0.93,
            ]),
            pixelWindow([
                "x": 0.25, "y": 0.68, "anchorX": 0.5, "anchorY": 0.5,
                "width": 240, "height": 150, "bgColor": "#f0fff4",
                "borderColor": "#c8f7dc", "borderWidth": 4,
                "titleBgColor": "#c8f7dc", "titleColor": "#ffffff",
                "title": "Calendar", "titleBarHeight": 28,
                "content": "📅 Today:\nMarch 14, 2026\nSaturday ☆",
                "contentColor": "#5a3a5a", "alpha": 0.91,
            ]),
            pixelWindow([
                "x": 0.78, "y": 0.78, "anchorX": 0.5, "anchorY": 0.5,
                "width": 340, "height": 240, "bgColor": "#fffef0",
                "borderColor": "#ffb3d9", "borderWidth": 4,
                "titleBgColor": "#ffb3d9", "titleColor": "#ffffff",
                "title": "Note.txt", "titleBarHeight": 28,
                "content": "1. Buy milk\n2. Call mom\n3. Practice drawing\n4. Be cute!",
                "contentColor": "#5a3a5a", "alpha": 0.95,
            ]),
            TextPVEffect(.scatteredShapes, layer: .decoration, [
                "shape": "circle", "color": "#ffb3d9", "count": 6,
                "minSize": 12, "maxSize": 20, "alpha": 0.5, "speed": 0.2,
            ]),
            TextPVEffect(.scatteredShapes, layer: .decoration, [
                "shape": "circle", "color": "#fff9b3", "count": 8,
                "minSize": 8, "maxSize": 16, "alpha": 0.6, "speed": 0.15,
            ]),
            TextPVEffect(.pixelTypewriter, layer: .text, [
                "fillColor": "#5a3a5a", "strokeColor": "#ffffff",
                "fontSize": 44, "strokeWidth": 6, "fontWeight": "900",
                "fontFamily": "Courier New", "letterSpacing": 3,
                "leftX": 0.2, "rightX": 0.6, "y": 0.5,
                "maxCharsPerSide": 5, "shadowColor": "#ffb3d9",
                "shadowBlur": 0, "shadowOffsetX": 3, "shadowOffsetY": 3,
                "charDelay": 0.08, "cursorColor": "#ffb3d9",
                "cursorWidth": 4, "cursorBlinkSpeed": 0.5,
                "showCursorWhenDone": false, "pixelSize": 3,
            ]),
        ],
        bpm: 120,
        animationSpeed: 1,
        backgroundOpacity: 1
    )

    static let crimeScene = TextPVTemplate(
        style: .crimeScene,
        palette: TextPVPalette(
            background: "#0a0a0a",
            primary: "#cccccc",
            secondary: "#666666",
            accent: "#8b0000",
            text: "#ffffff"
        ),
        effects: [
            TextPVEffect(.victimOutline, layer: .background, [
                "color": "#ffffff", "alpha": 0.88, "scale": 1.5,
                "lineWidth": 5, "seed": 914,
            ]),
            TextPVEffect(.bloodSplatter, layer: .background, [
                "count": 5, "color": "#8b0000", "alpha": 0.85,
                "size": 1.1, "seed": 914,
            ]),
            TextPVEffect(.textureBackground, layer: .background, ["pattern": "dots"]),
            TextPVEffect(.staggeredText, layer: .text, [
                "color": "#ffffff", "fontSize": 64, "modeDuration": 3.5,
            ]),
            TextPVEffect(.crimeTape, layer: .decoration, [
                "count": 6, "tapeColor": "#f5c800", "textColor": "#000000",
                "tapeWidth": 52, "speed": 70,
                "text": "POLICE LINE DO NOT CROSS", "angleRange": 0.22,
            ]),
            TextPVEffect(.vignette, layer: .overlay, [
                "color": "#000000", "alpha": 0.72, "radius": 0.65,
            ]),
        ],
        animationSpeed: 2.5
    )

    static let haruhikage = TextPVTemplate(
        style: .haruhikage,
        palette: TextPVPalette(
            background: "#ABC5D2",
            primary: "#5a3a5a",
            secondary: "#7faecc",
            accent: "#d97a7a",
            text: "#5a3a5a"
        ),
        effects: [
            TextPVEffect(.backgroundBlocks, layer: .background, ["count": 7, "alpha": 0.35]),
            TextPVEffect(.halftoneBlocks, layer: .background, [
                "color": "$primary", "alpha": 0.12, "size": 3, "spacing": 6,
            ]),
            TextPVEffect(.scanlines, layer: .overlay, ["alpha": 0.08, "spacing": 3]),
            TextPVEffect(.crayonShatter, layer: .text, [
                "fontSize": 115, "fontFamily": "Yu Gothic", "fontWeight": "700",
                "charSpacingFrac": 1.05, "colSpacingFrac": 1.4,
                "colRowPhase": 0.45, "layoutJitter": 0.06,
                "baseColor": "#5a3a5a",
                "colors": ["#d97a7a", "#e0b96a", "#83b07c", "#7faecc", "#c89bba", "#d49d6f", "#9c89c4", "#7fb6c4"],
                "replaceProb": 0.55, "randomReplaceMaxSizeFrac": 0.50,
                "offsetProb": 0.55, "maxOffsetPx": 5,
                "rotateProb": 0.55, "maxRotateDeg": 14,
                "swingProb": 0.15, "outlineProb": 1,
                "outlineLineWidth": 1.5, "outlineJitter": 0.6,
                "outlineSimplify": 6, "outlineSmoothIters": 2,
                "frameHoldSec": 0.18, "frameCount": 4, "spinSpeedScale": 1,
            ]),
        ],
        bpm: 90,
        animationSpeed: 0.8
    )

    private static func pixelWindow(_ config: TextPVEffectConfig) -> TextPVEffect {
        TextPVEffect(.pixelWindow, layer: .decoration, config)
    }
}
