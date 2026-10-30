import Foundation
import Observation

enum SearchKind: Int, CaseIterable, Identifiable, Hashable {
    case songs = 1
    case albums = 10
    case artists = 100
    case playlists = 1_000
    case podcasts = 1_009

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .songs: L10n.string("ui.search.kind.songs")
        case .albums: L10n.string("ui.search.kind.albums")
        case .artists: L10n.string("ui.search.kind.artists")
        case .playlists: L10n.string("ui.search.kind.playlists")
        case .podcasts: L10n.string("ui.search.kind.podcasts")
        }
    }
}

enum APIError: LocalizedError {
    case requestEncoding
    case invalidResponse
    case emptyResponse(statusCode: Int)
    case server(statusCode: Int, message: String)
    case noPlayableSource
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .requestEncoding:
            L10n.string("ui.error.api.request_encoding")
        case .invalidResponse:
            L10n.string("ui.error.api.invalid_response")
        case .emptyResponse(let statusCode):
            L10n.format("ui.error.api.empty_response", statusCode)
        case .server(let statusCode, _):
            L10n.format("ui.error.api.server_code", statusCode)
        case .noPlayableSource:
            L10n.string("ui.error.api.no_playable_source")
        case .notLoggedIn:
            L10n.string("ui.error.api.login_required")
        }
    }
}

@MainActor
@Observable
final class NeteaseAPI {
    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    let client: NeteaseDirectClient

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

    func playlist(
        id: Int,
        trackLimit: Int? = 100
    ) async throws -> Playlist {
        let embeddedTrackCount = min(max(trackLimit ?? 100, 0), 100)
        let response: PlaylistDetailResponse = try await client.eapi(
            "/api/v6/playlist/detail",
            data: ["id": id, "n": embeddedTrackCount, "s": 8]
        )
        var playlist = response.playlist
        guard !playlist.trackIDs.isEmpty else {
            if let trackLimit,
               playlist.tracks.count > trackLimit {
                playlist.tracks = Array(
                    playlist.tracks.prefix(max(trackLimit, 0))
                )
            }
            return playlist
        }

        let requestedTrackIDs = if let trackLimit {
            Array(playlist.trackIDs.prefix(max(trackLimit, 0)).map(\.id))
        } else {
            playlist.trackIDs.map(\.id)
        }
        playlist.tracks = try await songDetailsCollection(
            ids: requestedTrackIDs,
            prefetched: playlist.tracks
        )
        return playlist
    }

    func album(id: Int) async throws -> (Album, [Song]) {
        let response: AlbumDetailResponse = try await client.eapi("/api/v1/album/\(id)")
        return (response.album, response.songs)
    }

    func albumSubscriptionStatus(id: Int) async throws -> Bool {
        let response: AlbumDynamicResponse = try await client.weapi(
            "/api/album/detail/dynamic",
            data: ["id": id]
        )
        try validate(responseCode: response.code)
        return response.isSub ?? false
    }

    func setAlbumSubscribed(id: Int, isSubscribed: Bool) async throws {
        let path = isSubscribed ? "/api/album/sub" : "/api/album/unsub"
        let response: APIStatusResponse = try await client.weapi(
            path,
            data: ["id": id]
        )
        try validate(responseCode: response.code, message: response.message)
    }

    func subscribedAlbums(limit: Int = 2_000) async throws -> [Album] {
        let path = "/api/album/sublist"
        let data: [String: Any] = [
            "limit": max(limit, 1),
            "offset": 0,
            "total": true,
        ]
        let response: SubscribedAlbumsResponse
        do {
            // Mirrors @neteaseapireborn/api/module/album_sublist.js.
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            response = try await client.eapi(
                path,
                data: data,
                authenticated: true
            )
        }
        try validate(responseCode: response.code, message: response.message)
        return response.albums
    }

    func artist(id: Int) async throws -> (Artist, [Song], [Album]) {
        let detail: ArtistDetailResponse = try await client.eapi("/api/v1/artist/\(id)")
        let albums: ArtistAlbumsResponse = try await client.eapi(
            "/api/artist/albums/\(id)",
            data: ["limit": 100, "offset": 0, "total": true]
        )
        return (detail.artist, detail.hotSongs, albums.hotAlbums)
    }

    func subscribedArtists(limit: Int = 2_000) async throws -> [Artist] {
        let path = "/api/artist/sublist"
        let data: [String: Any] = [
            "limit": max(limit, 1),
            "offset": 0,
            "total": true,
        ]
        let response: SubscribedArtistsResponse
        do {
            // Mirrors @neteaseapireborn/api/module/artist_sublist.js.
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            response = try await client.eapi(
                path,
                data: data,
                authenticated: true
            )
        }
        try validate(responseCode: response.code, message: response.message)
        return response.artists
    }

    func setArtistFollowed(id: Int, isFollowed: Bool) async throws {
        let path = isFollowed ? "/api/artist/sub" : "/api/artist/unsub"
        let data: [String: Any] = [
            "artistId": id,
            "artistIds": "[\(id)]",
        ]
        let response: APIStatusResponse
        do {
            // Mirrors @neteaseapireborn/api/module/artist_sub.js.
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            response = try await client.eapi(
                path,
                data: data,
                authenticated: true
            )
        }
        try validate(responseCode: response.code, message: response.message)
    }

    func songDetails(ids: [Int]) async throws -> [Song] {
        guard !ids.isEmpty else { return [] }
        let songs = ids.map { ["id": $0] }
        let songsData = try JSONSerialization.data(withJSONObject: songs)
        guard let songsJSON = String(data: songsData, encoding: .utf8) else {
            throw APIError.requestEncoding
        }
        let path = "/api/v3/song/detail"
        let response: SongDetailResponse
        do {
            // Mirrors @neteaseapireborn/api/module/song_detail.js.
            response = try await client.weapi(
                path,
                data: ["c": songsJSON]
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            response = try await client.eapi(
                path,
                data: ["c": songsJSON]
            )
        }
        return response.songs
    }

    func songDetailsCollection(
        ids: [Int],
        prefetched: [Song] = []
    ) async throws -> [Song] {
        guard !ids.isEmpty else { return [] }

        var detailsByID = Dictionary(
            prefetched.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let missingIDs = ids.filter { detailsByID[$0] == nil }

        for start in stride(from: 0, to: missingIDs.count, by: 100) {
            try Task.checkCancellation()
            let end = min(start + 100, missingIDs.count)
            for song in try await songDetails(
                ids: Array(missingIDs[start..<end])
            ) {
                detailsByID[song.id] = song
            }
        }

        return ids.compactMap { detailsByID[$0] }
    }

    func audioMatches(
        fingerprint: String,
        duration: Int
    ) async throws -> [AudioMatchCandidate] {
        guard !fingerprint.isEmpty,
              (1...15).contains(duration),
              let encodedFingerprint = fingerprint.addingPercentEncoding(
                withAllowedCharacters: Self.audioMatchQueryValueAllowed
              ) else {
            throw APIError.requestEncoding
        }

        // Mirrors @neteaseapireborn/api/module/audio_match.js exactly:
        // this is NetEase's original public matcher, not a proxy route.
        var components = URLComponents(
            string: "https://interface.music.163.com/api/music/audio/match"
        )
        components?.percentEncodedQuery = [
            "sessionId=0123456789abcdef",
            "algorithmCode=shazam_v2",
            "duration=\(duration)",
            "rawdata=\(encodedFingerprint)",
            "times=1",
            "decrypt=1",
        ].joined(separator: "&")
        guard let url = components?.url else {
            throw APIError.requestEncoding
        }

        let response: AudioMatchResponse = try await client.get(url)
        try validate(responseCode: response.code)
        return response.data?.result ?? []
    }

    func songDetailsPage(
        ids: [Int],
        offset: Int,
        limit: Int = 100
    ) async throws -> SongCollectionPage {
        let start = min(max(offset, 0), ids.count)
        let end = min(start + min(max(limit, 1), 100), ids.count)
        let pageIDs = Array(ids[start..<end])
        guard !pageIDs.isEmpty else {
            return SongCollectionPage(
                songs: [],
                nextOffset: end,
                totalCount: ids.count
            )
        }

        let details = try await songDetails(ids: pageIDs)
        var detailsByID: [Int: Song] = [:]
        for song in details {
            detailsByID[song.id] = song
        }
        return SongCollectionPage(
            songs: pageIDs.compactMap { detailsByID[$0] },
            nextOffset: end,
            totalCount: ids.count
        )
    }

    func songComments(
        id: Int,
        offset: Int = 0,
        limit: Int = 20,
        beforeTime: Int64 = 0
    ) async throws -> SongCommentsResponse {
        let path = "/api/v1/resource/comments/R_SO_4_\(id)"
        let data: [String: Any] = [
            "rid": id,
            "limit": limit,
            "offset": offset,
            "beforeTime": beforeTime,
        ]
        let response: SongCommentsResponse
        do {
            // @neteaseapireborn/api 对该路由使用 weapi。
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            // CFNetwork 请求部分网易云 weapi 路由时会得到 HTTP 200 空包；
            // 保留完全相同的原始路由和参数，仅切换到其支持的 eapi 传输。
            response = try await client.eapi(path, data: data)
        }
        try validate(responseCode: response.code)
        return response
    }

    func songCommentReplies(
        songID: Int,
        parentCommentID: Int64,
        time: Int64 = -1,
        limit: Int = 20
    ) async throws -> SongCommentFloorResponse {
        let path = "/api/resource/comment/floor/get"
        let data: [String: Any] = [
            "parentCommentId": parentCommentID,
            "threadId": "R_SO_4_\(songID)",
            "time": time,
            "limit": limit,
        ]
        let response: SongCommentFloorResponse
        do {
            // @neteaseapireborn/api/module/comment_floor.js 使用同一路由和 weapi 参数。
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            response = try await client.eapi(path, data: data)
        }
        try validate(responseCode: response.code)
        return response
    }

    func playbackSource(id: Int) async throws -> PlaybackSource {
        try await playbackSource(
            id: id,
            quality: settings.quality,
            availability: .unknown
        )
    }

    func playbackSource(for song: Song) async throws -> PlaybackSource {
        try await playbackSource(
            id: song.id,
            quality: settings.quality,
            availability: song.audioAvailability
        )
    }

    private func playbackSource(
        id: Int,
        quality: MusicQuality,
        availability: SongAudioAvailability
    ) async throws -> PlaybackSource {
        do {
            for candidate in quality.playbackCandidates(
                for: availability
            ) {
                do {
                    return try await requestPlaybackSource(
                        id: id,
                        quality: candidate
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch APIError.noPlayableSource {
                    continue
                }
            }
            throw APIError.noPlayableSource
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // YesPlayMusic 在未登录时使用网易云官方外链。iOS 先尝试上面的
            // HTTPS 化原始音源，仅在失败时保留这个官方兜底，避免静默卡在 00:00。
            guard settings.cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let url = URL(string: "https://music.163.com/song/media/outer/url?id=\(id)") else {
                throw error
            }
            return PlaybackSource(
                url: url,
                bitrate: nil,
                format: "mp3",
                quality: nil
            )
        }
    }

    private func requestPlaybackSource(
        id: Int,
        quality: MusicQuality
    ) async throws -> PlaybackSource {
        // Mirrors @neteaseapireborn/api/module/song_url_v1.js.
        var data: [String: Any] = [
            "ids": "[\(id)]",
            "level": quality.apiLevel,
            "encodeType": "flac",
        ]
        if quality.requiresImmersiveType {
            data["immerseType"] = "c51"
        }
        let response: SongURLResponse = try await client.eapi(
            "/api/song/enhance/player/url/v1",
            data: data
        )
        guard let source = response.data.first(where: { $0.id == id }),
              let string = source.url,
              let url = securePlaybackURL(from: string) else {
            throw APIError.noPlayableSource
        }
        return PlaybackSource(
            url: url,
            bitrate: source.bitrate,
            format: source.format,
            quality: source.level.flatMap(MusicQuality.init(apiLevel:))
        )
    }

    func downloadSource(
        for song: Song,
        quality: MusicQuality
    ) async throws -> PlaybackSource {
        do {
            for candidate in quality.playbackCandidates(
                for: song.audioAvailability
            ) {
                do {
                    return try await requestDownloadSource(
                        id: song.id,
                        quality: candidate
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch APIError.noPlayableSource {
                    continue
                }
            }
            throw APIError.noPlayableSource
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // The dedicated download route can require account privileges.
            // The reference player caches the original player URL as its
            // compatibility path, so preserve that behavior here as well.
            return try await playbackSource(
                id: song.id,
                quality: quality,
                availability: song.audioAvailability
            )
        }
    }

    private func requestDownloadSource(
        id: Int,
        quality: MusicQuality
    ) async throws -> PlaybackSource {
        // Mirrors @neteaseapireborn/api/module/song_download_url_v1.js.
        var data: [String: Any] = [
            "id": id,
            "level": quality.apiLevel,
        ]
        if quality.requiresImmersiveType {
            data["immerseType"] = "c51"
        }
        let response: SongDownloadURLResponse = try await client.eapi(
            "/api/song/enhance/download/url/v1",
            data: data
        )
        guard let source = response.data,
              source.id == id,
              source.freeTrialInfo == nil,
              let string = source.url,
              let url = securePlaybackURL(from: string) else {
            throw APIError.noPlayableSource
        }
        return PlaybackSource(
            url: url,
            bitrate: source.bitrate,
            format: source.format,
            quality: source.level.flatMap(MusicQuality.init(apiLevel:))
        )
    }

    func songURL(id: Int) async throws -> URL {
        try await playbackSource(id: id).url
    }

    func search(_ keywords: String, kind: SearchKind, limit: Int = 30) async throws -> SearchPayload {
        let response: SearchResponse = try await client.eapi(
            "/api/search/get",
            data: ["s": keywords, "type": kind.rawValue, "limit": limit, "offset": 0]
        )
        return response.result ?? SearchPayload(
            songs: nil,
            albums: nil,
            artists: nil,
            playlists: nil,
            podcasts: nil
        )
    }

    func dailySongs(afresh: Bool = false) async throws -> [Song] {
        let path = "/api/v3/discovery/recommend/songs"
        let data: [String: Any] = afresh ? ["afresh": true] : [:]
        let response: DailySongsResponse
        do {
            response = try await client.eapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            response = try await client.weapi(path, data: data)
        }
        return response.data.dailySongs
    }

    func similarSongs(id: Int, limit: Int = 50) async throws -> [Song] {
        let path = "/api/v1/discovery/simiSong"
        let data: [String: Any] = [
            "songid": id,
            "limit": limit,
            "offset": 0,
        ]
        let response: SimilarSongsResponse
        do {
            // Mirrors @neteaseapireborn/api/module/simi_song.js.
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            // NetEase occasionally replies to the web transport with an
            // HTTP 200 and no body. Keep the original route and parameters,
            // changing only the transport for the retry.
            response = try await client.eapi(
                path,
                data: data,
                authenticated: true
            )
        }
        return response.songs
    }

    func lyrics(id: Int) async throws -> [LyricLine] {
        let payload = try await neteaseLyrics(id: id)
        return LyricParser.parse(
            yrc: payload.yrc ?? "",
            lrc: payload.lrc ?? "",
            translatedYRC: payload.translatedYRC ?? "",
            translatedLRC: payload.translatedLRC ?? "",
            romanizedYRC: payload.romanizedYRC ?? "",
            romanizedLRC: payload.romanizedLRC ?? ""
        )
    }

    func neteaseLyrics(id: Int) async throws -> NeteaseLyricPayload {
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
            return NeteaseLyricPayload(
                yrc: response.yrc?.lyric,
                lrc: response.lrc?.lyric,
                translatedYRC: response.ytlrc?.lyric,
                translatedLRC: response.tlyric?.lyric,
                romanizedYRC: response.yromalrc?.lyric,
                romanizedLRC: response.romalrc?.lyric,
                isPureMusic: response.pureMusic == true
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
            return NeteaseLyricPayload(
                yrc: nil,
                lrc: response.lrc?.lyric,
                translatedYRC: nil,
                translatedLRC: response.tlyric?.lyric,
                romanizedYRC: nil,
                romanizedLRC: response.romalrc?.lyric,
                isPureMusic: response.pureMusic == true
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

    func userDetail(userID: Int) async throws -> AccountDetail {
        let response: AccountDetailResponse
        do {
            // Mirrors @neteaseapireborn/api/module/user_detail.js.
            response = try await client.weapi(
                "/api/v1/user/detail/\(userID)"
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            // Mirrors user_detail_new.js when the original weapi transport
            // yields an HTTP 200 empty response through CFNetwork.
            response = try await client.eapi(
                "/api/w/v1/user/detail/\(userID)",
                data: ["all": "true", "userId": userID],
                authenticated: true
            )
        }
        try validate(responseCode: response.code, message: response.message)
        guard let profile = response.profile else {
            throw APIError.invalidResponse
        }
        return AccountDetail(
            profile: profile,
            level: response.level ?? 0,
            listenSongs: response.listenSongs ?? 0,
            createDays: response.createDays
        )
    }

    func likedSongIDs(
        userID: Int,
        likedPlaylistID: Int? = nil
    ) async throws -> [Int] {
        if let likedPlaylistID {
            do {
                // Only request playlist metadata and ordered track IDs here.
                // Song details are fetched page by page by LibraryStore.
                let likedPlaylist = try await playlist(
                    id: likedPlaylistID,
                    trackLimit: 0
                )
                if !likedPlaylist.trackIDs.isEmpty
                    || likedPlaylist.trackCount == 0 {
                    return likedPlaylist.trackIDs.map(\.id)
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
        return response.ids
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

    func recentSongs(limit: Int = 100) async throws -> [Song] {
        let path = "/api/play-record/song/list"
        let data: [String: Any] = ["limit": limit]
        let response: RecentSongsResponse
        do {
            // Mirrors @neteaseapireborn/api/module/record_recent_song.js.
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            // CFNetwork may receive an HTTP 200 empty body from this weapi
            // route. Keep its original route and parameters, changing only
            // to the authenticated eapi transport for compatibility.
            response = try await client.eapi(path, data: data, authenticated: true)
        }
        try validate(responseCode: response.code, message: response.message)
        return response.data?.list.compactMap(\.data) ?? []
    }

    func cloudSongs(limit: Int = 200, offset: Int = 0) async throws -> CloudMusicPage {
        let path = "/api/v1/cloud/get"
        let data: [String: Any] = ["limit": limit, "offset": offset]
        let response: CloudMusicPage
        do {
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            // This authenticated weapi route can return HTTP 200 with an empty
            // body to CFNetwork. Keep the original route and parameters and
            // use its supported eapi transport, matching the other library
            // compatibility fallbacks in this client.
            response = try await client.eapi(path, data: data, authenticated: true)
        }
        try validate(responseCode: response.code)
        return response
    }

    func deleteCloudSong(id: Int) async throws {
        let path = "/api/cloud/del"
        let data: [String: Any] = ["songIds": [id]]
        let response: APIStatusResponse
        do {
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            response = try await client.eapi(path, data: data, authenticated: true)
        }
        try validate(responseCode: response.code, message: response.message)
    }

    func uploadCloudSong(fileAt url: URL) async throws {
        let file = try await CloudUploadFile.prepare(from: url)
        let bitrate = 999_000

        // Mirrors @neteaseapireborn/api/module/cloud.js: the upload check and
        // metadata registration use the default eapi transport.
        let check: CloudUploadCheckResponse = try await client.eapi(
            "/api/cloud/upload/check",
            data: [
                "bitrate": String(bitrate),
                "ext": "",
                "length": file.size,
                "md5": file.md5,
                "songId": "0",
                "version": 1,
            ],
            authenticated: true
        )
        try validate(responseCode: check.code, message: check.message)

        let metadataToken: CloudNOSTokenResponse = try await client.eapi(
            "/api/nos/token/alloc",
            data: [
                "bucket": "",
                "ext": file.fileExtension,
                "filename": file.normalizedStem,
                "local": false,
                "nos_product": 3,
                "type": "audio",
                "md5": file.md5,
            ],
            authenticated: true
        )
        try validate(responseCode: metadataToken.code, message: metadataToken.message)

        if check.needUpload {
            let bucket = "jd-musicrep-privatecloud-audio-public"
            // songUpload.js deliberately obtains a separate weapi token for
            // the NOS transfer while retaining the eapi resourceId above.
            let tokenPath = "/api/nos/token/alloc"
            let tokenData: [String: Any] = [
                "bucket": bucket,
                "ext": file.fileExtension,
                "filename": file.normalizedStem,
                "local": false,
                "nos_product": 3,
                "type": "audio",
                "md5": file.md5,
            ]
            let uploadToken: CloudNOSTokenResponse
            do {
                uploadToken = try await client.weapi(tokenPath, data: tokenData)
            } catch is CancellationError {
                throw CancellationError()
            } catch APIError.emptyResponse {
                uploadToken = try await client.eapi(
                    tokenPath,
                    data: tokenData,
                    authenticated: true
                )
            }
            try validate(responseCode: uploadToken.code, message: uploadToken.message)
            try await client.uploadToNOS(
                fileURL: file.url,
                bucket: bucket,
                objectKey: uploadToken.result.objectKey,
                token: uploadToken.result.token,
                md5: file.md5,
                fileSize: file.size
            )
        }

        let uploadInfo: CloudUploadInfoResponse = try await client.eapi(
            "/api/upload/cloud/info/v2",
            data: [
                "md5": file.md5,
                "songid": check.songID,
                "filename": file.filename,
                "song": file.songName,
                "album": file.album,
                "artist": file.artist,
                "bitrate": String(bitrate),
                "resourceId": metadataToken.result.resourceID,
            ],
            authenticated: true
        )
        try validate(responseCode: uploadInfo.code, message: uploadInfo.message)

        let publish: APIStatusResponse = try await client.eapi(
            "/api/cloud/pub/v2",
            data: ["songid": uploadInfo.songID],
            authenticated: true
        )
        try validate(responseCode: publish.code, message: publish.message)
    }

    func recordRecentPlayback(songID: Int, sourceID: Int) async throws {
        try await submitPlaybackLog(
            action: "startplay",
            fields: [
                "id": String(songID),
                "type": "song",
                "mainsite": "1",
                "mainsiteWeb": "1",
                "content": "id=\(sourceID)",
            ]
        )
    }

    func recordPlaybackDuration(songID: Int, sourceID: Int, time: Int) async throws {
        try await submitPlaybackLog(
            action: "play",
            fields: [
                "download": 0,
                "end": "playend",
                "id": String(songID),
                "sourceId": String(sourceID),
                "time": String(max(time, 0)),
                "type": "song",
                "wifi": 0,
                "source": "list",
                "mainsite": "1",
                "mainsiteWeb": "1",
                "content": "id=\(sourceID)",
            ]
        )
    }

    private func submitPlaybackLog(
        action: String,
        fields: [String: Any]
    ) async throws {
        let logs: [[String: Any]] = [["action": action, "json": fields]]
        let logsData = try JSONSerialization.data(withJSONObject: logs)
        guard let logsJSON = String(data: logsData, encoding: .utf8) else {
            throw APIError.requestEncoding
        }
        // The current upstream implementation posts both `startplay` and
        // `play` events to the original client-log endpoint using eapi and an
        // OSX client cookie. `startplay` feeds /api/play-record/song/list;
        // `play` carries the elapsed listening time.
        let response: APIStatusResponse = try await client.eapi(
            "/api/feedback/weblog",
            data: ["logs": logsJSON],
            authenticated: true,
            domain: "https://clientlog.music.163.com",
            cookieOS: "osx"
        )
        try validate(responseCode: response.code, message: response.message)
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

    func addSong(id: Int, toPlaylistID playlistID: Int) async throws {
        try await manipulatePlaylistTrack(id: id, playlistID: playlistID, operation: "add")
    }

    func validate(responseCode: Int, message: String? = nil) throws {
        guard (200..<300).contains(responseCode) else {
            throw APIError.server(
                statusCode: responseCode,
                message: message ?? L10n.string("ui.error.api.operation_incomplete")
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

    private static let audioMatchQueryValueAllowed: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.!~*'()")
        return allowed
    }()
}
