import Foundation

/// A decoded audio timeline reading. A zero rate means media time is not
/// advancing, including pauses, buffering, and completed seeks before resume.
struct AudioPlaybackClockSample: Equatable, Sendable {
    enum Origin: Equatable, Sendable {
        case periodic
        case stateChanged
        case seekCompleted
        case activeItemChanged
    }

    let position: TimeInterval
    let rate: Double
    let sampledAt: Date
    let origin: Origin
}
