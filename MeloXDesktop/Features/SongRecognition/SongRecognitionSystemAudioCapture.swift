@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import CoreMedia
import Foundation

@MainActor
final class SongRecognitionSystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    nonisolated static let sampleRate = 48_000.0

    nonisolated private let recordingBuffer: SongRecognitionSampleBuffer
    private let audioQueue = DispatchQueue(label: "MeloX.songRecognition.systemAudio")
    private var stream: SCStream?
    private(set) var failure: SongRecognitionRecordingError?

    init(recordingBuffer: SongRecognitionSampleBuffer) {
        self.recordingBuffer = recordingBuffer
    }

    func start() async throws {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )
            try Task.checkCancellation()
            guard let display = content.displays.first else {
                throw SongRecognitionRecordingError.systemAudioUnavailable
            }

            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = false
            configuration.captureMicrophone = false
            configuration.sampleRate = Int(Self.sampleRate)
            configuration.channelCount = 1
            configuration.width = 2
            configuration.height = 2
            configuration.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: 1)
            configuration.showsCursor = false

            let stream = SCStream(
                filter: SCContentFilter(display: display, excludingApplications: [], exceptingWindows: []),
                configuration: configuration,
                delegate: self
            )
            self.stream = stream
            // Register only audio output: no screen frames enter the app.
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
            do {
                try await stream.startCapture()
                try Task.checkCancellation()
            } catch {
                try? await stream.stopCapture()
                throw error
            }
        } catch is CancellationError {
            stop()
            throw CancellationError()
        } catch {
            stop()
            throw Self.recordingError(error)
        }
    }

    func stop() {
        guard let stream else { return }
        self.stream = nil
        try? stream.removeStreamOutput(self, type: .audio)
        stream.stopCapture { _ in }
    }

    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio, sampleBuffer.isValid, sampleBuffer.numSamples > 0 else { return }
        do {
            let reachedLimit = try Self.appendSamples(from: sampleBuffer, to: recordingBuffer)
            if reachedLimit {
                Task { @MainActor [weak self] in
                    guard let self, self.stream === stream else { return }
                    stop()
                }
            }
        } catch {
            Task { @MainActor [weak self] in
                guard let self, self.stream === stream else { return }
                failure = Self.recordingError(error)
                stop()
            }
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor [weak self] in
            guard let self, self.stream === stream else { return }
            failure = Self.recordingError(error)
            stop()
        }
    }

    nonisolated static func appendSamples(
        from sampleBuffer: CMSampleBuffer,
        to recordingBuffer: SongRecognitionSampleBuffer
    ) throws -> Bool {
        try sampleBuffer.withAudioBufferList { audioBufferList, _ in
            guard let description = sampleBuffer.formatDescription else {
                throw SongRecognitionRecordingError.conversionFailed
            }
            let format = AVAudioFormat(cmAudioFormatDescription: description)
            guard format.commonFormat == .pcmFormatFloat32,
                  format.sampleRate == Self.sampleRate,
                  let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    bufferListNoCopy: audioBufferList.unsafePointer
                  ) else {
                throw SongRecognitionRecordingError.conversionFailed
            }
            return recordingBuffer.append(buffer)
        }
    }

    private static func recordingError(_ error: any Error) -> SongRecognitionRecordingError {
        if let error = error as? SongRecognitionRecordingError { return error }
        let error = error as NSError
        if error.domain == SCStreamErrorDomain,
           error.code == SCStreamError.userDeclined.rawValue {
            return .systemAudioPermissionDenied
        }
        return .recordingFailed(error.localizedDescription)
    }
}
