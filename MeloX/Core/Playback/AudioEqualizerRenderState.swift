import Synchronization

nonisolated struct AudioEqualizerRenderConfiguration {
    let isEnabled: Bool
    let preamp: Float
    let bandGains: SIMD16<Float>
    let revision: UInt64

    var isBypassed: Bool {
        guard isEnabled, abs(preamp) > 0.0001 || hasAdjustedBand else {
            return true
        }
        return false
    }

    private var hasAdjustedBand: Bool {
        for index in 0..<AudioEqualizerBand.count
        where abs(bandGains[index]) > 0.0001 {
            return true
        }
        return false
    }
}

nonisolated final class SharedAudioEqualizerConfiguration: Sendable {
    private let revision: Atomic<UInt64>
    private let header: Atomic<UInt64>
    private let gains01: Atomic<UInt64>
    private let gains23: Atomic<UInt64>
    private let gains45: Atomic<UInt64>
    private let gains67: Atomic<UInt64>
    private let gains89: Atomic<UInt64>

    init(configuration: AudioEqualizerConfiguration) {
        let renderConfiguration = Self.renderConfiguration(
            from: configuration,
            revision: 0
        )
        revision = Atomic(0)
        header = Atomic(Self.packHeader(renderConfiguration))
        gains01 = Atomic(Self.packGains(renderConfiguration, 0, 1))
        gains23 = Atomic(Self.packGains(renderConfiguration, 2, 3))
        gains45 = Atomic(Self.packGains(renderConfiguration, 4, 5))
        gains67 = Atomic(Self.packGains(renderConfiguration, 6, 7))
        gains89 = Atomic(Self.packGains(renderConfiguration, 8, 9))
    }

    @MainActor
    func update(_ configuration: AudioEqualizerConfiguration) {
        let nextRevision = revision.load(ordering: .relaxed) &+ 2
        let renderConfiguration = Self.renderConfiguration(
            from: configuration,
            revision: nextRevision
        )

        revision.wrappingAdd(
            1,
            ordering: .acquiringAndReleasing
        )
        header.store(
            Self.packHeader(renderConfiguration),
            ordering: .relaxed
        )
        gains01.store(
            Self.packGains(renderConfiguration, 0, 1),
            ordering: .relaxed
        )
        gains23.store(
            Self.packGains(renderConfiguration, 2, 3),
            ordering: .relaxed
        )
        gains45.store(
            Self.packGains(renderConfiguration, 4, 5),
            ordering: .relaxed
        )
        gains67.store(
            Self.packGains(renderConfiguration, 6, 7),
            ordering: .relaxed
        )
        gains89.store(
            Self.packGains(renderConfiguration, 8, 9),
            ordering: .relaxed
        )
        revision.wrappingAdd(1, ordering: .releasing)
    }

    func snapshot() -> AudioEqualizerRenderConfiguration {
        while true {
            let startingRevision = revision.load(ordering: .acquiring)
            guard startingRevision.isMultiple(of: 2) else { continue }

            let packedHeader = header.load(ordering: .relaxed)
            let packedGains01 = gains01.load(ordering: .relaxed)
            let packedGains23 = gains23.load(ordering: .relaxed)
            let packedGains45 = gains45.load(ordering: .relaxed)
            let packedGains67 = gains67.load(ordering: .relaxed)
            let packedGains89 = gains89.load(ordering: .relaxed)
            let endingRevision = revision.load(ordering: .acquiring)
            guard startingRevision == endingRevision else { continue }

            var gains = SIMD16<Float>(repeating: 0)
            let pair01 = Self.unpackPair(packedGains01)
            gains[0] = pair01.first
            gains[1] = pair01.second
            let pair23 = Self.unpackPair(packedGains23)
            gains[2] = pair23.first
            gains[3] = pair23.second
            let pair45 = Self.unpackPair(packedGains45)
            gains[4] = pair45.first
            gains[5] = pair45.second
            let pair67 = Self.unpackPair(packedGains67)
            gains[6] = pair67.first
            gains[7] = pair67.second
            let pair89 = Self.unpackPair(packedGains89)
            gains[8] = pair89.first
            gains[9] = pair89.second

            return AudioEqualizerRenderConfiguration(
                isEnabled: packedHeader & (1 << 32) != 0,
                preamp: Float(
                    bitPattern: UInt32(truncatingIfNeeded: packedHeader)
                ),
                bandGains: gains,
                revision: endingRevision
            )
        }
    }

    private static func renderConfiguration(
        from configuration: AudioEqualizerConfiguration,
        revision: UInt64
    ) -> AudioEqualizerRenderConfiguration {
        var gains = SIMD16<Float>(repeating: 0)
        for index in 0..<min(
            configuration.bandGains.count,
            AudioEqualizerBand.count
        ) {
            let gain = configuration.bandGains[index]
            gains[index] = Float(
                min(
                    max(
                        gain.isFinite ? gain : 0,
                        AudioEqualizerPreferences.bandGainRange.lowerBound
                    ),
                    AudioEqualizerPreferences.bandGainRange.upperBound
                )
            )
        }

        let preamp = configuration.preamp.isFinite
            ? configuration.preamp
            : 0
        return AudioEqualizerRenderConfiguration(
            isEnabled: configuration.isEnabled,
            preamp: Float(
                min(
                    max(
                        preamp,
                        AudioEqualizerPreferences.preampRange.lowerBound
                    ),
                    AudioEqualizerPreferences.preampRange.upperBound
                )
            ),
            bandGains: gains,
            revision: revision
        )
    }

    private static func packHeader(
        _ configuration: AudioEqualizerRenderConfiguration
    ) -> UInt64 {
        UInt64(configuration.preamp.bitPattern)
            | (configuration.isEnabled ? 1 << 32 : 0)
    }

    private static func packGains(
        _ configuration: AudioEqualizerRenderConfiguration,
        _ firstIndex: Int,
        _ secondIndex: Int
    ) -> UInt64 {
        UInt64(configuration.bandGains[firstIndex].bitPattern)
            | UInt64(
                configuration.bandGains[secondIndex].bitPattern
            ) << 32
    }

    private static func unpackPair(
        _ packedValue: UInt64
    ) -> (first: Float, second: Float) {
        (
            Float(bitPattern: UInt32(truncatingIfNeeded: packedValue)),
            Float(bitPattern: UInt32(truncatingIfNeeded: packedValue >> 32))
        )
    }
}
