import Foundation

/// A monotonic presentation clock that freezes at its current phase while the
/// player is hidden. Restarting the renderer must not snap the three Music
/// backdrop transforms back to their zero-angle state.
struct DesktopAppleMusicBackdropClock: Equatable {
    private(set) var elapsed: TimeInterval = 0
    private(set) var resumedAt: Date?

    mutating func setRunning(_ isRunning: Bool, at date: Date) {
        if isRunning {
            if resumedAt == nil {
                resumedAt = date
            }
            return
        }

        if let resumedAt {
            elapsed += max(date.timeIntervalSince(resumedAt), 0)
            self.resumedAt = nil
        }
    }

    func elapsed(at date: Date) -> TimeInterval {
        guard let resumedAt else { return elapsed }
        return elapsed + max(date.timeIntervalSince(resumedAt), 0)
    }
}
