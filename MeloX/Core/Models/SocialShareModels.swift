import Foundation

enum NeteaseShareResource: Hashable, Identifiable {
    case song(Song)
    case playlist(Playlist)
    case album(Album)

    var id: String {
        "\(resourceType)-\(resourceID)"
    }

    var resourceID: Int {
        switch self {
        case .song(let song):
            song.id
        case .playlist(let playlist):
            playlist.id
        case .album(let album):
            album.id
        }
    }

    var resourceType: String {
        switch self {
        case .song:
            "song"
        case .playlist:
            "playlist"
        case .album:
            "album"
        }
    }

    var kindTitle: String {
        switch self {
        case .song:
            "歌曲"
        case .playlist:
            "歌单"
        case .album:
            "专辑"
        }
    }

    var title: String {
        switch self {
        case .song(let song):
            song.name
        case .playlist(let playlist):
            playlist.name
        case .album(let album):
            album.name
        }
    }

    var subtitle: String? {
        switch self {
        case .song(let song):
            song.artistText
        case .playlist(let playlist):
            playlist.creator?.nickname
        case .album(let album):
            album.artistText
        }
    }

    var artworkURL: URL? {
        switch self {
        case .song(let song):
            song.album?.artworkURL
        case .playlist(let playlist):
            playlist.artworkURL
        case .album(let album):
            album.artworkURL
        }
    }

    var webURL: URL {
        URL(
            string: "https://music.163.com/\(resourceType)?id=\(resourceID)"
        )!
    }

    var supportsTimelineSharing: Bool {
        switch self {
        case .song, .playlist:
            true
        case .album:
            false
        }
    }
}

struct NeteaseMessageContact: Decodable, Hashable, Identifiable {
    let id: Int
    let nickname: String
    let avatarURLString: String?
    let signature: String?
    let remarkName: String?
    let mutual: Bool?

    var displayName: String {
        let remark = remarkName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let remark, !remark.isEmpty else { return nickname }
        return remark
    }

    var artworkURL: URL? {
        makeArtworkURL(from: avatarURLString)
    }

    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case nickname
        case avatarURLString = "avatarUrl"
        case signature
        case remarkName
        case mutual
    }

    init(
        id: Int,
        nickname: String,
        avatarURLString: String? = nil,
        signature: String? = nil,
        remarkName: String? = nil,
        mutual: Bool? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.avatarURLString = avatarURLString
        self.signature = signature
        self.remarkName = remarkName
        self.mutual = mutual
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        nickname = try container.decodeIfPresent(
            String.self,
            forKey: .nickname
        ) ?? "网易云用户"
        avatarURLString = try container.decodeIfPresent(
            String.self,
            forKey: .avatarURLString
        )
        signature = try container.decodeIfPresent(
            String.self,
            forKey: .signature
        )
        remarkName = try container.decodeIfPresent(
            String.self,
            forKey: .remarkName
        )
        mutual = try container.decodeIfPresent(Bool.self, forKey: .mutual)
    }
}

struct NeteaseFollowsResponse: Decodable {
    let code: Int
    let follow: [NeteaseMessageContact]
    let more: Bool?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, follow, more, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        follow = try container.decodeIfPresent(
            [NeteaseMessageContact].self,
            forKey: .follow
        ) ?? []
        more = try container.decodeIfPresent(Bool.self, forKey: .more)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

enum NeteaseSocialError: LocalizedError {
    case noRecipient
    case unsupportedTimelineResource

    var errorDescription: String? {
        switch self {
        case .noRecipient:
            "请至少选择一位收件人。"
        case .unsupportedTimelineResource:
            "网易云音乐暂不支持将此类型的内容转发到动态。"
        }
    }
}
