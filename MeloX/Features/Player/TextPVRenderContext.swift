// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

struct TextPVRenderContext {
    let template: TextPVTemplate
    let currentText: String
    let previousText: String
    let normalizedText: String
    let normalizedCharacters: [Character]
    let visibleCharacters: [Character]
    let previousCharacters: [Character]
    let time: CGFloat
    let segmentTime: CGFloat
    let animationSpeed: CGFloat
    let motionIntensity: CGFloat
    let fontScale: CGFloat
    let seed: UInt64
    let canvasSymbols: [TextPVCanvasTextSymbol]
    var motionTargets: [CGRect] = []

    var animatedTime: CGFloat { time * animationSpeed }

    var beatIntensity: CGFloat {
        let interval = 60 / max(template.bpm, 30)
        let phase = time.truncatingRemainder(dividingBy: interval) / interval
        return exp(-phase * 6) * 0.5
    }

}

enum TextPVSeed {
    static func value(_ components: String...) -> UInt64 {
        components.reduce(0xcbf29ce484222325) { hash, component in
            component.utf8.reduce(hash) { partial, byte in
                (partial ^ UInt64(byte)) &* 0x100000001b3
            }
        }
    }

    static func unit(_ seed: UInt64, _ index: Int, salt: UInt64 = 0) -> CGFloat {
        DeterministicRandom.closedUnit(
            seed
                &+ UInt64(truncatingIfNeeded: index) &* 0x9E3779B97F4A7C15
                &+ salt
        )
    }

    static func signed(_ seed: UInt64, _ index: Int, salt: UInt64 = 0) -> CGFloat {
        unit(seed, index, salt: salt) * 2 - 1
    }
}

extension CGFloat {
    func textPVClamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
