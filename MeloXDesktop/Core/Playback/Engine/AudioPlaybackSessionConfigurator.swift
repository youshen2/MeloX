import Foundation

@MainActor
enum AudioPlaybackSessionConfigurator {
    static func activate() throws {
        // macOS manages the output route and the audio device lifetime.
    }
}
