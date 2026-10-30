@preconcurrency import ReplayKit
import Foundation

@MainActor
final class SongRecognitionAppAudioCapture: SongRecognitionAudioCapture {
    nonisolated private let buffer: SongRecognitionCapturedAudioBuffer
    private let recorder = RPScreenRecorder.shared()
    private var ownsRecording = false
    private(set) var failure: (any Error)?

    init(buffer: SongRecognitionCapturedAudioBuffer) {
        self.buffer = buffer
    }

    func start() async throws {
        guard recorder.isAvailable, !recorder.isRecording else {
            throw SongRecognitionRecordingError.captureUnavailable
        }
        ownsRecording = true
        recorder.isMicrophoneEnabled = false
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                recorder.startCapture { [weak self, buffer] sample, type, error in
                    if let error {
                        Task { @MainActor [weak self] in
                            self?.failure = error
                            self?.stop()
                        }
                        return
                    }
                    guard type == .audioApp else { return }
                    do {
                        if try buffer.append(sample) {
                            Task { @MainActor [weak self] in self?.stop() }
                        }
                    } catch {
                        Task { @MainActor [weak self] in
                            self?.failure = error
                            self?.stop()
                        }
                    }
                } completionHandler: { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
            try Task.checkCancellation()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        guard ownsRecording, recorder.isRecording else { return }
        ownsRecording = false
        recorder.stopCapture { _ in }
    }
}
