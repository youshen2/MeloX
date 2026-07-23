import Foundation

struct PersonalizedResponse: Decodable {
    let result: [Playlist]
}

struct NewAlbumsResponse: Decodable {
    let albums: [Album]
}

struct ToplistsResponse: Decodable {
    let list: [Playlist]
}

struct TopPlaylistsResponse: Decodable {
    let playlists: [Playlist]
    let more: Bool?
}

struct PlaylistDetailResponse: Decodable {
    let playlist: Playlist
}

struct SongDetailResponse: Decodable {
    let songs: [Song]
}

struct SongURLResponse: Decodable {
    let data: [SongURL]
}

struct SongDownloadURLResponse: Decodable {
    let data: SongURL?
}

struct SongURL: Decodable {
    let id: Int
    let url: String?
    let bitrate: Int?
    let format: String?
    let freeTrialInfo: FreeTrialInfo?

    enum CodingKeys: String, CodingKey {
        case id, url
        case bitrate = "br"
        case format = "type"
        case freeTrialInfo
    }
}

struct FreeTrialInfo: Decodable {
    let start: Int?
    let end: Int?
}

struct AlbumDetailResponse: Decodable {
    let album: Album
    let songs: [Song]
}

struct AlbumDynamicResponse: Decodable {
    let code: Int
    let isSub: Bool?
}

struct ArtistDetailResponse: Decodable {
    let artist: Artist
    let hotSongs: [Song]
}

struct ArtistAlbumsResponse: Decodable {
    let hotAlbums: [Album]
}

struct ArtistToplistResponse: Decodable {
    let list: ArtistToplist
}

struct ArtistToplist: Decodable {
    let artists: [Artist]
}

struct SearchResponse: Decodable {
    let result: SearchPayload?
}

struct SearchPayload: Decodable {
    let songs: [Song]?
    let albums: [Album]?
    let artists: [Artist]?
    let playlists: [Playlist]?
}

struct DailySongsResponse: Decodable {
    let data: DailySongsData
}

struct DailySongsData: Decodable {
    let dailySongs: [Song]
}

struct LyricResponse: Decodable {
    let lrc: LyricContent?
    let yrc: LyricContent?
    let tlyric: LyricContent?
    let ytlrc: LyricContent?
}

struct LyricContent: Decodable {
    let lyric: String?
}

struct AccountResponse: Decodable {
    let code: Int
    let profile: AccountProfile?
}

struct LikedSongsResponse: Decodable {
    let code: Int
    let ids: [Int]
}

struct UserPlaylistsResponse: Decodable {
    let code: Int
    let playlist: [Playlist]
    let more: Bool?
}

struct RecentSongsResponse: Decodable {
    let code: Int
    let data: RecentSongsData?
    let message: String?
}

struct RecentSongsData: Decodable {
    let list: [RecentSongItem]
}

struct RecentSongItem: Decodable {
    let data: Song?
}

struct APIStatusResponse: Decodable {
    let code: Int
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, message
    }
}
