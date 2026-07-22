// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

struct TextPVStageView: View {
    let frame: TextPVRenderContext

    var body: some View {
        ZStack {
            frame.template.palette.backgroundColor
            TextPVEffectCanvas(frame: frame)
        }
        .scaleEffect(1 + frame.template.postFX.zoom * 0.5)
        .rotationEffect(.radians(Double(frame.template.postFX.tilt * 0.3)))
        .offset(cameraOffset)
        .hueRotation(.degrees(Double(frame.template.postFX.hueShift)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var cameraOffset: CGSize {
        let totalShake = frame.template.postFX.shake
            + frame.beatIntensity * 0.15
        guard totalShake > 0 else { return .zero }
        let tick = Int(frame.time * 60)
        return CGSize(
            width: TextPVSeed.signed(frame.seed, tick) * totalShake * 15,
            height: TextPVSeed.signed(frame.seed, tick + 1) * totalShake * 10
        )
    }
}
