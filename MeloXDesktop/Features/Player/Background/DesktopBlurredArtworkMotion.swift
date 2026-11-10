import Foundation

// Ported from lladlam/MeloX-Android, commit 9f496319 (GPL-3.0),
// MeloXFlowingLightBackdrop.kt: constant-flow trajectories and phase rate.
nonisolated struct DesktopBlurredArtworkMotion {
    func centers(at phase: Double) -> [Float] {
        let x = [0.50, 0.25, 0.75, 0.50, 0.25, 0.75, 0.50, 0.25, 0.75]
        let y = [0.25, 0.75, 0.50, 0.75, 0.50, 0.25, 0.50, 0.25, 0.75]
        var result: [Float] = []
        for i in 0..<9 {
            let px: Double = phase * x[i] + Double(i) * 1.7
            let py: Double = phase * y[i] + Double(i) * 0.9
            result.append(Float(0.5 + 0.3 * sin(px)))
            result.append(Float(0.5 + 0.3 * cos(py)))
        }
        return result
    }

    func speed(for intensity: Double) -> Double {
        let value = min(max(intensity, 0), 1.4)
        guard value > 0 else { return 0 }
        let multiplier = value <= 1 ? max(0.25, value) : 1 + (value - 1) * 2.5
        return 1.92 * multiplier
    }
}

/// Integrates speed changes rather than multiplying the whole elapsed time,
/// so adjusting the slider changes velocity without jumping to another phase.
nonisolated struct DesktopBlurredArtworkClock {
    private var accumulated: TimeInterval = 0
    private var anchor: Date?
    private var rate: Double = 0

    func elapsed(at date: Date) -> TimeInterval {
        accumulated + max(date.timeIntervalSince(anchor ?? date), 0) * rate
    }

    mutating func setRate(_ newRate: Double, at date: Date) {
        accumulated = elapsed(at: date)
        anchor = date
        rate = max(newRate, 0)
    }
}
