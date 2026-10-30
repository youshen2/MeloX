"""Run the real song-loading methods with a synchronous outgoing-clock callback.

Uses only Python and the Swift command-line tools; no Xcode, network or account.
"""

from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


def method(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


STUBS = r"""
struct Song { let id = 2; let durationMS = 300_000 }
struct PlaybackSource { let quality = 1 }
struct PlaybackIssue { init(song: Song, error: Error) {} }
struct Queue { let currentSong: Song? = Song() }
struct Downloads {
    func localPlaybackSource(songID: Int) -> PlaybackSource? { nil }
}
@MainActor final class API {
    var beforeResolution: (() -> Void)?
    func playbackSource(id: Int) async throws -> PlaybackSource {
        beforeResolution?()
        return PlaybackSource()
    }
    func playbackSource(for song: Song) async throws -> PlaybackSource {
        try await playbackSource(id: song.id)
    }
}
@MainActor final class Engine {
    var onOutgoingClock: (() -> Void)?
    var loadedPosition: Double?
    var loadedAutoplay: Bool?
    func unload() {
        // The real engine pauses the outgoing deck before clearing it. A
        // playing -> paused transition publishes its final playback sample.
        onOutgoingClock?()
    }
    func load(_ source: PlaybackSource, startAt: Double, autoplay: Bool) async {
        loadedPosition = startAt
        loadedAutoplay = autoplay
    }
}
@MainActor final class Store {
    var playbackQueue = Queue()
    var loadGeneration = 0
    var currentSong: Song?
    var detailedPlaybackSongs: [Int: Song] = [:]
    var duration: Double = 300
    var progress: Double = 73
    var playbackTimelineClock = PlaybackTimelineClock()
    var isResolvingSource = false
    var isLoading = false
    var isPlaying = true
    var isUsingDownloadedSource = false
    var currentPlaybackSource: PlaybackSource?
    var effectivePlaybackQuality: Int?
    var currentLoadShouldAutoplay = false
    var playbackIssue: PlaybackIssue?
    var nowPlayingLyricsSongID: Int?
    var nowPlayingLyrics: [Int] = []
    var publishedNowPlayingLyricID: Int?
    var currentIndex = 1
    var queue = [Song(), Song()]
    var nowPlayingLyricsDisplaySettings = 0
    let engine = Engine()
    let api = API()
    let downloads = Downloads()
    let nowPlayingSession = Session()
    func cancelAutoMixPreparation() {}
    func resolveCurrentSongAudioAvailability(for song: Song, generation: Int) {}
    func resetBeatAnalysis() {}
    func updateNowPlayingState() {}
    func persistSnapshot() {}
    struct Session {
        func setSong(_ song: Song, duration: Double, queueIndex: Int,
                     queueCount: Int, lyricsDisplaySettings: Int) {}
    }
    func run(startAt: Double, autoplay: Bool) async {
        await loadCurrentSong(autoplay: autoplay, startAt: startAt)
    }
    func seekWhileResolving(to position: Double) {
        progress = position
        reanchorPlaybackTimeline(to: position, rate: 0)
    }
    // SOURCE_METHODS
}

@main struct Regression {
    @MainActor static func main() async {
        var failures = 0
        for playing in [true, false] {
            for start in [0.0, 42.0] {
                for seekDuringResolution in [false, true] {
                    for autoplay in [true, false] {
                        let store = Store()
                        if playing {
                            store.engine.onOutgoingClock = {
                                store.seekWhileResolving(to: 73)
                            }
                        }
                        if seekDuringResolution {
                            store.api.beforeResolution = {
                                store.seekWhileResolving(to: 15)
                            }
                        }
                        await store.run(startAt: start, autoplay: autoplay)
                        let expected = seekDuringResolution ? 15.0 : start
                        if store.engine.loadedPosition != expected ||
                           store.engine.loadedAutoplay != autoplay {
                            print("FAIL playing=\(playing) startAt=\(start) seek=\(seekDuringResolution) autoplay=\(autoplay): expected \(expected), got \(store.engine.loadedPosition ?? -1)")
                            failures += 1
                        }
                    }
                }
            }
        }
        if failures > 0 { exit(1) }
        print("PASS: 16 song replacement / resume / pending seek scenarios")
    }
}
"""


class SongSwitchTests(unittest.TestCase):
    def test_outgoing_progress_cannot_override_new_song_position(self):
        for app in ("MeloXDesktop", "MeloX"):
            with self.subTest(app=app), tempfile.TemporaryDirectory() as directory:
                session = ROOT / app / "Core/Playback/Session"
                source = (session / "PlayerStore.swift").read_text()
                signatures = (
                    "private func loadCurrentSong(",
                    "func estimatedProgress(",
                    "private var playbackDurationLimit:",
                    "private func clampedPlaybackPosition(",
                    "private func reanchorPlaybackTimeline(",
                )
                methods = "\n".join(method(source, sig) for sig in signatures)
                swift = Path(directory) / "main.swift"
                swift.write_text(
                    (session / "PlaybackTimelineClock.swift").read_text()
                    + STUBS.replace("// SOURCE_METHODS", methods)
                )
                executable = Path(directory) / "regression"
                compile_result = subprocess.run(
                    ["swiftc", "-parse-as-library", str(swift), "-o", str(executable)],
                    capture_output=True, text=True,
                )
                self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
                result = subprocess.run([str(executable)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                print(f"{app}: {result.stdout.strip()}")


if __name__ == "__main__":
    unittest.main()
