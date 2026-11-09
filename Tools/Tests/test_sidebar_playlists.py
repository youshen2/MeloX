"""Exercise the real iPad sidebar playlist selection against saved libraries."""

from pathlib import Path
import subprocess
import sys
import tempfile

from test_playback_song_switch import method


ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "MeloX/App/ContentView.swift"

STUBS = r"""
struct Playlist {
    let id: Int
    var name: String = ""
    var trackCount: Int = 0
}
struct Library {
    var isLoggedIn = true
    var likedPlaylistID: Int?
    var favoriteSongTotalCount = 83
    var favoritePlaylists: [Playlist]
}
struct UIDevice {
    enum Idiom { case pad }
    static let current = Self()
    let userInterfaceIdiom: Idiom = .pad
}
enum L10n {
    static func string(_ key: String) -> String { key }
}
struct ContentView {
    let library: Library
    var sidebarIDs: [Int] { sidebarPlaylists.map(\.id) }
    // SOURCE_PROPERTY
}

let empty = ContentView(library: Library(favoritePlaylists: []))
precondition(empty.sidebarIDs.isEmpty)
let shortList = ContentView(library: Library(
    likedPlaylistID: 1,
    favoritePlaylists: [1, 3, 2, 3].map { Playlist(id: $0) }
))
precondition(shortList.sidebarIDs == [1, 3, 2])

let largeList = ContentView(library: Library(
    likedPlaylistID: 5000,
    favoritePlaylists: ([5000, 1, 1] + Array(2...2000)).map { Playlist(id: $0) }
))
precondition(largeList.sidebarIDs == [5000] + Array(1...40))
precondition(largeList.sidebarIDs == [5000] + Array(1...40))

let signedOut = ContentView(library: Library(
    isLoggedIn: false, likedPlaylistID: 1, favoritePlaylists: [Playlist(id: 2)]
))
precondition(signedOut.sidebarIDs.isEmpty)
print("Sidebar playlist startup regression passed")
"""

with tempfile.TemporaryDirectory() as directory:
    swift = Path(directory) / "main.swift"
    swift.write_text(STUBS.replace(
        "// SOURCE_PROPERTY", method(SOURCE.read_text(), "private var sidebarPlaylists:")
    ))
    subprocess.run(["swift", str(swift)], check=True)
