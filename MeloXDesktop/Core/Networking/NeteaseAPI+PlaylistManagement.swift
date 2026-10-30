import Foundation

extension NeteaseAPI {
    func removeSong(id: Int, fromPlaylistID playlistID: Int) async throws {
        try await manipulatePlaylistTrack(id: id, playlistID: playlistID, operation: "del")
    }

    func manipulatePlaylistTrack(id: Int, playlistID: Int, operation: String) async throws {
        // The original route and parameters follow playlist_tracks.js;
        // use the authenticated versioned EAPI route, as for adding tracks.
        let path = "/api/v1/playlist/manipulate/tracks"
        let trackID = String(id)
        var response: APIStatusResponse = try await client.eapi(
            path,
            data: ["op": operation, "pid": playlistID, "trackIds": "[\"\(trackID)\"]", "imme": "true"],
            authenticated: true
        )
        if response.code == 512 {
            response = try await client.eapi(
                path,
                data: ["op": operation, "pid": playlistID, "trackIds": "[\"\(trackID)\",\"\(trackID)\"]", "imme": "true"],
                authenticated: true
            )
        }
        try validate(responseCode: response.code, message: response.message)
    }

    func deletePlaylist(id: Int) async throws {
        // Mirrors @neteaseapireborn/api/module/playlist_delete.js.
        let response: APIStatusResponse = try await client.weapi(
            "/api/playlist/remove",
            data: ["ids": "[\(id)]"]
        )
        try validate(responseCode: response.code, message: response.message)
    }

    func createPlaylist(name: String, isPrivate: Bool) async throws -> Playlist {
        // Mirrors @neteaseapireborn/api/module/playlist_create.js.
        let response: PlaylistCreationResponse = try await client.weapi(
            "/api/playlist/create",
            data: ["name": name, "privacy": isPrivate ? "10" : "0", "type": "NORMAL"]
        )
        try validate(responseCode: response.code, message: response.message)
        guard let playlist = response.playlist, playlist.id > 0 else {
            throw APIError.invalidResponse
        }
        return playlist
    }
}

private struct PlaylistCreationResponse: Decodable {
    let code: Int
    let playlist: Playlist?
    let message: String?
}
