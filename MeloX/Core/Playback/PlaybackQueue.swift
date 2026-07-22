import Foundation

enum RepeatMode: String, CaseIterable, Identifiable {
    case off
    case all
    case one

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .off, .all: "repeat"
        case .one: "repeat.1"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .off: "循环关闭"
        case .all: "列表循环"
        case .one: "单曲循环"
        }
    }
}

struct PlaybackQueue {
    private(set) var songs: [Song] = []
    private(set) var currentIndex = 0
    private(set) var isShuffled = false

    private var shuffledOrder: [Int] = []
    private var shuffledPosition = 0

    var currentSong: Song? {
        guard songs.indices.contains(currentIndex) else { return nil }
        return songs[currentIndex]
    }

    var persistedShuffleOrder: [Int] {
        shuffledOrder
    }

    mutating func restore(
        songs: [Song],
        currentIndex: Int,
        isShuffled: Bool,
        shuffledOrder: [Int]
    ) {
        self.songs = songs
        self.currentIndex = songs.isEmpty
            ? 0
            : min(max(currentIndex, 0), songs.count - 1)
        self.isShuffled = isShuffled

        if isShuffled, isValidShuffleOrder(shuffledOrder) {
            self.shuffledOrder = shuffledOrder
            shuffledPosition = shuffledOrder.firstIndex(of: self.currentIndex) ?? 0
        } else if isShuffled {
            rebuildShuffleOrder()
        } else {
            self.shuffledOrder = []
            shuffledPosition = 0
        }
    }

    mutating func replace(with songs: [Song], startingAt index: Int) {
        self.songs = songs
        currentIndex = songs.isEmpty ? 0 : min(max(index, 0), songs.count - 1)
        if isShuffled {
            rebuildShuffleOrder()
        }
    }

    mutating func select(index: Int) -> Bool {
        guard songs.indices.contains(index) else { return false }
        currentIndex = index
        alignShufflePosition()
        return true
    }

    mutating func move(by offset: Int, wraps: Bool) -> Bool {
        let order = isShuffled ? shuffledOrder : Array(songs.indices)
        guard !order.isEmpty else { return false }
        let position = isShuffled ? shuffledPosition : currentIndex
        var destination = position + offset
        if order.indices.contains(destination) {
            // Continue in the existing order.
        } else if wraps {
            destination = offset > 0 ? 0 : order.count - 1
        } else {
            return false
        }

        if isShuffled {
            shuffledPosition = destination
            currentIndex = order[destination]
        } else {
            currentIndex = destination
        }
        return true
    }

    func canMove(by offset: Int, wraps: Bool) -> Bool {
        let order = isShuffled ? shuffledOrder : Array(songs.indices)
        guard !order.isEmpty else { return false }
        let position = isShuffled ? shuffledPosition : currentIndex
        return order.indices.contains(position + offset) || wraps
    }

    mutating func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            rebuildShuffleOrder()
        } else {
            shuffledOrder = []
            shuffledPosition = 0
        }
    }

    private mutating func rebuildShuffleOrder() {
        guard songs.indices.contains(currentIndex) else {
            shuffledOrder = []
            shuffledPosition = 0
            return
        }
        shuffledOrder = [currentIndex] + songs.indices.filter { $0 != currentIndex }.shuffled()
        shuffledPosition = 0
    }

    private mutating func alignShufflePosition() {
        guard isShuffled else { return }
        if let position = shuffledOrder.firstIndex(of: currentIndex) {
            shuffledPosition = position
        } else {
            rebuildShuffleOrder()
        }
    }

    private func isValidShuffleOrder(_ order: [Int]) -> Bool {
        order.count == songs.count && Set(order) == Set(songs.indices)
    }
}
