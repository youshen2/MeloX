"""Exercise production playlist and row playback with a paged 300-song source.

The Swift harness uses the real playback handlers and collection resolver with
an in-memory transport/player; no account, network, or audio output is needed.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
# Keep inspectable artifacts outside the checkout; no recursive deletion.
ARTIFACTS = Path(tempfile.gettempdir()) / "melox-tests.noindex"
ARTIFACTS.mkdir(parents=True, exist_ok=True)


def method(path, signature):
    source = (ROOT / path).read_text()
    start = source.index(signature)
    opening = source.index("{", start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


HARNESS = r'''
import Foundation

struct Song: Equatable { let id: Int }
struct TrackID { let id: Int }
struct Playlist { let id: Int; let trackIDs: [TrackID] }
enum Failure: Error { case offline }

@MainActor final class API {
    var batches: [[Int]] = []
    var fails = false
    var onRequest: (() -> Void)?
    func songDetails(ids: [Int]) async throws -> [Song] {
        batches.append(ids)
        onRequest?()
        if fails { throw Failure.offline }
        // The server may return a batch in a different order.
        return ids.reversed().map { Song(id: $0) }
    }
    // COLLECTION
}
@MainActor final class Player {
    var queue: [Song] = []
    var selectedID: Int?
    var sourceID: Int?
    var calls = 0
    func play(_ song: Song, in songs: [Song], sourceID: Int?) async {
        queue = songs; selectedID = song.id; self.sourceID = sourceID; calls += 1
    }
    func playAll(_ songs: [Song], sourceID: Int?) async {
        queue = songs; selectedID = songs.first?.id
        self.sourceID = sourceID; calls += 1
    }
}
@MainActor final class Model { let api = API(); let player = Player() }
@MainActor final class PlaylistView {
    var playlist: Playlist? = Playlist(id: 7, trackIDs: (1...300).map { TrackID(id: $0) })
    var songs = (1...100).map { Song(id: $0) }
    var isPreparingPlayback = false
    var playbackErrorMessage: String?
    let model = Model()
    // PLAYLIST
    func play(_ id: Int) async { await playAll(shuffled: false, startingAt: Song(id: id)) }
    func playAllTracks(shuffled: Bool = false) async { await playAll(shuffled: shuffled) }
}
@MainActor final class Row {
    let model: Model
    let song = Song(id: 80)
    let songs = (1...100).map { Song(id: $0) }
    let sourceID: Int? = 7
    var onPlaySong: ((Song) async -> Void)?
    init(model: Model) { self.model = model }
    // ROW
    func activate() async { await playSong() }
}
@main struct Checks {
    @MainActor static func main() async {
        let view = PlaylistView()
        view.model.api.onRequest = { precondition(view.isPreparingPlayback) }
        let row = Row(model: view.model)
        row.onPlaySong = { song in await view.play(song.id) }
        await row.activate()
        precondition(view.model.player.queue.map(\.id) == Array(1...300))
        precondition(view.model.player.selectedID == 80)
        precondition(view.model.player.sourceID == 7)
        precondition(view.model.api.batches == [Array(101...200), Array(201...300)])
        precondition(!view.isPreparingPlayback)
        print("PASS: row activation resolves all 300 songs, preserving selected song and order")

        await view.playAllTracks()
        precondition(view.model.player.queue.map(\.id) == Array(1...300))
        precondition(view.model.player.selectedID == 1)
        await view.playAllTracks(shuffled: true)
        precondition(Set(view.model.player.queue.map(\.id)) == Set(1...300))
        precondition(view.model.player.queue.count == 300)
        print("PASS: normal and shuffled Play All retain all songs")

        let failed = PlaylistView()
        failed.model.api.fails = true
        await failed.play(80)
        precondition(failed.model.player.calls == 0)
        precondition(failed.playbackErrorMessage != nil)
        precondition(!failed.isPreparingPlayback)
        print("PASS: hydration failure leaves the queue intact and reports the error")

        let changed = PlaylistView()
        changed.model.api.onRequest = { changed.playlist = Playlist(id: 9, trackIDs: []) }
        await changed.play(80)
        precondition(changed.model.player.calls == 0)
        print("PASS: a stale playlist response cannot replace playback")

        let fallback = Row(model: Model())
        await fallback.activate()
        precondition(fallback.model.player.queue.count == 100)
        precondition(fallback.model.player.selectedID == 80)
        print("PASS: other row contexts preserve their existing playback behavior")
    }
}
'''


class PlaylistQueueTests(unittest.TestCase):
    def test_complete_playlist_queue(self):
        source = HARNESS.replace("// COLLECTION", method(
            "MeloXDesktop/Core/Networking/NeteaseAPI.swift", "    func songDetailsCollection("))
        source = source.replace("// PLAYLIST", method(
            "MeloXDesktop/Features/Detail/DesktopPlaylistDetailView.swift", "    private func playAll("))
        source = source.replace("// ROW", method(
            "MeloXDesktop/Shared/DesktopTrackRow.swift", "    private func playSong("))
        # Keep artifacts for inspection; never recursively remove directories.
        path = Path(tempfile.mkdtemp(prefix="melox-queue-checks-", dir=ARTIFACTS))
        (path / "Checks.swift").write_text(source)
        subprocess.run(["swiftc", "-parse-as-library", str(path / "Checks.swift"),
                        "-o", str(path / "checks")], check=True)
        subprocess.run([str(path / "checks")], check=True)


if __name__ == "__main__":
    unittest.main()
