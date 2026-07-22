import Foundation

private func makeArtworkURL(from source: String?) -> URL? {
    guard var source = source?.trimmingCharacters(in: .whitespacesAndNewlines),
          !source.isEmpty else { return nil }

    if source.hasPrefix("//") {
        source = "https:\(source)"
    } else if !source.contains("://") {
        source = "https://\(source)"
    }
    guard var components = URLComponents(string: source) else { return nil }
    if components.scheme?.lowercased() == "http" {
        components.scheme = "https"
    }
    // 分类歌单的 coverImgUrl 常带有多段 imageView / watermark 查询参数，
    // 再追加 param 会让网易云图片服务拒绝处理。路径本身就是原始封面，
    // 统一移除服务端返回的处理链后请求固定尺寸即可。
    components.query = nil
    components.queryItems = [URLQueryItem(name: "param", value: "1024y1024")]
    return components.url
}

struct Artist: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let picURL: String?
    let avatarURL: String?
    let aliases: [String]

    var artworkURL: URL? {
        makeArtworkURL(from: picURL ?? avatarURL)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, alias, picUrl, img1v1Url
    }

    init(
        id: Int,
        name: String,
        picURL: String? = nil,
        avatarURL: String? = nil,
        aliases: [String] = []
    ) {
        self.id = id
        self.name = name
        self.picURL = picURL
        self.avatarURL = avatarURL
        self.aliases = aliases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未知歌手"
        picURL = try container.decodeIfPresent(String.self, forKey: .picUrl)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .img1v1Url)
        aliases = try container.decodeIfPresent([String].self, forKey: .alias) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(picURL, forKey: .picUrl)
        try container.encodeIfPresent(avatarURL, forKey: .img1v1Url)
        try container.encode(aliases, forKey: .alias)
    }
}

struct Album: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let picURL: String?
    let artists: [Artist]
    let publishTime: Double?
    let size: Int?
    let type: String?
    let albumDescription: String?

    var artworkURL: URL? {
        makeArtworkURL(from: picURL)
    }

    var artistText: String {
        artists.map(\.name).joined(separator: " / ")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, picUrl, artists, artist, publishTime, size, type, description
    }

    init(
        id: Int,
        name: String,
        picURL: String? = nil,
        artists: [Artist] = [],
        publishTime: Double? = nil,
        size: Int? = nil,
        type: String? = nil,
        albumDescription: String? = nil
    ) {
        self.id = id
        self.name = name
        self.picURL = picURL
        self.artists = artists
        self.publishTime = publishTime
        self.size = size
        self.type = type
        self.albumDescription = albumDescription
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未知专辑"
        picURL = try container.decodeIfPresent(String.self, forKey: .picUrl)
        if let decodedArtists = try container.decodeIfPresent([Artist].self, forKey: .artists) {
            artists = decodedArtists
        } else if let artist = try container.decodeIfPresent(Artist.self, forKey: .artist) {
            artists = [artist]
        } else {
            artists = []
        }
        publishTime = try container.decodeIfPresent(Double.self, forKey: .publishTime)
        size = try container.decodeIfPresent(Int.self, forKey: .size)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        albumDescription = try container.decodeIfPresent(String.self, forKey: .description)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(picURL, forKey: .picUrl)
        try container.encode(artists, forKey: .artists)
        try container.encodeIfPresent(publishTime, forKey: .publishTime)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(albumDescription, forKey: .description)
    }
}

struct Song: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let artists: [Artist]
    let album: Album?
    let durationMS: Int
    let trackNumber: Int?
    let disc: String?
    let fee: Int?

    var artistText: String {
        artists.map(\.name).joined(separator: " / ")
    }

    var durationText: String {
        let totalSeconds = durationMS / 1_000
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, ar, artists, al, album, dt, duration, no, cd, fee
    }

    init(
        id: Int,
        name: String,
        artists: [Artist],
        album: Album? = nil,
        durationMS: Int = 0,
        trackNumber: Int? = nil,
        disc: String? = nil,
        fee: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.artists = artists
        self.album = album
        self.durationMS = durationMS
        self.trackNumber = trackNumber
        self.disc = disc
        self.fee = fee
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未知歌曲"
        artists = try container.decodeIfPresent([Artist].self, forKey: .ar)
            ?? container.decodeIfPresent([Artist].self, forKey: .artists)
            ?? []
        album = try container.decodeIfPresent(Album.self, forKey: .al)
            ?? container.decodeIfPresent(Album.self, forKey: .album)
        durationMS = try container.decodeIfPresent(Int.self, forKey: .dt)
            ?? container.decodeIfPresent(Int.self, forKey: .duration)
            ?? 0
        trackNumber = try container.decodeIfPresent(Int.self, forKey: .no)
        disc = try container.decodeIfPresent(String.self, forKey: .cd)
        fee = try container.decodeIfPresent(Int.self, forKey: .fee)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(artists, forKey: .ar)
        try container.encodeIfPresent(album, forKey: .al)
        try container.encode(durationMS, forKey: .dt)
        try container.encodeIfPresent(trackNumber, forKey: .no)
        try container.encodeIfPresent(disc, forKey: .cd)
        try container.encodeIfPresent(fee, forKey: .fee)
    }
}

struct UserSummary: Codable, Hashable {
    let userID: Int
    let nickname: String

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case nickname
    }

    init(userID: Int = 0, nickname: String = "网易云音乐") {
        self.userID = userID
        self.nickname = nickname
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decodeIfPresent(Int.self, forKey: .userID) ?? 0
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? "网易云音乐"
    }
}

struct AccountProfile: Decodable, Hashable, Identifiable {
    let id: Int
    let nickname: String
    let avatarURLString: String?

    var artworkURL: URL? {
        makeArtworkURL(from: avatarURLString)
    }

    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case nickname
        case avatarURLString = "avatarUrl"
    }
}

struct TrackReference: Codable, Hashable {
    let id: Int
}

struct Playlist: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let coverURLString: String?
    let playlistDescription: String?
    let trackCount: Int
    let playCount: Int
    let updateFrequency: String?
    let toplistType: String?
    let copywriter: String?
    let creator: UserSummary?
    var tracks: [Song]
    let trackIDs: [TrackReference]
    let subscribed: Bool

    var artworkURL: URL? {
        makeArtworkURL(from: coverURLString)
    }

    var isOfficialToplist: Bool {
        !(toplistType?.isEmpty ?? true)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, coverImgUrl, picUrl, description, trackCount, playCount
        case updateFrequency, copywriter, creator, tracks, trackIds, subscribed
        case toplistType = "ToplistType"
    }

    init(
        id: Int,
        name: String,
        coverURLString: String? = nil,
        playlistDescription: String? = nil,
        trackCount: Int = 0,
        playCount: Int = 0,
        updateFrequency: String? = nil,
        toplistType: String? = nil,
        copywriter: String? = nil,
        creator: UserSummary? = nil,
        tracks: [Song] = [],
        trackIDs: [TrackReference] = [],
        subscribed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.coverURLString = coverURLString
        self.playlistDescription = playlistDescription
        self.trackCount = trackCount
        self.playCount = playCount
        self.updateFrequency = updateFrequency
        self.toplistType = toplistType
        self.copywriter = copywriter
        self.creator = creator
        self.tracks = tracks
        self.trackIDs = trackIDs
        self.subscribed = subscribed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未知歌单"
        coverURLString = try container.decodeIfPresent(String.self, forKey: .coverImgUrl)
            ?? container.decodeIfPresent(String.self, forKey: .picUrl)
        playlistDescription = try container.decodeIfPresent(String.self, forKey: .description)
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount) ?? 0
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount) ?? 0
        updateFrequency = try container.decodeIfPresent(String.self, forKey: .updateFrequency)
        toplistType = try container.decodeIfPresent(String.self, forKey: .toplistType)
        copywriter = try container.decodeIfPresent(String.self, forKey: .copywriter)
        creator = try container.decodeIfPresent(UserSummary.self, forKey: .creator)
        tracks = try container.decodeIfPresent([Song].self, forKey: .tracks) ?? []
        trackIDs = try container.decodeIfPresent([TrackReference].self, forKey: .trackIds) ?? []
        subscribed = try container.decodeIfPresent(Bool.self, forKey: .subscribed) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(coverURLString, forKey: .coverImgUrl)
        try container.encodeIfPresent(playlistDescription, forKey: .description)
        try container.encode(trackCount, forKey: .trackCount)
        try container.encode(playCount, forKey: .playCount)
        try container.encodeIfPresent(updateFrequency, forKey: .updateFrequency)
        try container.encodeIfPresent(toplistType, forKey: .toplistType)
        try container.encodeIfPresent(copywriter, forKey: .copywriter)
        try container.encodeIfPresent(creator, forKey: .creator)
        try container.encode(tracks, forKey: .tracks)
        try container.encode(trackIDs, forKey: .trackIds)
        try container.encode(subscribed, forKey: .subscribed)
    }
}

enum LoadingPhase: Equatable {
    case loading
    case loaded
    case failed(String)
}
