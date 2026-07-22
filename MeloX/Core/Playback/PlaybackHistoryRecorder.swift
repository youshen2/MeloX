import Foundation
import OSLog

@MainActor
final class PlaybackHistoryRecorder {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MeloX",
        category: "PlaybackHistory"
    )

    private let api: NeteaseAPI
    private let settings: AppSettings
    private let onRecorded: (Song) -> Void
    private var submissionTask: Task<Void, Never>?

    init(
        api: NeteaseAPI,
        settings: AppSettings,
        onRecorded: @escaping (Song) -> Void = { _ in }
    ) {
        self.api = api
        self.settings = settings
        self.onRecorded = onRecorded
    }

    func recordRecentPlayback(song: Song, sourceID: Int?) {
        let resolvedSourceID = sourceID ?? song.album?.id ?? 0
        enqueue(song: song, operation: "recent") { api in
            try await api.recordRecentPlayback(
                songID: song.id,
                sourceID: resolvedSourceID
            )
        } onSuccess: { [onRecorded] in
            onRecorded(song)
        }
    }

    func recordPlaybackDuration(
        song: Song,
        sourceID: Int?,
        playbackTime: TimeInterval,
        completed: Bool
    ) {
        let duration = max(song.durationMS / 1_000, 0)
        let elapsed = playbackTime.isFinite ? max(Int(playbackTime), 0) : 0
        let recordedTime = completed
            ? duration
            : (duration > 0 ? min(elapsed, duration) : elapsed)
        let resolvedSourceID = sourceID ?? song.album?.id ?? 0
        enqueue(song: song, operation: "duration time=\(recordedTime)") { api in
            try await api.recordPlaybackDuration(
                songID: song.id,
                sourceID: resolvedSourceID,
                time: recordedTime
            )
        }
    }

    private func enqueue(
        song: Song,
        operation: String,
        submission: @escaping (NeteaseAPI) async throws -> Void,
        onSuccess: @escaping () -> Void = {}
    ) {
        let accountCookie = normalizedCookie
        guard !accountCookie.isEmpty else {
            debugLog("skipped \(operation): no authenticated account")
            return
        }

        debugLog("queued \(operation) songID=\(song.id)")
        let previousSubmission = submissionTask
        let api = api
        let settings = settings

        submissionTask = Task { @MainActor in
            await previousSubmission?.value
            guard settings.cookie.trimmingCharacters(in: .whitespacesAndNewlines)
                == accountCookie else {
                Self.debugLog("skipped: account changed before submission")
                return
            }
            do {
                try await submission(api)
                onSuccess()
                Self.debugLog("succeeded \(operation) songID=\(song.id)")
            } catch {
                Self.debugLog("failed \(operation): \(error.localizedDescription)")
                Self.logger.error(
                    "Playback reporting failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private var normalizedCookie: String {
        settings.cookie.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func debugLog(_ message: String) {
        Self.debugLog(message)
    }

    private static func debugLog(_ message: String) {
        #if DEBUG
        print("[PlaybackHistory] \(message)")
        #endif
    }
}
