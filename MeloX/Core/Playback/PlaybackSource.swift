import Foundation

struct PlaybackSource: Equatable, Sendable {
    let url: URL
    let bitrate: Int?
    let format: String?
}
