#if canImport(ScreenCaptureKit)
@preconcurrency import ScreenCaptureKit
import CoreMedia
import Foundation

@available(iOS 27, *)
@MainActor
final class SongRecognitionSystemAudioCapture: NSObject, SongRecognitionAudioCapture,
    SCStreamOutput, SCStreamDelegate, SCContentSharingPickerObserver {
    nonisolated private let buffer: SongRecognitionCapturedAudioBuffer
    private let capturesSystemAudio: Bool
    private let queue = DispatchQueue(label: "MeloX.recognition.capture")
    private var stream: SCStream?
    private var selection: CheckedContinuation<SCContentFilter, Error>?
    private(set) var failure: (any Error)?

    init(buffer: SongRecognitionCapturedAudioBuffer, capturesSystemAudio: Bool) {
        self.buffer = buffer
        self.capturesSystemAudio = capturesSystemAudio
    }

    func start() async throws {
        guard SCContentSharingPicker.shared.isAvailable else {
            throw SongRecognitionRecordingError.captureUnavailable
        }
        do {
            let filter = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    selection = continuation
                    let picker = SCContentSharingPicker.shared
                    picker.defaultConfiguration = SCContentSharingPickerConfiguration()
                    picker.add(self)
                    picker.isActive = true
                    if capturesSystemAudio { picker.present() }
                    else { picker.presentForCurrentApplication() }
                }
            } onCancel: {
                Task { @MainActor [weak self] in self?.stop() }
            }
            try Task.checkCancellation()

            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = false
            configuration.sampleRate = Int(SongRecognitionCapturedAudioBuffer.sampleRate)
            configuration.channelCount = 1
            configuration.width = 2
            configuration.height = 2
            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            self.stream = stream
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
            do {
                try await stream.startCapture()
                try Task.checkCancellation()
            } catch {
                try? await stream.stopCapture()
                throw error
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        let pendingSelection = selection
        selection = nil
        pendingSelection?.resume(throwing: CancellationError())
        let picker = SCContentSharingPicker.shared
        picker.remove(self)
        picker.isActive = false
        guard let stream else { return }
        self.stream = nil
        try? stream.removeStreamOutput(self, type: .audio)
        stream.stopCapture { _ in }
    }

    nonisolated func contentSharingPicker(
        _ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?
    ) {
        Task { @MainActor [weak self] in
            guard let self, let selection else { return }
            self.selection = nil
            selection.resume(returning: filter)
        }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if selection == nil { failure = CancellationError() }
            stop()
        }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let pendingSelection = selection
            selection = nil
            pendingSelection?.resume(throwing: error)
            stop()
        }
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        do {
            if try buffer.append(sample) {
                Task { @MainActor [weak self] in
                    guard let self, self.stream === stream else { return }
                    stop()
                }
            }
        } catch {
            report(error, from: stream)
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        report(error, from: stream)
    }

    nonisolated private func report(_ error: any Error, from stream: SCStream) {
        Task { @MainActor [weak self] in
            guard let self, self.stream === stream else { return }
            failure = error
            stop()
        }
    }
}
#endif
