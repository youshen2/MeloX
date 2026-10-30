import Foundation

struct PlaylistContentSnapshot: Codable {
    let playlist: Playlist
    let loadedTrackOffset: Int

    static func cacheKey(id: Int) -> String {
        "playlist.v1.\(id)"
    }
}
