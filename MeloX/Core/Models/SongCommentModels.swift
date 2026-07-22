import Foundation

struct SongCommentUser: Decodable, Hashable, Identifiable {
    let id: Int
    let nickname: String
    let avatarURLString: String?

    var artworkURL: URL? {
        makeArtworkURL(from: avatarURLString, dimension: 96)
    }

    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case nickname
        case avatarURLString = "avatarUrl"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? "网易云音乐用户"
        avatarURLString = try container.decodeIfPresent(String.self, forKey: .avatarURLString)
    }
}

struct SongCommentReply: Decodable, Hashable {
    let user: SongCommentUser?
    let content: String

    enum CodingKeys: String, CodingKey {
        case user, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decodeIfPresent(SongCommentUser.self, forKey: .user)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? "该评论已删除"
    }
}

struct SongCommentIPLocation: Decodable, Hashable {
    let location: String?
}

struct SongCommentFloorSummary: Decodable, Hashable {
    let replyCount: Int

    enum CodingKeys: String, CodingKey {
        case replyCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount) ?? 0
    }
}

struct SongComment: Decodable, Hashable, Identifiable {
    let id: Int64
    let user: SongCommentUser
    let content: String
    let time: Double?
    let timeDescription: String?
    let likedCount: Int
    let isLiked: Bool
    let replies: [SongCommentReply]
    let ipLocation: SongCommentIPLocation?
    let floorSummary: SongCommentFloorSummary?

    var replyCount: Int {
        max(floorSummary?.replyCount ?? 0, replies.count)
    }

    enum CodingKeys: String, CodingKey {
        case id = "commentId"
        case user, content, time
        case timeDescription = "timeStr"
        case likedCount
        case isLiked = "liked"
        case replies = "beReplied"
        case ipLocation
        case floorSummary = "showFloorComment"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id) ?? 0
        user = try container.decode(SongCommentUser.self, forKey: .user)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        time = try container.decodeIfPresent(Double.self, forKey: .time)
        timeDescription = try container.decodeIfPresent(String.self, forKey: .timeDescription)
        likedCount = try container.decodeIfPresent(Int.self, forKey: .likedCount) ?? 0
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
        replies = try container.decodeIfPresent([SongCommentReply].self, forKey: .replies) ?? []
        ipLocation = try container.decodeIfPresent(SongCommentIPLocation.self, forKey: .ipLocation)
        floorSummary = try container.decodeIfPresent(
            SongCommentFloorSummary.self,
            forKey: .floorSummary
        )
    }
}

struct SongCommentFloorResponse: Decodable {
    let code: Int
    let data: SongCommentFloorData
}

struct SongCommentFloorData: Decodable {
    let ownerComment: SongComment?
    let comments: [SongComment]
    let totalCount: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case ownerComment, comments, totalCount, hasMore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ownerComment = try container.decodeIfPresent(SongComment.self, forKey: .ownerComment)
        comments = try container.decodeIfPresent([SongComment].self, forKey: .comments) ?? []
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? comments.count
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
}

struct SongCommentsResponse: Decodable {
    let code: Int
    let hotComments: [SongComment]
    let comments: [SongComment]
    let total: Int
    let more: Bool

    enum CodingKeys: String, CodingKey {
        case code, hotComments, comments, total, more
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        hotComments = try container.decodeIfPresent([SongComment].self, forKey: .hotComments) ?? []
        comments = try container.decodeIfPresent([SongComment].self, forKey: .comments) ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? comments.count
        more = try container.decodeIfPresent(Bool.self, forKey: .more) ?? false
    }
}
