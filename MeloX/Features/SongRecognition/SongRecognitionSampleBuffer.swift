@preconcurrency import AVFoundation
import Foundation

nonisolated struct SongRecognitionRawAudioSnapshot: Sendable {
    let samples: [Float]
    let totalFrameCount: Int64
    let reachedLimit: Bool
}

nonisolated final class SongRecognitionSampleBuffer:
    @unchecked Sendable
{
    private let retainedFrameCount: Int
    private let stoppingFrameCount: Int64?
    private let lock = NSLock()
    private var storage: [Float]
    private var writeIndex = 0
    private var storedFrameCount = 0
    private var totalFrameCount: Int64 = 0
    private var didSignalLimit = false

    init(
        retainedFrameCount: Int,
        stoppingFrameCount: Int?
    ) {
        self.retainedFrameCount = retainedFrameCount
        self.stoppingFrameCount = stoppingFrameCount.map(Int64.init)
        storage = Array(
            repeating: 0,
            count: retainedFrameCount
        )
    }

    /// Returns `true` once, when the configured recording limit is reached.
    func append(_ buffer: AVAudioPCMBuffer) -> Bool {
        lock.withLock {
            guard retainedFrameCount > 0,
                  let channelData = buffer.floatChannelData else {
                return false
            }

            let availableFrameCount = Int(buffer.frameLength)
            let framesToCopy: Int
            if let stoppingFrameCount {
                let remainingFrameCount = max(
                    stoppingFrameCount - totalFrameCount,
                    0
                )
                framesToCopy = min(
                    availableFrameCount,
                    Int(remainingFrameCount)
                )
            } else {
                framesToCopy = availableFrameCount
            }
            guard framesToCopy > 0 else { return false }

            let channelCount = Int(buffer.format.channelCount)
            guard channelCount > 0 else { return false }

            for frame in 0..<framesToCopy {
                let sample: Float
                if channelCount == 1 {
                    sample = channelData[0][frame]
                } else {
                    var mixedSample: Float = 0
                    for channel in 0..<channelCount {
                        mixedSample += buffer.format.isInterleaved
                            ? channelData[0][frame * channelCount + channel]
                            : channelData[channel][frame]
                    }
                    sample = mixedSample / Float(channelCount)
                }

                storage[writeIndex] = sample
                writeIndex += 1
                if writeIndex == retainedFrameCount {
                    writeIndex = 0
                }
                storedFrameCount = min(
                    storedFrameCount + 1,
                    retainedFrameCount
                )
            }
            totalFrameCount += Int64(framesToCopy)

            guard let stoppingFrameCount,
                  totalFrameCount == stoppingFrameCount,
                  !didSignalLimit else {
                return false
            }
            didSignalLimit = true
            return true
        }
    }

    func snapshot() -> SongRecognitionRawAudioSnapshot {
        lock.withLock {
            let samples: [Float]
            if storedFrameCount < retainedFrameCount {
                samples = Array(storage.prefix(storedFrameCount))
            } else {
                samples =
                    Array(storage[writeIndex...])
                    + Array(storage[..<writeIndex])
            }
            return SongRecognitionRawAudioSnapshot(
                samples: samples,
                totalFrameCount: totalFrameCount,
                reachedLimit:
                    stoppingFrameCount == totalFrameCount
            )
        }
    }
}
