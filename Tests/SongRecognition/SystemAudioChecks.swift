// Standalone checks; these generate PCM fixtures and never start audio capture.
// Run from the repository root:
// xcrun swiftc -parse-as-library \
//   MeloXDesktop/Core/Settings/Recognition/SongRecognitionAudioSource.swift \
//   MeloXDesktop/Core/Settings/Recognition/SongRecognitionPreferences.swift \
//   MeloXDesktop/Features/SongRecognition/SongRecognitionSampleBuffer.swift \
//   MeloXDesktop/Features/SongRecognition/SongRecognitionSystemAudioCapture.swift \
//   MeloXDesktop/Features/SongRecognition/SongRecognitionAudioRecorder.swift \
//   Tests/SongRecognition/SystemAudioChecks.swift -o /tmp/melox-system-audio-checks \
//   && /tmp/melox-system-audio-checks
import AVFoundation
import CoreMedia
import Foundation

enum L10n {
    static func string(_ key: String) -> String { key }
    static func format(_ key: String, _ arguments: CVarArg...) -> String { key }
}

@main
struct SystemAudioChecks {
    @MainActor
    static func main() throws {
        let domain = "MeloX.SystemAudioChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let preferences = SongRecognitionPreferences(defaults: defaults)
        precondition(preferences.audioSource == .microphone)
        preferences.duration = .extended
        preferences.audioSource = .systemAudio
        let restored = SongRecognitionPreferences(defaults: defaults)
        precondition(restored.audioSource == .systemAudio && restored.duration == .extended)
        defaults.set("unknown", forKey: "songRecognition.audioSource")
        precondition(SongRecognitionPreferences(defaults: defaults).audioSource == .microphone)
        print("PASS: source preferences persist and default to microphone")

        for interleaved in [false, true] {
            let source = pcm(interleaved: interleaved)
            let sample = try sampleBuffer(from: source)
            let buffer = SongRecognitionSampleBuffer(retainedFrameCount: 4, stoppingFrameCount: 4)
            let reachedLimit = try SongRecognitionSystemAudioCapture.appendSamples(from: sample, to: buffer)
            precondition(reachedLimit)
            let snapshot = buffer.snapshot()
            precondition(snapshot.samples == [0, 0.5, 0.5, -1])
            precondition(snapshot.totalFrameCount == 4 && snapshot.reachedLimit)
            let repeatedLimit = try SongRecognitionSystemAudioCapture.appendSamples(from: sample, to: buffer)
            precondition(!repeatedLimit && buffer.snapshot().totalFrameCount == 4)
            print("PASS: \(interleaved ? "interleaved" : "planar") PCM downmix and recording limit")
        }

        let source = try sampleBuffer(from: pcm(interleaved: true))
        let rolling = SongRecognitionSampleBuffer(retainedFrameCount: 3, stoppingFrameCount: nil)
        _ = try SongRecognitionSystemAudioCapture.appendSamples(from: source, to: rolling)
        _ = try SongRecognitionSystemAudioCapture.appendSamples(from: source, to: rolling)
        precondition(rolling.snapshot().samples == [0.5, 0.5, -1])
        precondition(rolling.snapshot().totalFrameCount == 8)
        precondition(!rolling.snapshot().reachedLimit)
        print("PASS: continuous capture retains a bounded rolling window")

        let invalidRate = try sampleBuffer(from: pcm(interleaved: false, sampleRate: 44_100))
        do {
            _ = try SongRecognitionSystemAudioCapture.appendSamples(from: invalidRate, to: rolling)
            fatalError("Unexpected sample rate was accepted")
        } catch SongRecognitionRecordingError.conversionFailed { }
        precondition(SongRecognitionRecordingError.systemAudioPermissionDenied.opensSystemSettings)
        precondition(SongRecognitionRecordingError.microphonePermissionDenied.opensSystemSettings)
        precondition(!SongRecognitionRecordingError.systemAudioTimedOut.opensSystemSettings)
        print("PASS: format errors and permission recovery")
    }

    private static func pcm(interleaved: Bool, sampleRate: Double = 48_000) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: interleaved
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4)!
        buffer.frameLength = 4
        let channels: [[Float]] = [[1, 0.5, 0, -1], [-1, 0.5, 1, -1]]
        for channel in 0..<2 {
            for frame in 0..<4 {
                if interleaved {
                    buffer.floatChannelData![0][frame * 2 + channel] = channels[channel][frame]
                } else {
                    buffer.floatChannelData![channel][frame] = channels[channel][frame]
                }
            }
        }
        return buffer
    }

    private static func sampleBuffer(from pcm: AVAudioPCMBuffer) throws -> CMSampleBuffer {
        var sample: CMSampleBuffer?
        let status = CMAudioSampleBufferCreateWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: pcm.format.formatDescription,
            sampleCount: Int(pcm.frameLength),
            presentationTimeStamp: .zero,
            packetDescriptions: nil,
            sampleBufferOut: &sample
        )
        precondition(status == noErr)
        try sample!.setDataBuffer(fromAudioBufferList: pcm.audioBufferList)
        precondition(CMSampleBufferSetDataReady(sample!) == noErr)
        return sample!
    }
}
