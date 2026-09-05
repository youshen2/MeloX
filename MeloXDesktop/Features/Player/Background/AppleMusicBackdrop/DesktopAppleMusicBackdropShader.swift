import SwiftUI

enum DesktopAppleMusicBackdropShader {
    static func pinch(
        size: CGSize,
        time: TimeInterval,
        meshWarpTimeScale: Double,
        blackScrimAlpha: Double,
        usesDarkAppearance: Bool,
        averageLuminosity: Double,
        meshPositions: Data,
        lookupOffsets: Data,
        lookupTriangles: Data
    ) -> Shader {
        ShaderLibrary.desktopAppleMusicBackdropPinch(
            .float2(size),
            .float(meshWeight(at: time, timeScale: meshWarpTimeScale)),
            .float(blackScrimAlpha),
            .float(usesDarkAppearance ? 1 : 0),
            .float(averageLuminosity),
            .data(meshPositions),
            .data(lookupOffsets),
            .data(lookupTriangles)
        )
    }

    /// Uniform across the whole frame. Reduce the phase in Double before
    /// uploading it so long playback sessions retain smooth Float steps.
    static func meshWeight(at time: TimeInterval, timeScale: Double) -> Double {
        let scale = max(timeScale, 0.1)
        let cycle = time.truncatingRemainder(dividingBy: 2 * scale) / scale
        let phase = cycle < 1 ? abs(cycle - 0.5) : 1 - abs(cycle - 1.5)
        return phase * phase * (3 - 2 * phase)
    }
}
