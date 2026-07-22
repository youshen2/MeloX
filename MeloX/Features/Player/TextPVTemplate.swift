// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

enum TextPVLayer: CaseIterable {
    case background
    case decoration
    case text
    case overlay
}

enum TextPVEffectKind: String {
    case backgroundBlocks
    case balancingCircles
    case bigOutlineText
    case bloodSplatter
    case burstLines
    case centeredSquares
    case checkerboard
    case chromaticAberration
    case colorMask
    case compositionGuides
    case concentricCircles
    case crayonShatter
    case crimeTape
    case cuteOutlineText
    case dataMonitors
    case desktopIcon
    case diagonalHatch
    case diagonalSplit
    case diagonalStructure
    case dotScreen
    case edgeClouds
    case fallingText
    case filmGrain
    case flowingLines
    case formulaText
    case glitchBars
    case glowTextCards
    case gradientOverlay
    case halftoneBlocks
    case heroText
    case hudCorners
    case hudInfoPanel
    case hudStatusText
    case layeredText
    case lightSpot
    case motionBrackets
    case noiseText
    case perspectiveGrid
    case pinkGrid
    case pinkStripes
    case pixelTypewriter
    case pixelWindow
    case planet
    case pulsingCircle
    case radialRectangles
    case scalloppedBorder
    case scanlines
    case scatteredShapes
    case scatteredText
    case screenBorder
    case shadowShapes
    case staggeredText
    case textureBackground
    case triangleGrid
    case verticalSubText
    case victimOutline
    case vignette
    case waveText
    case webLines
}

enum TextPVConfigValue:
    ExpressibleByArrayLiteral,
    ExpressibleByBooleanLiteral,
    ExpressibleByDictionaryLiteral,
    ExpressibleByFloatLiteral,
    ExpressibleByIntegerLiteral,
    ExpressibleByStringLiteral
{
    case array([TextPVConfigValue])
    case bool(Bool)
    case number(CGFloat)
    case object([String: TextPVConfigValue])
    case string(String)

    init(arrayLiteral elements: TextPVConfigValue...) {
        self = .array(elements)
    }

    init(booleanLiteral value: Bool) {
        self = .bool(value)
    }

    init(dictionaryLiteral elements: (String, TextPVConfigValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }

    init(floatLiteral value: Double) {
        self = .number(CGFloat(value))
    }

    init(integerLiteral value: Int) {
        self = .number(CGFloat(value))
    }

    init(stringLiteral value: String) {
        self = .string(value)
    }

    var arrayValue: [TextPVConfigValue]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    var boolValue: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }

    var numberValue: CGFloat? {
        guard case let .number(value) = self else { return nil }
        return value
    }

    var objectValue: [String: TextPVConfigValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
}

typealias TextPVEffectConfig = [String: TextPVConfigValue]

struct TextPVEffect {
    let kind: TextPVEffectKind
    let layer: TextPVLayer
    let config: TextPVEffectConfig

    init(
        _ kind: TextPVEffectKind,
        layer: TextPVLayer,
        _ config: TextPVEffectConfig = [:]
    ) {
        self.kind = kind
        self.layer = layer
        self.config = config
    }
}

struct TextPVPalette {
    let background: String
    let primary: String
    let secondary: String
    let accent: String
    let text: String
    let backgroundColor: Color

    private let primaryColor: Color
    private let secondaryColor: Color
    private let accentColor: Color
    private let textColor: Color
    private let lineColor: Color

    init(
        background: String,
        primary: String,
        secondary: String,
        accent: String,
        text: String
    ) {
        self.background = background
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.text = text
        backgroundColor = Color(textPVHex: background)
        primaryColor = Color(textPVHex: primary)
        secondaryColor = Color(textPVHex: secondary)
        accentColor = Color(textPVHex: accent)
        textColor = Color(textPVHex: text)

        let components = Color.textPVComponents(from: background)
        let luminance = components.red * 0.299
            + components.green * 0.587
            + components.blue * 0.114
        lineColor = Color(textPVHex: luminance > 0.55 ? "#999999" : "#ffffff")
    }

    func resolve(_ token: String, fallback: String = "#000000") -> Color {
        switch token {
        case "$background": return backgroundColor
        case "$primary": return primaryColor
        case "$secondary": return secondaryColor
        case "$accent": return accentColor
        case "$text": return textColor
        case "$line": return lineColor
        default: return Color(textPVHex: token.hasPrefix("#") ? token : fallback)
        }
    }
}

struct TextPVFeatures {
    var motionDetection = false
    var invertMedia = false
    var thresholdMedia = false
}

struct TextPVPostFX {
    var shake: CGFloat = 0
    var zoom: CGFloat = 0
    var tilt: CGFloat = 0
    var glitch: CGFloat = 0
    var hueShift: CGFloat = 0
}

struct TextPVTemplate {
    let style: TextPVStyle
    let palette: TextPVPalette
    let effects: [TextPVEffect]
    var bpm: CGFloat = 120
    var animationSpeed: CGFloat?
    var backgroundOpacity: CGFloat = 1
    var features = TextPVFeatures()
    var postFX = TextPVPostFX()

    static func resolve(style: TextPVStyle) -> Self {
        TextPVTemplateCatalog.template(for: style)
    }
}

enum TextPVTemplateCatalog {
    static func template(for style: TextPVStyle) -> TextPVTemplate {
        switch style {
        case .blueBold: blueBold
        case .kineticSplit: kineticSplit
        case .bluePlane: bluePlane
        case .cyberGrunge: cyberGrunge
        case .geometric: geometric
        case .rainCity: rainCity
        case .cyberpunkHUD: cyberpunkHUD
        case .emotionCinema: emotionCinema
        case .hystericNight: hystericNight
        case .spiderWeb: spiderWeb
        case .staggeredText: staggeredText
        case .calmVillain: calmVillain
        case .girlyClouds: girlyClouds
        case .sweetPink: sweetPink
        case .flyMeToTheMoon: flyMeToTheMoon
        case .kawaiPixel: kawaiPixel
        case .crimeScene: crimeScene
        case .haruhikage: haruhikage
        }
    }
}

extension TextPVEffectConfig {
    func number(_ key: String, default fallback: CGFloat) -> CGFloat {
        self[key]?.numberValue ?? fallback
    }

    func integer(_ key: String, default fallback: Int) -> Int {
        Int(self[key]?.numberValue ?? CGFloat(fallback))
    }

    func string(_ key: String, default fallback: String) -> String {
        self[key]?.stringValue ?? fallback
    }

    func bool(_ key: String, default fallback: Bool) -> Bool {
        self[key]?.boolValue ?? fallback
    }

    func array(_ key: String) -> [TextPVConfigValue] {
        self[key]?.arrayValue ?? []
    }
}

extension Color {
    fileprivate init(textPVHex hex: String) {
        let components = Self.textPVComponents(from: hex)
        self.init(
            red: Double(components.red),
            green: Double(components.green),
            blue: Double(components.blue)
        )
    }

    fileprivate static func textPVComponents(
        from hex: String
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let integer = UInt64(value, radix: 16) else {
            return (0, 0, 0)
        }
        return (
            CGFloat((integer >> 16) & 0xFF) / 255,
            CGFloat((integer >> 8) & 0xFF) / 255,
            CGFloat(integer & 0xFF) / 255
        )
    }
}
