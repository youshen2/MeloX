import AVFoundation
import Foundation
import Synchronization

nonisolated struct PlaybackAudioSpectrumSnapshot:
    Equatable,
    Sendable
{
    static let zero = PlaybackAudioSpectrumSnapshot(
        low: 0,
        mid: 0,
        high: 0,
        overall: 0
    )

    let low: Float
    let mid: Float
    let high: Float
    let overall: Float
}

nonisolated final class SharedPlaybackAudioSpectrum: Sendable {
    private let revision = Atomic<UInt64>(0)
    private let lowAndMid = Atomic<UInt64>(0)
    private let highAndOverall = Atomic<UInt64>(0)

    func publish(_ snapshot: PlaybackAudioSpectrumSnapshot) {
        revision.wrappingAdd(
            1,
            ordering: .acquiringAndReleasing
        )
        lowAndMid.store(
            Self.pack(snapshot.low, snapshot.mid),
            ordering: .relaxed
        )
        highAndOverall.store(
            Self.pack(snapshot.high, snapshot.overall),
            ordering: .relaxed
        )
        revision.wrappingAdd(1, ordering: .releasing)
    }

    func snapshot() -> PlaybackAudioSpectrumSnapshot {
        while true {
            let startingRevision = revision.load(ordering: .acquiring)
            guard startingRevision.isMultiple(of: 2) else { continue }

            let packedLowAndMid = lowAndMid.load(ordering: .relaxed)
            let packedHighAndOverall = highAndOverall.load(
                ordering: .relaxed
            )
            let endingRevision = revision.load(ordering: .acquiring)
            guard startingRevision == endingRevision else { continue }

            let lowAndMid = Self.unpack(packedLowAndMid)
            let highAndOverall = Self.unpack(packedHighAndOverall)
            return PlaybackAudioSpectrumSnapshot(
                low: lowAndMid.first,
                mid: lowAndMid.second,
                high: highAndOverall.first,
                overall: highAndOverall.second
            )
        }
    }

    private static func pack(_ first: Float, _ second: Float) -> UInt64 {
        UInt64(first.bitPattern)
            | UInt64(second.bitPattern) << 32
    }

    private static func unpack(
        _ packedValue: UInt64
    ) -> (first: Float, second: Float) {
        (
            Float(bitPattern: UInt32(truncatingIfNeeded: packedValue)),
            Float(bitPattern: UInt32(truncatingIfNeeded: packedValue >> 32))
        )
    }
}

/// A real-time-safe, three-band envelope follower matching the ranges and
/// temporal response used by Music's Backdrop renderer.
nonisolated final class PlaybackAudioSpectrumAnalyzer {
    private static let delayCount = 10
    private static let historyCount = 4
    private static let historyWeights = SIMD4<Float>(0.1, 0.2, 0.3, 0.4)

    private let sharedSpectrum: SharedPlaybackAudioSpectrum
    private var sampleRate = 0.0
    private var channelCount = 0
    private var lowCoefficient: Float = 0
    private var midCoefficient: Float = 0
    private var lowFilterState: [Float] = []
    private var midFilterState: [Float] = []
    private var delayedBands = Array(
        repeating: SIMD3<Float>(repeating: 0),
        count: delayCount
    )
    private var recentBands = Array(
        repeating: SIMD3<Float>(repeating: 0),
        count: historyCount
    )
    private var delayIndex = 0
    private var recentIndex = 0
    private var target = SIMD3<Float>(repeating: 0)
    private var current = SIMD3<Float>(repeating: 0)

    init(sharedSpectrum: SharedPlaybackAudioSpectrum) {
        self.sharedSpectrum = sharedSpectrum
    }

    func prepare(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = max(channelCount, 1)
        lowCoefficient = Self.lowPassCoefficient(
            cutoff: 300,
            sampleRate: sampleRate
        )
        midCoefficient = Self.lowPassCoefficient(
            cutoff: 3_500,
            sampleRate: sampleRate
        )
        lowFilterState = Array(
            repeating: 0,
            count: self.channelCount
        )
        midFilterState = Array(
            repeating: 0,
            count: self.channelCount
        )
        reset()
    }

    func reset() {
        for index in lowFilterState.indices {
            lowFilterState[index] = 0
            midFilterState[index] = 0
        }
        for index in delayedBands.indices {
            delayedBands[index] = .zero
        }
        for index in recentBands.indices {
            recentBands[index] = .zero
        }
        delayIndex = 0
        recentIndex = 0
        target = .zero
        current = .zero
        sharedSpectrum.publish(.zero)
    }

    func process(buffer: AVAudioPCMBuffer) {
        if sampleRate != buffer.format.sampleRate || channelCount != Int(buffer.format.channelCount) {
            prepare(sampleRate: buffer.format.sampleRate, channelCount: Int(buffer.format.channelCount))
        }
        process(bufferList: buffer.mutableAudioBufferList, frameCount: Int(buffer.frameLength))
    }

    func process(
        bufferList: UnsafeMutablePointer<AudioBufferList>,
        frameCount: Int
    ) {
        guard sampleRate > 0,
              frameCount > 0,
              !lowFilterState.isEmpty else {
            return
        }

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        var energy = SIMD3<Double>(repeating: 0)
        var analyzedSampleCount = 0
        var channelBase = 0

        for buffer in buffers {
            guard let data = buffer.mData else {
                channelBase += Int(buffer.mNumberChannels)
                continue
            }

            let channelsInBuffer = max(Int(buffer.mNumberChannels), 1)
            let availableSampleCount = Int(buffer.mDataByteSize)
                / MemoryLayout<Float>.stride
            let requestedSampleCount = frameCount * channelsInBuffer
            let sampleCount = min(availableSampleCount, requestedSampleCount)
            let samples = data.assumingMemoryBound(to: Float.self)

            if channelsInBuffer == 1 {
                analyzeNoninterleaved(
                    samples: samples,
                    sampleCount: sampleCount,
                    channel: channelBase,
                    energy: &energy,
                    analyzedSampleCount: &analyzedSampleCount
                )
            } else {
                analyzeInterleaved(
                    samples: samples,
                    sampleCount: sampleCount,
                    channelsInBuffer: channelsInBuffer,
                    channelBase: channelBase,
                    energy: &energy,
                    analyzedSampleCount: &analyzedSampleCount
                )
            }
            channelBase += channelsInBuffer
        }

        guard analyzedSampleCount > 0 else { return }
        let divisor = Double(analyzedSampleCount)
        let rawBands = SIMD3<Float>(
            Self.normalizedPower(sqrt(energy.x / divisor)),
            Self.normalizedPower(sqrt(energy.y / divisor)),
            Self.normalizedPower(sqrt(energy.z / divisor))
        )
        updateEnvelope(
            with: Self.smootherstep(rawBands),
            duration: Double(frameCount) / sampleRate
        )
    }

    private func analyzeNoninterleaved(
        samples: UnsafeMutablePointer<Float>,
        sampleCount: Int,
        channel: Int,
        energy: inout SIMD3<Double>,
        analyzedSampleCount: inout Int
    ) {
        guard channel < channelCount else { return }
        for index in 0..<sampleCount {
            accumulate(
                sample: samples[index],
                channel: channel,
                energy: &energy
            )
        }
        analyzedSampleCount += sampleCount
    }

    private func analyzeInterleaved(
        samples: UnsafeMutablePointer<Float>,
        sampleCount: Int,
        channelsInBuffer: Int,
        channelBase: Int,
        energy: inout SIMD3<Double>,
        analyzedSampleCount: inout Int
    ) {
        let frameCount = sampleCount / channelsInBuffer
        for frameIndex in 0..<frameCount {
            for localChannel in 0..<channelsInBuffer {
                let channel = channelBase + localChannel
                guard channel < channelCount else { continue }
                accumulate(
                    sample: samples[
                        frameIndex * channelsInBuffer + localChannel
                    ],
                    channel: channel,
                    energy: &energy
                )
                analyzedSampleCount += 1
            }
        }
    }

    private func accumulate(
        sample: Float,
        channel: Int,
        energy: inout SIMD3<Double>
    ) {
        let finiteSample = sample.isFinite ? sample : 0
        var low = lowFilterState[channel]
        var lowAndMid = midFilterState[channel]
        low += lowCoefficient * (finiteSample - low)
        lowAndMid += midCoefficient * (finiteSample - lowAndMid)
        lowFilterState[channel] = low
        midFilterState[channel] = lowAndMid

        let mid = lowAndMid - low
        let high = finiteSample - lowAndMid
        energy.x += Double(low * low)
        energy.y += Double(mid * mid)
        energy.z += Double(high * high)
    }

    private func updateEnvelope(
        with bands: SIMD3<Float>,
        duration: TimeInterval
    ) {
        let delayed = delayedBands[delayIndex]
        delayedBands[delayIndex] = bands
        delayIndex = (delayIndex + 1) % Self.delayCount

        recentBands[recentIndex] = delayed
        recentIndex = (recentIndex + 1) % Self.historyCount

        var weighted = SIMD3<Float>(repeating: 0)
        for offset in 0..<Self.historyCount {
            let index = (recentIndex + offset) % Self.historyCount
            weighted += recentBands[index]
                * Self.historyWeights[offset]
        }

        let equivalentFrames = Float(max(duration, 0) * 120)
        target.x *= pow(49.0 / 50.0, equivalentFrames)
        target.y *= pow(99.0 / 100.0, equivalentFrames)
        target.z *= pow(999.0 / 1_000.0, equivalentFrames)
        target = max(target, weighted)

        let retention = pow(0.5, equivalentFrames)
        current = target + (current - target) * retention
        let overall = max(current.x, max(current.y, current.z))
        sharedSpectrum.publish(
            PlaybackAudioSpectrumSnapshot(
                low: current.x,
                mid: current.y,
                high: current.z,
                overall: overall
            )
        )
    }

    private static func lowPassCoefficient(
        cutoff: Double,
        sampleRate: Double
    ) -> Float {
        guard sampleRate > 0 else { return 0 }
        let limitedCutoff = min(cutoff, sampleRate * 0.45)
        return Float(1 - exp(-2 * Double.pi * limitedCutoff / sampleRate))
    }

    private static func normalizedPower(_ rootMeanSquare: Double) -> Float {
        guard rootMeanSquare.isFinite, rootMeanSquare > 0 else { return 0 }
        let decibels = 20 * log10(rootMeanSquare)
        return Float(min(max((decibels + 55) / 47, 0), 1))
    }

    private static func smootherstep(_ value: SIMD3<Float>) -> SIMD3<Float> {
        value * value * value * (value * (value * 6 - 15) + 10)
    }
}
