@preconcurrency import AVFoundation
import Foundation

enum SongRecognitionRecordingError: LocalizedError {
    case microphonePermissionDenied
    case microphoneUnavailable
    case systemAudioPermissionDenied
    case systemAudioUnavailable
    case systemAudioTimedOut
    case recordingFailed(String)
    case recordingTimedOut
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            L10n.string("ui.recognition.error.microphone_permission")
        case .microphoneUnavailable:
            L10n.string("ui.recognition.error.microphone_unavailable")
        case .systemAudioPermissionDenied:
            L10n.string("ui.desktop.recognition.error.system_audio_permission")
        case .systemAudioUnavailable:
            L10n.string("ui.desktop.recognition.error.system_audio_unavailable")
        case .systemAudioTimedOut:
            L10n.string("ui.desktop.recognition.error.system_audio_timed_out")
        case .recordingFailed(let message):
            L10n.format("ui.recognition.error.recording_failed", message)
        case .recordingTimedOut:
            L10n.string("ui.recognition.error.recording_timed_out")
        case .conversionFailed:
            L10n.string("ui.recognition.error.conversion_failed")
        }
    }

    var opensSystemSettings: Bool {
        switch self {
        case .microphonePermissionDenied, .systemAudioPermissionDenied:
            true
        default:
            false
        }
    }
}

struct SongRecognitionAudioSnapshot {
    let samples: [Float]
    let duration: Int
    let totalDuration: Int
    let reachedLimit: Bool
}

@MainActor
final class SongRecognitionAudioRecorder {
    static let fingerprintSampleRate = 8_000.0
    private static let continuousWindowDuration = 9

    private var engine: AVAudioEngine?
    private var sampleBuffer: SongRecognitionSampleBuffer?
    private var sourceSampleRate = 0.0
    private var isTapInstalled = false
    private var systemAudioCapture: SongRecognitionSystemAudioCapture?

    func start(maximumDuration: Int?, source: SongRecognitionAudioSource) async throws {
        stop()
        resetCapture()

        if let maximumDuration,
           maximumDuration <= 0 {
            throw SongRecognitionRecordingError.conversionFailed
        }

        if source == .systemAudio {
            let recordingBuffer = makeSampleBuffer(
                sampleRate: SongRecognitionSystemAudioCapture.sampleRate,
                maximumDuration: maximumDuration
            )
            let capture = SongRecognitionSystemAudioCapture(recordingBuffer: recordingBuffer)
            systemAudioCapture = capture
            do {
                try await capture.start()
            } catch {
                stop()
                resetCapture()
                throw error
            }
            return
        }

        try await ensureMicrophonePermission()
        try Task.checkCancellation()

        let recordingEngine = AVAudioEngine()
        let inputNode = recordingEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              inputFormat.channelCount > 0,
              inputFormat.commonFormat == .pcmFormatFloat32 else {
            throw SongRecognitionRecordingError.microphoneUnavailable
        }

        let recordingBuffer = makeSampleBuffer(
            sampleRate: inputFormat.sampleRate,
            maximumDuration: maximumDuration
        )

        engine = recordingEngine

        inputNode.installTap(
            onBus: 0,
            bufferSize: 2_048,
            format: inputFormat
        ) { [weak self] buffer, _ in
            guard recordingBuffer.append(buffer) else { return }
            Task { @MainActor [weak self] in
                guard let self,
                      sampleBuffer === recordingBuffer else {
                    return
                }
                stopEngine()
            }
        }
        isTapInstalled = true

        do {
            recordingEngine.prepare()
            try recordingEngine.start()
        } catch {
            stop()
            resetCapture()
            throw SongRecognitionRecordingError.recordingFailed(
                error.localizedDescription
            )
        }
    }

    func snapshot() throws -> SongRecognitionAudioSnapshot? {
        if let failure = systemAudioCapture?.failure { throw failure }
        guard let sampleBuffer,
              sourceSampleRate > 0 else {
            return nil
        }

        let rawSnapshot = sampleBuffer.snapshot()
        let availableDuration = Int(
            Double(rawSnapshot.samples.count)
                / sourceSampleRate
        )
        let totalDuration = Int(
            Double(rawSnapshot.totalFrameCount)
                / sourceSampleRate
        )
        guard availableDuration > 0 else { return nil }

        let sourceFrameCount = min(
            rawSnapshot.samples.count,
            Int(
                (Double(availableDuration) * sourceSampleRate)
                    .rounded(.down)
            )
        )
        let sourceSamples = Array(
            rawSnapshot.samples.suffix(sourceFrameCount)
        )
        let targetFrameCount =
            availableDuration * Int(Self.fingerprintSampleRate)

        return SongRecognitionAudioSnapshot(
            samples: try resample(
                sourceSamples,
                sourceSampleRate: sourceSampleRate,
                targetFrameCount: targetFrameCount
            ),
            duration: availableDuration,
            totalDuration: totalDuration,
            reachedLimit: rawSnapshot.reachedLimit
        )
    }

    func cancel() {
        stop()
    }

    func prepareForConcurrentPlayback() {
        // macOS supports playback while either audio source is captured.
    }

    func stop() {
        stopEngine()
    }

    private func stopEngine() {
        systemAudioCapture?.stop()
        systemAudioCapture = nil
        guard let engine else { return }
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        engine.stop()
        self.engine = nil
    }

    private func resetCapture() {
        sampleBuffer = nil
        sourceSampleRate = 0
    }

    private func makeSampleBuffer(
        sampleRate: Double,
        maximumDuration: Int?
    ) -> SongRecognitionSampleBuffer {
        let retainedDuration = maximumDuration ?? Self.continuousWindowDuration
        let buffer = SongRecognitionSampleBuffer(
            retainedFrameCount: Int((Double(retainedDuration) * sampleRate).rounded(.up)),
            stoppingFrameCount: maximumDuration.map {
                Int((Double($0) * sampleRate).rounded(.up))
            }
        )
        sampleBuffer = buffer
        sourceSampleRate = sampleRate
        return buffer
    }

    private func ensureMicrophonePermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .denied, .restricted:
            throw SongRecognitionRecordingError
                .microphonePermissionDenied
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else {
                throw SongRecognitionRecordingError
                    .microphonePermissionDenied
            }
        @unknown default:
            throw SongRecognitionRecordingError
                .microphonePermissionDenied
        }
    }

    private func resample(
        _ samples: [Float],
        sourceSampleRate: Double,
        targetFrameCount: Int
    ) throws -> [Float] {
        guard !samples.isEmpty,
              targetFrameCount > 0 else {
            throw SongRecognitionRecordingError.conversionFailed
        }

        if sourceSampleRate == Self.fingerprintSampleRate {
            return normalizedFrameCount(
                samples,
                targetFrameCount: targetFrameCount
            )
        }

        guard let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceSampleRate,
            channels: 1,
            interleaved: false
        ),
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.fingerprintSampleRate,
            channels: 1,
            interleaved: false
        ),
        let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: AVAudioFrameCount(samples.count)
        ),
        let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(targetFrameCount + 32)
        ),
        let inputChannel = inputBuffer.floatChannelData?[0],
        let converter = AVAudioConverter(
            from: sourceFormat,
            to: targetFormat
        ) else {
            throw SongRecognitionRecordingError.conversionFailed
        }

        samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            inputChannel.update(
                from: baseAddress,
                count: samples.count
            )
        }
        inputBuffer.frameLength = AVAudioFrameCount(samples.count)
        converter.primeMethod = .none

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(
            to: outputBuffer,
            error: &conversionError
        ) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .endOfStream
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return inputBuffer
        }

        guard status != .error,
              conversionError == nil,
              let outputChannel = outputBuffer.floatChannelData?[0] else {
            throw SongRecognitionRecordingError.conversionFailed
        }

        let output = Array(
            UnsafeBufferPointer(
                start: outputChannel,
                count: Int(outputBuffer.frameLength)
            )
        )
        return normalizedFrameCount(
            output,
            targetFrameCount: targetFrameCount
        )
    }

    private func normalizedFrameCount(
        _ samples: [Float],
        targetFrameCount: Int
    ) -> [Float] {
        if samples.count >= targetFrameCount {
            return Array(samples.prefix(targetFrameCount))
        }
        return samples + Array(
            repeating: 0,
            count: targetFrameCount - samples.count
        )
    }
}
