@preconcurrency import AVFoundation
import Foundation

@MainActor
final class WatchAudioPlaybackEngine: NSObject, AVAudioPlayerDelegate {
    var onEnded: (() -> Void)?
    var onFailure: ((Error) -> Void)?
    private var player: AVAudioPlayer?
    private var playbackFile: URL?
    private var loadID = UUID()
    private var pendingPosition: TimeInterval = 0
    var volume: Float = 1 {
        didSet { player?.volume = volume }
    }
    var hasCurrentItem: Bool { player != nil }
    var isPlaying: Bool { player?.isPlaying == true }
    var currentTime: TimeInterval { player?.currentTime ?? pendingPosition }
    var duration: TimeInterval { player?.duration ?? 0 }

    deinit {
        if let playbackFile { try? FileManager.default.removeItem(at: playbackFile) }
    }

    func load(_ url: URL, startAt: TimeInterval, autoplay: Bool) async throws {
        unload()
        let id = loadID
        pendingPosition = startAt
        let localURL: URL
        if url.isFileURL { localURL = url }
        else {
            let (temporaryURL, response) = try await URLSession.shared.download(from: url)
            guard id == loadID else { throw CancellationError() }
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("melox-playback-\(id.uuidString)")
                .appendingPathExtension(url.pathExtension)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            playbackFile = destination
            localURL = destination
        }
        let player = try AVAudioPlayer(contentsOf: localURL)
        self.player = player
        player.delegate = self
        player.volume = volume
        player.prepareToPlay()
        player.currentTime = min(max(pendingPosition, 0), player.duration)
        if autoplay { player.play() }
    }

    func play() { player?.play() }
    func pause() { player?.pause() }
    func seek(to seconds: TimeInterval) {
        pendingPosition = max(seconds, 0)
        if let player { player.currentTime = min(pendingPosition, player.duration) }
    }
    func unload() {
        loadID = UUID()
        player?.stop()
        player?.delegate = nil
        player = nil
        if let playbackFile { try? FileManager.default.removeItem(at: playbackFile) }
        playbackFile = nil
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === self.player else { return }
        onEnded?()
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard player === self.player, let error else { return }
        onFailure?(error)
    }
}
