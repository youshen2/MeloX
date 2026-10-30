@preconcurrency import AVFoundation
import CoreMedia
import Foundation

@MainActor
protocol SongRecognitionAudioCapture: AnyObject {
    var failure: (any Error)? { get }
    func start() async throws
    func stop()
}

nonisolated final class SongRecognitionCapturedAudioBuffer: @unchecked Sendable {
    static let sampleRate = 48_000.0
    private let recordingBuffer: SongRecognitionSampleBuffer
    private let lock = NSLock()
    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: 1,
        interleaved: false
    )!
    private var converter: AVAudioConverter?

    init(recordingBuffer: SongRecognitionSampleBuffer) {
        self.recordingBuffer = recordingBuffer
    }

    func append(_ sample: CMSampleBuffer) throws -> Bool {
        guard sample.isValid, sample.numSamples > 0 else { return false }
        return try sample.withAudioBufferList { buffers, _ in
            guard let description = sample.formatDescription else {
                throw SongRecognitionRecordingError.conversionFailed
            }
            let format = AVAudioFormat(cmAudioFormatDescription: description)
            guard format.sampleRate > 0, format.channelCount > 0,
                  let input = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: buffers.unsafePointer) else {
                throw SongRecognitionRecordingError.conversionFailed
            }
            if format.commonFormat == .pcmFormatFloat32, format.sampleRate == Self.sampleRate {
                return recordingBuffer.append(input)
            }

            return try lock.withLock {
                if converter?.inputFormat != format {
                    converter = AVAudioConverter(from: format, to: outputFormat)
                    converter?.primeMethod = .none
                }
                let capacity = AVAudioFrameCount(
                    (Double(input.frameLength) * Self.sampleRate / format.sampleRate).rounded(.up)
                ) + 32
                guard let converter,
                      let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
                    throw SongRecognitionRecordingError.conversionFailed
                }
                var suppliedInput = false
                var error: NSError?
                let status = converter.convert(to: output, error: &error) { _, inputStatus in
                    if suppliedInput {
                        inputStatus.pointee = .noDataNow
                        return nil
                    }
                    suppliedInput = true
                    inputStatus.pointee = .haveData
                    return input
                }
                guard status != .error, error == nil else {
                    throw SongRecognitionRecordingError.conversionFailed
                }
                return recordingBuffer.append(output)
            }
        }
    }
}
