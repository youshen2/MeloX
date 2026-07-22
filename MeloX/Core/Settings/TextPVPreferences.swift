// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Template metadata ported under the PV Tool Non-Commercial License.

import Foundation
import Observation

// Template order and names mirror pv-tool/src/templates/index.ts.
enum TextPVStyle: String, CaseIterable, Identifiable {
    case blueBold
    case kineticSplit
    case bluePlane
    case cyberGrunge
    case geometric
    case rainCity
    case cyberpunkHUD
    case emotionCinema
    case hystericNight
    case spiderWeb
    case staggeredText
    case calmVillain
    case girlyClouds
    case sweetPink
    case flyMeToTheMoon
    case kawaiPixel
    case crimeScene
    case haruhikage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blueBold: "蓝色冲击"
        case .kineticSplit: "斩击"
        case .bluePlane: "蓝色构成(建议配合视频使用)"
        case .cyberGrunge: "赛博废墟"
        case .geometric: "几何"
        case .rainCity: "黑客帝国"
        case .cyberpunkHUD: "夜之城监控(建议配合视频使用)"
        case .emotionCinema: "情绪电影(建议配合视频使用)"
        case .hystericNight: "歇斯底里之夜(光敏慎点)"
        case .spiderWeb: "蛛网"
        case .staggeredText: "错落文字"
        case .calmVillain: "冷静的反派"
        case .girlyClouds: "少女云朵"
        case .sweetPink: "格子花边"
        case .flyMeToTheMoon: "Fly Me to the Moon"
        case .kawaiPixel: "Kawaii像素"
        case .crimeScene: "案发现场"
        case .haruhikage: "春日影"
        }
    }

    var description: String {
        switch self {
        case .blueBold: "蓝底、轮廓字与带阴影的几何文字块"
        case .kineticSplit: "米白底、酒红斩击结构与多层文字"
        case .bluePlane: "反相蓝色构成、物理公式与目标节点"
        case .cyberGrunge: "黑白网点、监视器、噪声与发光字卡"
        case .geometric: "明黄背景、同心方块与波浪文字"
        case .rainCity: "青绿色雨幕文字与色差暗角"
        case .cyberpunkHUD: "黄色监控网格、红色目标框与情报面板"
        case .emotionCinema: "冷色渐变、流动线条与克制的电影文字"
        case .hystericNight: "放射矩形与逐字发光卡片，包含强烈闪动"
        case .spiderWeb: "红色蛛网、扫描线与故障文字"
        case .staggeredText: "五种错落排版循环切换"
        case .calmVillain: "粉蓝精密构成、透视网格与冷光字卡"
        case .girlyClouds: "粉色斜纹、边缘云朵与中央标题"
        case .sweetPink: "移动粉格、脉冲圆与扇贝花边"
        case .flyMeToTheMoon: "深空纹理、行星与竖排小字"
        case .kawaiPixel: "复古桌面窗口、像素图标与打字机文字"
        case .crimeScene: "受害者轮廓、血迹与移动警戒线"
        case .haruhikage: "蓝灰半调背景与彩色蜡笔碎裂文字"
        }
    }

    var systemImage: String {
        switch self {
        case .blueBold: "bolt.fill"
        case .kineticSplit: "line.diagonal"
        case .bluePlane: "circle.grid.cross"
        case .cyberGrunge: "waveform.path.ecg"
        case .geometric: "square.on.square"
        case .rainCity: "text.line.first.and.arrowtriangle.forward"
        case .cyberpunkHUD: "viewfinder"
        case .emotionCinema: "film"
        case .hystericNight: "rays"
        case .spiderWeb: "point.3.filled.connected.trianglepath.dotted"
        case .staggeredText: "textformat.size.larger"
        case .calmVillain: "scope"
        case .girlyClouds: "cloud.fill"
        case .sweetPink: "circle.grid.2x2.fill"
        case .flyMeToTheMoon: "moon.stars.fill"
        case .kawaiPixel: "macwindow"
        case .crimeScene: "exclamationmark.triangle.fill"
        case .haruhikage: "scribble.variable"
        }
    }

    var referenceAnimationSpeed: Double {
        switch self {
        case .staggeredText: 3.4
        case .girlyClouds: 1.5
        case .sweetPink, .kawaiPixel: 1
        case .flyMeToTheMoon: 3.7
        case .crimeScene: 2.5
        case .haruhikage: 0.8
        default: 2
        }
    }

    var minimumRenderInterval: TimeInterval {
        switch self {
        case .rainCity, .hystericNight, .calmVillain, .crimeScene, .haruhikage:
            1.0 / 30.0
        default:
            1.0 / 60.0
        }
    }
}

@MainActor
@Observable
final class TextPVPreferences {
    static let defaultStyle = TextPVStyle.blueBold
    static let defaultMotionIntensity = 1.0
    static let motionIntensityRange = 0.0...2.0
    static let defaultAnimationSpeed = 2.0
    static let animationSpeedRange = 0.0...4.0

    private enum Key {
        static let style = "textPVStyle"
        static let motionIntensity = "textPVMotionIntensity"
        static let animationSpeed = "textPVAnimationSpeed"
    }

    var style: TextPVStyle {
        didSet {
            defaults.set(style.rawValue, forKey: Key.style)
            guard style != oldValue else { return }
            animationSpeed = style.referenceAnimationSpeed
        }
    }

    var motionIntensity: Double {
        didSet { defaults.set(motionIntensity, forKey: Key.motionIntensity) }
    }

    var animationSpeed: Double {
        didSet { defaults.set(animationSpeed, forKey: Key.animationSpeed) }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedStyle = TextPVStyle(
            rawValue: defaults.string(forKey: Key.style) ?? ""
        ) ?? Self.defaultStyle
        style = storedStyle
        motionIntensity = (defaults.object(forKey: Key.motionIntensity) as? Double
            ?? Self.defaultMotionIntensity)
            .clamped(to: Self.motionIntensityRange)
        animationSpeed = (defaults.object(forKey: Key.animationSpeed) as? Double
            ?? storedStyle.referenceAnimationSpeed)
            .clamped(to: Self.animationSpeedRange)
    }

    func reset() {
        style = Self.defaultStyle
        motionIntensity = Self.defaultMotionIntensity
        animationSpeed = Self.defaultAnimationSpeed
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
