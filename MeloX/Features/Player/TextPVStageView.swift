// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

struct TextPVStageView: View {
    let frame: TextPVRenderContext

    var body: some View {
        stageCanvas
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    @ViewBuilder
    private var stageCanvas: some View {
        if usesPostProcessing {
            TextPVEffectCanvas(frame: frame)
                .scaleEffect(1 + frame.template.postFX.zoom * 0.5)
                .rotationEffect(
                    .radians(Double(frame.template.postFX.tilt * 0.3))
                )
                .offset(cameraOffset)
                .hueRotation(
                    .degrees(Double(frame.template.postFX.hueShift))
                )
        } else {
            TextPVEffectCanvas(frame: frame)
        }
    }

    private var usesPostProcessing: Bool {
        let postFX = frame.template.postFX
        return postFX.shake != 0
            || postFX.zoom != 0
            || postFX.tilt != 0
            || postFX.hueShift != 0
    }

    private var cameraOffset: CGSize {
        let shake = frame.template.postFX.shake
        guard shake > 0 else { return .zero }
        let totalShake = shake * (1 + frame.beatIntensity * 0.15)
        let tick = Int(frame.time * 60)
        return CGSize(
            width: TextPVSeed.signed(frame.seed, tick) * totalShake * 15,
            height: TextPVSeed.signed(frame.seed, tick + 1) * totalShake * 10
        )
    }
}
