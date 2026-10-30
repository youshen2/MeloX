import Foundation

nonisolated enum AutoMixEqualizerEnvelope {
    static func adjustments(
        at rawProgress: Double
    ) -> (
        outgoing: (
            low: Float,
            mid: Float,
            high: Float
        ),
        incoming: (
            low: Float,
            mid: Float,
            high: Float
        )
    ) {
        let progress =
            min(max(rawProgress, 0), 1)
        let bassSwap = smoothstep(
            (progress - 0.24) / 0.52
        )
        let outgoingExit = smoothstep(
            (progress - 0.5) / 0.5
        )
        let incomingEntry = smoothstep(
            progress / 0.48
        )

        return (
            outgoing: (
                low: Float(-12 * bassSwap),
                mid: Float(-3.5 * outgoingExit),
                high: Float(-1.5 * outgoingExit)
            ),
            incoming: (
                low:
                    Float(
                        -12
                            * (1 - bassSwap)
                    ),
                mid:
                    Float(
                        -2.5
                            * (1 - incomingEntry)
                    ),
                high:
                    Float(
                        -1
                            * (1 - incomingEntry)
                    )
            )
        )
    }

    private static func smoothstep(
        _ rawValue: Double
    ) -> Double {
        let value = min(max(rawValue, 0), 1)
        return value * value * (3 - 2 * value)
    }
}
