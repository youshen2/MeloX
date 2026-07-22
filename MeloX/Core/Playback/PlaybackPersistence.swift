import Foundation

struct PlaybackSnapshot: Codable {
    let queue: [Song]
    let currentIndex: Int
    let progress: TimeInterval
    let repeatMode: String
    let isShuffled: Bool
    let shuffledOrder: [Int]
    let volume: Double
    let historySourceID: Int?
}

@MainActor
final class PlaybackPersistence {
    private enum Key {
        static let snapshot = "player.playbackSnapshot"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PlaybackSnapshot? {
        guard let data = defaults.data(forKey: Key.snapshot) else { return nil }
        return try? JSONDecoder().decode(PlaybackSnapshot.self, from: data)
    }

    func save(_ snapshot: PlaybackSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.snapshot)
    }

    func clear() {
        defaults.removeObject(forKey: Key.snapshot)
    }
}
