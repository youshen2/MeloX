"""Exercise desktop lyric synchronization without opening any player windows."""

from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]

HARNESS = r"""
import Foundation
import Observation

struct Song {
    let id: Int
    var isPodcastProgram = false
}
struct LyricLine { let text: String }
enum LyricSource { case netease, amll }
enum LyricSourcePreference: String { case automatic, amll }
struct LyricsSongMetadata {
    let id: Int
    init(song: Song) { id = song.id }
}
struct ResolvedLyrics {
    let lines: [LyricLine]
    let source: LyricSource
}
enum L10n {
    static func string(_ key: String) -> String { key }
}

@MainActor @Observable final class AppSettings {
    var lyricsSourcePreference = LyricSourcePreference.automatic
}

@MainActor @Observable final class PlayerStore {
    var currentSong: Song?
    var publishedLyrics: [String] = []
    func setNowPlayingLyrics(_ lyrics: [LyricLine], for songID: Int?) {
        guard let songID, currentSong?.id == songID else { return }
        publishedLyrics = lyrics.map(\.text)
    }
}

@MainActor final class LyricsService {
    let settings: AppSettings
    var requests: [Int] = []
    var completedRequests: [Int] = []
    var pendingLoad: CheckedContinuation<Void, Never>?

    init(settings: AppSettings) { self.settings = settings }

    func load(
        for song: LyricsSongMetadata,
        onUpdate: @MainActor (ResolvedLyrics) -> Void
    ) async throws -> ResolvedLyrics {
        let preference = settings.lyricsSourcePreference
        requests.append(song.id)
        if song.id == 2 {
            // Simulate a request that returns after it has been cancelled.
            await withCheckedContinuation { pendingLoad = $0 }
        }
        let result = ResolvedLyrics(
            lines: [LyricLine(text: "\(song.id):\(preference.rawValue)")],
            source: preference == .amll ? .amll : .netease
        )
        onUpdate(result)
        completedRequests.append(song.id)
        return result
    }
}

@main struct Regression {
    @MainActor static func waitUntil(
        _ message: String,
        _ condition: () -> Bool
    ) async throws {
        for _ in 0..<1_000 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        fatalError(message)
    }

    @MainActor static func main() async throws {
        let player = PlayerStore()
        let settings = AppSettings()
        let service = LyricsService(settings: settings)
        let lyrics = LyricsStore(service: service)
        player.currentSong = Song(id: 1)
        let synchronizer = DesktopLyricsSynchronizer(
            player: player, settings: settings, lyrics: lyrics
        )

        try await waitUntil("Initial song did not load") {
            player.publishedLyrics == ["1:automatic"]
        }

        player.currentSong = Song(id: 2)
        try await waitUntil("Next song did not start loading") {
            service.pendingLoad != nil
        }
        precondition(lyrics.songID == 2 && lyrics.lyrics.isEmpty)

        player.currentSong = Song(id: 3)
        try await waitUntil("Rapid song switch did not publish current lyrics") {
            player.publishedLyrics == ["3:automatic"]
        }
        service.pendingLoad?.resume()
        service.pendingLoad = nil
        try await waitUntil("Delayed request did not finish") {
            service.completedRequests.contains(2)
        }
        precondition(lyrics.songID == 3)
        precondition(lyrics.lyrics.map(\.text) == ["3:automatic"])
        precondition(player.publishedLyrics == ["3:automatic"])

        settings.lyricsSourcePreference = .amll
        try await waitUntil("Changing lyric source did not refresh the song") {
            player.publishedLyrics == ["3:amll"]
        }
        precondition(service.requests == [1, 2, 3, 3])

        player.currentSong = nil
        try await waitUntil("Clearing the current song left stale lyrics") {
            lyrics.songID == nil && lyrics.lyrics.isEmpty
        }
        withExtendedLifetime(synchronizer) {}
        print("PASS: window-independent loading, rapid switching, stale response rejection, source changes, and clearing")
    }
}
"""


class DesktopLyricsSyncTests(unittest.TestCase):
    def test_lyrics_follow_playback_without_a_main_window(self):
        with tempfile.TemporaryDirectory() as directory:
            harness = Path(directory) / "Harness.swift"
            harness.write_text(HARNESS)
            executable = Path(directory) / "regression"
            lyrics = ROOT / "MeloXDesktop/Core/Lyrics"
            result = subprocess.run(
                [
                    "xcrun", "swiftc", "-swift-version", "5",
                    "-O", "-whole-module-optimization",
                    "-default-isolation", "MainActor", "-parse-as-library",
                    str(lyrics / "DesktopLyricsSynchronizer.swift"),
                    str(lyrics / "LyricsStore.swift"), str(harness),
                    "-o", str(executable),
                ],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run(
                [str(executable)], capture_output=True, text=True, timeout=15
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            print(result.stdout.strip())


if __name__ == "__main__":
    unittest.main()
