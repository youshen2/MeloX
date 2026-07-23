import Foundation

struct AccountProfile: Decodable, Hashable, Identifiable {
    let id: Int
    let nickname: String
    let avatarURLString: String?
    let backgroundURLString: String?
    let signature: String?
    let follows: Int?
    let followeds: Int?
    let eventCount: Int?
    let playlistCount: Int?
    let playlistBeSubscribedCount: Int?

    var artworkURL: URL? {
        makeArtworkURL(from: avatarURLString)
    }

    var backgroundURL: URL? {
        makeArtworkURL(from: backgroundURLString)
    }

    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case nickname
        case avatarURLString = "avatarUrl"
        case backgroundURLString = "backgroundUrl"
        case signature
        case follows
        case followeds
        case eventCount
        case playlistCount
        case playlistBeSubscribedCount
    }
}

struct AccountDetail: Hashable {
    let profile: AccountProfile
    let level: Int
    let listenSongs: Int
    let createDays: Int?
}

struct AccountDetailResponse: Decodable {
    let code: Int
    let profile: AccountProfile?
    let level: Int?
    let listenSongs: Int?
    let createDays: Int?
    let message: String?
}
