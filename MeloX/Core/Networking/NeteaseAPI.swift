import Foundation
import Observation

enum SearchKind: Int, CaseIterable, Identifiable {
    case songs = 1
    case albums = 10
    case artists = 100
    case playlists = 1_000

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .songs: "歌曲"
        case .albums: "专辑"
        case .artists: "歌手"
        case .playlists: "歌单"
        }
    }
}

enum APIError: LocalizedError {
    case requestEncoding
    case invalidResponse
    case emptyResponse(statusCode: Int)
    case server(statusCode: Int, message: String)
    case noPlayableSource
    case trialSourceOnly
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .requestEncoding:
            "无法生成网易云音乐请求。"
        case .invalidResponse:
            "音乐服务返回了无法识别的数据。"
        case .emptyResponse(let statusCode):
            "音乐服务返回了空响应（\(statusCode)）。"
        case .server(let statusCode, let message):
            "请求失败（\(statusCode)）：\(message)"
        case .noPlayableSource:
            "当前歌曲没有可用的播放地址。"
        case .trialSourceOnly:
            "当前歌曲仅提供试听片段，已跳过播放。"
        case .notLoggedIn:
            "请先登录网易云音乐。"
        }
    }
}

@MainActor
@Observable
final class NeteaseAPI {
    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private let client: NeteaseDirectClient

    init(settings: AppSettings, session: URLSession = .shared) {
        self.settings = settings
        client = NeteaseDirectClient(settings: settings, session: session)
    }

    func recommendedPlaylists(limit: Int = 10) async throws -> [Playlist] {
        let response: PersonalizedResponse = try await client.eapi(
            "/api/personalized/playlist",
            data: ["limit": limit, "total": true, "n": 1_000]
        )
        return response.result
    }

    func newAlbums(limit: Int = 10, area: String? = nil) async throws -> [Album] {
        let response: NewAlbumsResponse = try await client.eapi(
            "/api/album/new",
            data: ["limit": limit, "offset": 0, "total": true, "area": area ?? settings.musicArea]
        )
        return response.albums
    }

    func toplists() async throws -> [Playlist] {
        let response: ToplistsResponse = try await client.eapi("/api/toplist")
        return response.list
    }

    func topArtists() async throws -> [Artist] {
        let response: ArtistToplistResponse = try await client.eapi("/api/toplist/artist")
        return response.list.artists
    }

    func playlists(category: String, offset: Int = 0, limit: Int = 50) async throws -> [Playlist] {
        switch category {
        case "推荐歌单":
            return try await recommendedPlaylists(limit: limit)
        case "排行榜":
            return try await toplists()
        case "精品歌单":
            let response: TopPlaylistsResponse = try await client.eapi(
                "/api/playlist/highquality/list",
                data: ["cat": "全部", "limit": limit, "lasttime": 0, "total": true]
            )
            return response.playlists
        default:
            let response: TopPlaylistsResponse = try await client.eapi(
                "/api/playlist/list",
                data: ["cat": category, "order": "hot", "offset": offset, "limit": limit, "total": true]
            )
            return response.playlists
        }
    }

    func playlist(id: Int) async throws -> Playlist {
        let response: PlaylistDetailResponse = try await client.eapi(
            "/api/v6/playlist/detail",
            data: ["id": id, "n": 100_000, "s": 8]
        )
        var playlist = response.playlist
        guard !playlist.trackIDs.isEmpty, playlist.tracks.count < playlist.trackIDs.count else {
            return playlist
        }

        var detailsByID = Dictionary(uniqueKeysWithValues: playlist.tracks.map { ($0.id, $0) })
        let missingIDs = playlist.trackIDs.map(\.id).filter { detailsByID[$0] == nil }
        for chunk in missingIDs.chunked(maxSize: 100) {
            let songs = try await songDetails(ids: chunk)
            for song in songs {
                detailsByID[song.id] = song
            }
        }
        playlist.tracks = playlist.trackIDs.compactMap { detailsByID[$0.id] }
        return playlist
    }

    func album(id: Int) async throws -> (Album, [Song]) {
        let response: AlbumDetailResponse = try await client.eapi("/api/v1/album/\(id)")
        return (response.album, response.songs)
    }

    func artist(id: Int) async throws -> (Artist, [Song], [Album]) {
        let detail: ArtistDetailResponse = try await client.eapi("/api/v1/artist/\(id)")
        let albums: ArtistAlbumsResponse = try await client.eapi(
            "/api/artist/albums/\(id)",
            data: ["limit": 100, "offset": 0, "total": true]
        )
        return (detail.artist, detail.hotSongs, albums.hotAlbums)
    }

    func songDetails(ids: [Int]) async throws -> [Song] {
        guard !ids.isEmpty else { return [] }
        let songs = ids.map { ["id": $0] }
        let songsData = try JSONSerialization.data(withJSONObject: songs)
        guard let songsJSON = String(data: songsData, encoding: .utf8) else {
            throw APIError.requestEncoding
        }
        let response: SongDetailResponse = try await client.eapi(
            "/api/v3/song/detail",
            data: ["c": songsJSON]
        )
        return response.songs
    }

    func playbackSource(id: Int) async throws -> PlaybackSource {
        do {
            let response: SongURLResponse = try await client.eapi(
                "/api/song/enhance/player/url",
                data: ["ids": "[\"\(id)\"]", "br": Int(settings.quality.bitrate) ?? 320_000]
            )
            guard let source = response.data.first(where: { $0.id == id }) else {
                throw APIError.noPlayableSource
            }
            guard source.freeTrialInfo == nil else {
                throw APIError.trialSourceOnly
            }
            guard let string = source.url,
                  let url = securePlaybackURL(from: string) else {
                throw APIError.noPlayableSource
            }
            return PlaybackSource(url: url, bitrate: source.bitrate, format: source.format)
        } catch {
            // YesPlayMusic 在未登录时使用网易云官方外链。iOS 先尝试上面的
            // HTTPS 化原始音源，仅在失败时保留这个官方兜底，避免静默卡在 00:00。
            guard settings.cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let url = URL(string: "https://music.163.com/song/media/outer/url?id=\(id)") else {
                throw error
            }
            return PlaybackSource(url: url, bitrate: nil, format: "mp3")
        }
    }

    func songURL(id: Int) async throws -> URL {
        try await playbackSource(id: id).url
    }

    func search(_ keywords: String, kind: SearchKind, limit: Int = 30) async throws -> SearchPayload {
        let response: SearchResponse = try await client.eapi(
            "/api/search/get",
            data: ["s": keywords, "type": kind.rawValue, "limit": limit, "offset": 0]
        )
        return response.result ?? SearchPayload(songs: nil, albums: nil, artists: nil, playlists: nil)
    }

    func dailySongs() async throws -> [Song] {
        let response: DailySongsResponse = try await client.eapi("/api/v3/discovery/recommend/songs")
        return response.data.dailySongs
    }

    func lyrics(id: Int) async throws -> [LyricLine] {
        do {
            let response: LyricResponse = try await client.eapi(
                "/api/song/lyric/v1",
                data: [
                    "id": id,
                    "cp": false,
                    "tv": 0,
                    "lv": 0,
                    "rv": 0,
                    "kv": 0,
                    "yv": 0,
                    "ytv": 0,
                    "yrv": 0,
                ]
            )
            return LyricParser.parse(
                yrc: response.yrc?.lyric ?? "",
                lrc: response.lrc?.lyric ?? "",
                translatedYRC: response.ytlrc?.lyric ?? "",
                translatedLRC: response.tlyric?.lyric ?? ""
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Keep line-synced lyrics available when the newer YRC route is
            // temporarily unavailable for a region or catalog item.
            let response: LyricResponse = try await client.eapi(
                "/api/song/lyric",
                data: ["id": id, "tv": -1, "lv": -1, "rv": -1, "kv": -1, "_nmclfl": 1]
            )
            return LyricParser.parse(
                yrc: "",
                lrc: response.lrc?.lyric ?? "",
                translatedLRC: response.tlyric?.lyric ?? ""
            )
        }
    }

    func accountProfile() async throws -> AccountProfile {
        do {
            let response: AccountResponse = try await client.eapi(
                "/api/w/nuser/account/get",
                authenticated: true
            )
            guard response.code == 200, let profile = response.profile else {
                throw APIError.notLoggedIn
            }
            return profile
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // 兼容旧账号接口；部分账号在 login_status 的 eapi 传输下
            // 只返回空 profile，仍应继续尝试原账号接口。
            let response: AccountResponse = try await client.eapi(
                "/api/nuser/account/get",
                authenticated: true
            )
            guard response.code == 200, let profile = response.profile else {
                throw APIError.notLoggedIn
            }
            return profile
        }
    }

    func likedSongs(userID: Int, likedPlaylistID: Int? = nil) async throws -> [Song] {
        if let likedPlaylistID {
            do {
                let likedPlaylist = try await playlist(id: likedPlaylistID)
                if !likedPlaylist.tracks.isEmpty || likedPlaylist.trackCount == 0 {
                    return likedPlaylist.tracks
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // 喜欢歌单详情不可用时，再回退到喜欢歌曲 ID 接口。
            }
        }

        // `likelist` does not opt into weapi in the reference module. With
        // encryption enabled it therefore uses eapi.
        let response: LikedSongsResponse = try await client.eapi(
            "/api/song/like/get",
            data: ["uid": userID],
            authenticated: true
        )
        try validate(responseCode: response.code)

        var songs: [Song] = []
        for ids in response.ids.chunked(maxSize: 100) {
            songs.append(contentsOf: try await songDetails(ids: ids))
        }
        let positions = Dictionary(
            uniqueKeysWithValues: response.ids.enumerated().map { ($0.element, $0.offset) }
        )
        return songs.sorted {
            positions[$0.id, default: .max] < positions[$1.id, default: .max]
        }
    }

    func userPlaylists(userID: Int, limit: Int = 2_000) async throws -> [Playlist] {
        // YesPlayMusic intentionally asks for at most 2,000 playlists in one
        // request. Paging this route caused later empty responses to discard an
        // otherwise valid first page.
        // The reference module selects weapi for this route. NetEase returns
        // HTTP 200 with an empty body to CFNetwork weapi requests, while the
        // same original route over its supported eapi transport returns JSON.
        let response: UserPlaylistsResponse = try await client.eapi(
            "/api/user/playlist",
            data: [
                "uid": userID,
                "limit": limit,
                "offset": 0,
                "includeVideo": true,
            ],
            authenticated: true
        )
        try validate(responseCode: response.code)
        return response.playlist
    }

    func recentSongs(userID: Int) async throws -> [Song] {
        // The reference library defaults to the weekly play history. This is a
        // different authenticated route from `/play-record/song/list`.
        let response: PlayHistoryResponse = try await client.eapi(
            "/api/v1/play/record",
            data: ["uid": userID, "type": 1],
            authenticated: true
        )
        try validate(responseCode: response.code)
        return response.weekData?.map(\.song) ?? []
    }

    func setSongLiked(id: Int, isLiked: Bool) async throws {
        let response: APIStatusResponse = try await client.eapi(
            "/api/radio/like",
            data: [
                "alg": "itembased",
                "trackId": id,
                "like": isLiked,
                "time": "3",
            ],
            authenticated: true
        )
        try validate(responseCode: response.code, message: response.message)
    }

    func setPlaylistSubscribed(id: Int, isSubscribed: Bool) async throws {
        var data: [String: Any] = ["id": id]
        if isSubscribed {
            data["checkToken"] = NeteaseDirectClient.checkToken
        }
        let path = isSubscribed ? "/api/playlist/subscribe" : "/api/playlist/unsubscribe"
        let response: APIStatusResponse = try await client.eapi(
            path,
            data: data,
            requiresCheckToken: true,
            authenticated: true
        )
        try validate(responseCode: response.code, message: response.message)
    }

    private func validate(responseCode: Int, message: String? = nil) throws {
        guard (200..<300).contains(responseCode) else {
            throw APIError.server(
                statusCode: responseCode,
                message: message ?? "网易云音乐未完成操作。"
            )
        }
    }

    private func securePlaybackURL(from source: String) -> URL? {
        guard var components = URLComponents(string: source) else { return nil }
        if components.scheme?.lowercased() == "http" {
            components.scheme = "https"
        }
        return components.url
    }
}

private extension Array {
    func chunked(maxSize: Int) -> [[Element]] {
        guard maxSize > 0 else { return [] }
        return stride(from: 0, to: count, by: maxSize).map { start in
            Array(self[start..<Swift.min(start + maxSize, count)])
        }
    }
}
