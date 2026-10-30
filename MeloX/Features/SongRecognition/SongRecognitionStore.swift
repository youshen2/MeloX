import Foundation
import Observation
import UIKit

enum SongRecognitionPhase: Equatable {
    case ready
    case requestingPermission
    case listening
    case matching
    case results
    case noMatch
    case failed(SongRecognitionFailure)

    var isWorking: Bool {
        switch self {
        case .requestingPermission, .listening, .matching:
            true
        case .ready, .results, .noMatch, .failed:
            false
        }
    }
}

struct SongRecognitionFailure: Equatable {
    let message: String
    let opensSystemSettings: Bool
}

@MainActor
@Observable
final class SongRecognitionStore {
    private static let queryInterval = 3
    private static let maximumStoredResults = 100

    private(set) var phase: SongRecognitionPhase = .ready
    private(set) var results: [SongRecognitionResult] = []
    private(set) var isContinuous = false
    private(set) var audioSource: SongRecognitionAudioSource = .microphone

    @ObservationIgnored
    private let recorder = SongRecognitionAudioRecorder()

    @ObservationIgnored
    private let fingerprintGenerator =
        NeteaseAudioFingerprintGenerator()

    @ObservationIgnored
    private var recognitionTask: Task<Void, Never>?

    @ObservationIgnored
    private var generation = 0

    func start(
        api: NeteaseAPI,
        duration: SongRecognitionDuration,
        source: SongRecognitionAudioSource
    ) {
        guard !phase.isWorking else { return }

        let previousTask = recognitionTask
        previousTask?.cancel()
        recorder.cancel()
        generation &+= 1
        let currentGeneration = generation
        results = []
        isContinuous = duration.isContinuous
        audioSource = source
        phase = .requestingPermission

        recognitionTask = Task { @MainActor [weak self] in
            // Let an earlier asynchronous capture startup finish its cleanup.
            await previousTask?.value
            guard let self else { return }
            guard !Task.isCancelled, generation == currentGeneration else { return }
            await recognize(
                api: api,
                duration: duration,
                source: source,
                generation: currentGeneration
            )
        }
    }

    func stopContinuousRecognition() {
        guard isContinuous, phase.isWorking else { return }

        generation &+= 1
        recognitionTask?.cancel()
        recorder.cancel()
        phase = results.isEmpty ? .noMatch : .results
    }

    func prepareForResultPlayback() {
        guard isContinuous, phase.isWorking else { return }
        recorder.prepareForConcurrentPlayback()
    }

    func cancel() {
        let wasWorking = phase.isWorking
        generation &+= 1
        recognitionTask?.cancel()
        recorder.cancel()
        if wasWorking {
            phase = .ready
        }
    }

    private func recognize(
        api: NeteaseAPI,
        duration: SongRecognitionDuration,
        source: SongRecognitionAudioSource,
        generation currentGeneration: Int
    ) async {
        defer {
            if generation == currentGeneration {
                recognitionTask = nil
            }
        }

        do {
            try await recorder.start(
                maximumDuration: duration.maximumDuration,
                source: source
            )
            defer {
                if generation == currentGeneration { recorder.stop() }
            }
            try Task.checkCancellation()
            guard generation == currentGeneration else { return }

            phase = .listening
            var nextQueryDuration = min(
                Self.queryInterval,
                duration.maximumDuration ?? Self.queryInterval
            )

            while true {
                var snapshot = try await waitForSnapshot(
                    minimumTotalDuration: nextQueryDuration
                )

                try Task.checkCancellation()
                guard generation == currentGeneration else { return }

                if source != .microphone {
                    // Keep capture active in other apps; run the WebKit fingerprint runtime in the foreground.
                    while UIApplication.shared.applicationState != .active {
                        try await Task.sleep(for: .milliseconds(500))
                    }
                    try Task.checkCancellation()
                    if let latest = try recorder.snapshot() { snapshot = latest }
                }

                if snapshot.reachedLimit {
                    recorder.stop()
                    phase = .matching
                }

                let fingerprint =
                    try await fingerprintGenerator.generate(
                        from: snapshot.samples
                    )
                let candidates = try await api.audioMatches(
                    fingerprint: fingerprint,
                    duration: snapshot.duration
                )

                try Task.checkCancellation()
                guard generation == currentGeneration else { return }

                let immediateResults = candidateResults(
                    from: candidates
                )
                if !immediateResults.isEmpty {
                    if duration.isContinuous {
                        mergeContinuousResults(immediateResults)
                        phase = .listening
                    } else {
                        recorder.stop()
                        results = immediateResults
                        phase = .results
                    }

                    let detailedResults = await resolvedResults(
                        from: immediateResults,
                        api: api
                    )
                    guard generation == currentGeneration else {
                        return
                    }
                    if duration.isContinuous {
                        mergeContinuousResults(detailedResults)
                    } else {
                        results = detailedResults
                        return
                    }
                }

                if snapshot.reachedLimit {
                    phase = .noMatch
                    return
                }

                phase = .listening
                let nextDuration =
                    snapshot.totalDuration + Self.queryInterval
                nextQueryDuration = min(
                    duration.maximumDuration ?? nextDuration,
                    nextDuration
                )
            }
        } catch is CancellationError {
            guard generation == currentGeneration else { return }
            phase = .ready
        } catch {
            guard generation == currentGeneration else { return }
            let recordingError =
                error as? SongRecognitionRecordingError
            phase = .failed(
                SongRecognitionFailure(
                    message: error.localizedDescription,
                    opensSystemSettings:
                        recordingError?.opensSystemSettings ?? false
                )
            )
        }
    }

    private func waitForSnapshot(
        minimumTotalDuration: Int
    ) async throws -> SongRecognitionAudioSnapshot {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(
            by: .seconds(Self.queryInterval + 4)
        )

        while true {
            try Task.checkCancellation()
            if let snapshot = try recorder.snapshot(),
               snapshot.totalDuration >= minimumTotalDuration
                    || snapshot.reachedLimit {
                return snapshot
            }
            guard clock.now < deadline else {
                throw audioSource != .microphone
                    ? SongRecognitionRecordingError.captureTimedOut
                    : SongRecognitionRecordingError.recordingTimedOut
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func candidateResults(
        from candidates: [AudioMatchCandidate]
    ) -> [SongRecognitionResult] {
        var results: [SongRecognitionResult] = []
        var seenIDs = Set<Int>()

        for candidate in candidates
        where candidate.song.id > 0
            && seenIDs.insert(candidate.song.id).inserted {
            results.append(
                SongRecognitionResult(
                    song: candidate.song,
                    startTimeMilliseconds: candidate.startTime
                )
            )
        }
        return results
    }

    private func resolvedResults(
        from results: [SongRecognitionResult],
        api: NeteaseAPI
    ) async -> [SongRecognitionResult] {
        let orderedIDs = results.map(\.id)
        guard !orderedIDs.isEmpty else { return [] }

        let detailedSongs = try? await api.songDetails(ids: orderedIDs)
        var detailByID: [Int: Song] = [:]
        for song in detailedSongs ?? [] {
            detailByID[song.id] = song
        }

        return results.map { result in
            var resolvedResult = result
            if let detailedSong = detailByID[result.id] {
                resolvedResult.song = detailedSong
            }
            return resolvedResult
        }
    }

    private func mergeContinuousResults(
        _ newResults: [SongRecognitionResult]
    ) {
        for newResult in newResults.reversed() {
            if let index = results.firstIndex(
                where: { $0.id == newResult.id }
            ) {
                results[index] = newResult
            } else {
                results.insert(newResult, at: 0)
            }
        }

        if results.count > Self.maximumStoredResults {
            results.removeLast(
                results.count - Self.maximumStoredResults
            )
        }
    }
}
