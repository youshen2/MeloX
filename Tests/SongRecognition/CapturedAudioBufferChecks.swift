// PCM fixtures only; no microphone, screen recorder, or system picker is started.
// Run from the repository root:
// xcrun swiftc -parse-as-library \
//   MeloX/Features/SongRecognition/SongRecognitionSampleBuffer.swift \
//   MeloX/Features/SongRecognition/SongRecognitionCapturedAudioBuffer.swift \
//   Tests/SongRecognition/CapturedAudioBufferChecks.swift \
//   -o /tmp/melox-captured-audio-checks && /tmp/melox-captured-audio-checks
import AVFoundation
import CoreMedia
import Foundation

enum SongRecognitionRecordingError: Error { case conversionFailed }

@main
struct CapturedAudioBufferChecks {
    static func main() throws {
        for interleaved in [false, true] {
            let buffer = SongRecognitionSampleBuffer(retainedFrameCount: 480, stoppingFrameCount: 480)
            let captured = SongRecognitionCapturedAudioBuffer(recordingBuffer: buffer)
            let sample = try makeSample(rate: 48_000, frames: 480, interleaved: interleaved, int16: false)
            let finished = try captured.append(sample)
            precondition(finished)
            precondition(buffer.snapshot().samples.allSatisfy { abs($0 - 0.5) < 0.001 })
            let repeated = try captured.append(sample)
            precondition(!repeated && buffer.snapshot().totalFrameCount == 480)
        }
        print("PASS: planar/interleaved capture and one-shot limit")

        let buffer = SongRecognitionSampleBuffer(retainedFrameCount: 960, stoppingFrameCount: nil)
        let captured = SongRecognitionCapturedAudioBuffer(recordingBuffer: buffer)
        let integerSample = try makeSample(rate: 44_100, frames: 441, interleaved: true, int16: true)
        _ = try captured.append(integerSample)
        _ = try captured.append(integerSample)
        let snapshot = buffer.snapshot()
        precondition((900...960).contains(snapshot.samples.count))
        precondition(snapshot.samples.dropFirst(32).allSatisfy { abs($0 - 0.5) < 0.01 })
        precondition(!snapshot.reachedLimit)
        print("PASS: ReplayKit-style Int16/44.1 kHz conversion to Float32/48 kHz")

        _ = try captured.append(integerSample)
        precondition(buffer.snapshot().samples.count == 960)
        precondition(buffer.snapshot().totalFrameCount > 960)
        print("PASS: continuous capture retains bounded memory")
    }

    private static func makeSample(
        rate: Double, frames: UInt32, interleaved: Bool, int16: Bool
    ) throws -> CMSampleBuffer {
        let format = AVAudioFormat(commonFormat: int16 ? .pcmFormatInt16 : .pcmFormatFloat32,
                                   sampleRate: rate, channels: 2, interleaved: interleaved)!
        let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        pcm.frameLength = frames
        for frame in 0..<Int(frames) {
            for channel in 0..<2 {
                let channelIndex = interleaved ? 0 : channel
                let sampleIndex = interleaved ? frame * 2 + channel : frame
                if int16 { pcm.int16ChannelData![channelIndex][sampleIndex] = 16_384 }
                else { pcm.floatChannelData![channelIndex][sampleIndex] = 0.5 }
            }
        }
        var sample: CMSampleBuffer?
        let status = CMAudioSampleBufferCreateWithPacketDescriptions(
            allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: format.formatDescription,
            sampleCount: Int(frames), presentationTimeStamp: .zero, packetDescriptions: nil,
            sampleBufferOut: &sample
        )
        precondition(status == noErr)
        try sample!.setDataBuffer(fromAudioBufferList: pcm.audioBufferList)
        precondition(CMSampleBufferSetDataReady(sample!) == noErr)
        return sample!
    }
}
