import SwiftUI

enum DesktopAppleMusicBackdropShader {
    static func backdrop(
        artwork: Image,
        size: CGSize,
        time: TimeInterval,
        motionIntensity: Double,
        meshWarpTimeScale: Double,
        blackScrimAlpha: Double,
        usesDarkAppearance: Bool,
        warpField: DesktopAppleMusicWarpField
    ) -> Shader {
        return ShaderLibrary.desktopAppleMusicBackdrop(
            .float2(size),
            .image(artwork),
            .float(meshWeight(at: time, timeScale: meshWarpTimeScale)),
            .float(blackScrimAlpha),
            .float(usesDarkAppearance ? 1 : 0),
            .floatArray(rotations(at: time, motionIntensity: motionIntensity)),
            .float2(Float(warpField.dimension), Float(warpField.phaseCount)),
            .data(warpField.coordinates)
        )
    }

    nonisolated static func rotations(
        at time: TimeInterval,
        motionIntensity: Double
    ) -> [Float] {
        let speed = 0.5 / max(motionIntensity, 0.1)
        // Rotation is uniform across the frame, so evaluate trigonometry once.
        return [120.0, 90.0, 70.0].flatMap { period in
            let angle = time.truncatingRemainder(dividingBy: period * speed)
                * 2 * .pi / (period * speed)
            return [Float(cos(angle)), Float(sin(angle))]
        }
    }

    /// Uniform across the whole frame. Reduce the phase in Double before
    /// uploading it so long playback sessions retain smooth Float steps.
    nonisolated static func meshWeight(at time: TimeInterval, timeScale: Double) -> Double {
        let scale = max(timeScale, 0.1)
        let cycle = time.truncatingRemainder(dividingBy: 2 * scale) / scale
        let phase = cycle < 1 ? abs(cycle - 0.5) : 1 - abs(cycle - 1.5)
        return phase * phase * (3 - 2 * phase)
    }
}
