@preconcurrency import AVFoundation
import Foundation

enum SongRecognitionRecordingError: LocalizedError {
    case microphonePermissionDenied
    case microphoneUnavailable
    case recordingFailed(String)
    case recordingTimedOut
    case conversionFailed
    case captureUnavailable
    case captureTimedOut

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            L10n.string("ui.recognition.error.microphone_permission")
        case .microphoneUnavailable:
            L10n.string("ui.recognition.error.microphone_unavailable")
        case .recordingFailed(let message):
            L10n.format("ui.recognition.error.recording_failed", message)
        case .recordingTimedOut:
            L10n.string("ui.recognition.error.recording_timed_out")
        case .conversionFailed:
            L10n.string("ui.recognition.error.conversion_failed")
        case .captureUnavailable:
            L10n.string("ui.recognition.error.capture_unavailable")
        case .captureTimedOut:
            L10n.string("ui.recognition.error.capture_timed_out")
        }
    }

    var opensSystemSettings: Bool {
        if case .microphonePermissionDenied = self {
            true
        } else {
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
    private var isSessionActive = false
    private var shouldPreservePlaybackSession = false
    private var audioCapture: (any SongRecognitionAudioCapture)?

    func start(maximumDuration: Int?, source: SongRecognitionAudioSource) async throws {
        stop()
        resetCapture()
        shouldPreservePlaybackSession = false

        if let maximumDuration,
           maximumDuration <= 0 {
            throw SongRecognitionRecordingError.conversionFailed
        }

        if source != .microphone {
            let recordingBuffer = makeSampleBuffer(
                sampleRate: SongRecognitionCapturedAudioBuffer.sampleRate,
                maximumDuration: maximumDuration
            )
            let buffer = SongRecognitionCapturedAudioBuffer(recordingBuffer: recordingBuffer)
            let capture = try makeAudioCapture(source: source, buffer: buffer)
            audioCapture = capture
            do { try await capture.start() }
            catch {
                stop()
                resetCapture()
                throw error
            }
            return
        }

        try await ensureMicrophonePermission()
        try Task.checkCancellation()

        let session = AVAudioSession.sharedInstance()
        do {
            let category: AVAudioSession.Category =
                maximumDuration == nil ? .playAndRecord : .record
            let options: AVAudioSession.CategoryOptions =
                maximumDuration == nil
                ? [.allowBluetoothHFP, .defaultToSpeaker]
                : [.allowBluetoothHFP]
            try session.setCategory(
                category,
                mode: .measurement,
                options: options
            )
            try session.setActive(true)
            isSessionActive = true
        } catch {
            throw SongRecognitionRecordingError.recordingFailed(
                error.localizedDescription
            )
        }

        let recordingEngine = AVAudioEngine()
        let inputNode = recordingEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              inputFormat.channelCount > 0,
              inputFormat.commonFormat == .pcmFormatFloat32 else {
            stopAudioSession()
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
                stopAudioSession()
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
        if let failure = audioCapture?.failure { throw failure }
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
        shouldPreservePlaybackSession = true
    }

    func stop() {
        stopEngine()
        stopAudioSession()
    }

    private func stopEngine() {
        audioCapture?.stop()
        audioCapture = nil
        guard let engine else { return }
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        engine.stop()
        self.engine = nil
    }

    private func stopAudioSession() {
        guard isSessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        if shouldPreservePlaybackSession {
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)
        } else {
            try? session.setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
        isSessionActive = false
    }

    private func resetCapture() {
        sampleBuffer = nil
        sourceSampleRate = 0
    }

    private func makeSampleBuffer(sampleRate: Double, maximumDuration: Int?) -> SongRecognitionSampleBuffer {
        let duration = maximumDuration ?? Self.continuousWindowDuration
        let buffer = SongRecognitionSampleBuffer(
            retainedFrameCount: Int((Double(duration) * sampleRate).rounded(.up)),
            stoppingFrameCount: maximumDuration.map { Int((Double($0) * sampleRate).rounded(.up)) }
        )
        sourceSampleRate = sampleRate
        sampleBuffer = buffer
        return buffer
    }

    private func makeAudioCapture(
        source: SongRecognitionAudioSource,
        buffer: SongRecognitionCapturedAudioBuffer
    ) throws -> any SongRecognitionAudioCapture {
        #if canImport(ScreenCaptureKit)
        if #available(iOS 27, *) {
            return SongRecognitionSystemAudioCapture(buffer: buffer, capturesSystemAudio: source == .systemAudio)
        }
        #endif
        guard source == .appAudio else { throw SongRecognitionRecordingError.captureUnavailable }
        return SongRecognitionAppAudioCapture(buffer: buffer)
    }

    private func ensureMicrophonePermission() async throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return
        case .denied:
            throw SongRecognitionRecordingError
                .microphonePermissionDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { isGranted in
                    continuation.resume(returning: isGranted)
                }
            }
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
