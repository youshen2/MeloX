import ActivityKit
import Foundation

nonisolated enum LyricsLiveActivityCompactTextSize:
    String,
    Codable,
    Hashable,
    CaseIterable,
    Identifiable,
    Sendable {
    case small
    case standard
    case large

    var id: Self { self }

    var pointSize: Double {
        switch self {
        case .small: 10
        case .standard: 12
        case .large: 14
        }
    }
}

nonisolated struct LyricsLiveActivityPresentation: Codable, Hashable, Sendable {
    let showsArtwork: Bool
    let showsNextLyric: Bool
    let showsProgress: Bool
    let scrollsCompactText: Bool
    let compactTextSize: LyricsLiveActivityCompactTextSize
    let scrollSpeed: Double
    let scrollPause: TimeInterval
}

nonisolated struct LyricsLiveActivityAttributes: ActivityAttributes, Sendable {
    static let currentSchemaVersion = 2

    nonisolated struct ContentState: Codable, Hashable, Sendable {
        let title: String
        let subtitle: String
        let compactText: String
        let compactScrollOffset: Int
        let compactScrollDistance: Double?
        let nextLyric: String?
        let artworkData: Data?
        let presentation: LyricsLiveActivityPresentation
        let isPlaying: Bool
        let playbackPosition: TimeInterval
        let duration: TimeInterval
        let updatedAt: Date

        var progress: Double {
            guard duration > 0 else { return 0 }
            return min(max(playbackPosition / duration, 0), 1)
        }

        var playbackInterval: ClosedRange<Date>? {
            guard isPlaying, duration > 0 else { return nil }
            let start = updatedAt.addingTimeInterval(-playbackPosition)
            return start...start.addingTimeInterval(duration)
        }
    }

    let sessionID: UUID
    let schemaVersion: Int?
}
