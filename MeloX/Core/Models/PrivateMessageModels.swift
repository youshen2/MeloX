import Foundation

struct NeteasePrivateMessagePayload: Hashable {
    let text: String
    let resource: NeteaseShareResource?

    var summary: String {
        if !text.isEmpty {
            return text
        }
        if let resource {
            return "[\(resource.kindTitle)] \(resource.title)"
        }
        return "私信"
    }

    static func decode(_ serialized: String) -> Self {
        guard let data = serialized.data(using: .utf8),
              let wire = try? JSONDecoder().decode(
                NeteasePrivateMessagePayloadWire.self,
                from: data
              ) else {
            return Self(text: serialized, resource: nil)
        }

        let resource: NeteaseShareResource?
        if let song = wire.song {
            resource = .song(song)
        } else if let playlist = wire.playlist {
            resource = .playlist(playlist)
        } else if let album = wire.album {
            resource = .album(album)
        } else {
            resource = nil
        }

        return Self(
            text: wire.message?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            resource: resource
        )
    }
}

struct NeteasePrivateConversation: Decodable, Hashable, Identifiable {
    let fromUser: NeteaseMessageContact?
    let toUser: NeteaseMessageContact?
    let lastMessageTime: Int64
    let lastMessage: NeteasePrivateMessagePayload
    var unreadCount: Int

    var id: String {
        [fromUser?.id ?? 0, toUser?.id ?? 0]
            .sorted()
            .map(String.init)
            .joined(separator: "-")
    }

    func participant(currentUserID: Int) -> NeteaseMessageContact {
        if let fromUser, fromUser.id != currentUserID {
            return fromUser
        }
        if let toUser, toUser.id != currentUserID {
            return toUser
        }
        return fromUser
            ?? toUser
            ?? NeteaseMessageContact(id: 0, nickname: "网易云用户")
    }

    enum CodingKeys: String, CodingKey {
        case fromUser, toUser
        case lastMessageTime = "lastMsgTime"
        case lastMessage = "lastMsg"
        case unreadCount = "newMsgCount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fromUser = try container.decodeIfPresent(
            NeteaseMessageContact.self,
            forKey: .fromUser
        )
        toUser = try container.decodeIfPresent(
            NeteaseMessageContact.self,
            forKey: .toUser
        )
        lastMessageTime = try container.decodeIfPresent(
            Int64.self,
            forKey: .lastMessageTime
        ) ?? 0
        let serialized = try container.decodeIfPresent(
            String.self,
            forKey: .lastMessage
        ) ?? ""
        lastMessage = .decode(serialized)
        unreadCount = try container.decodeIfPresent(
            Int.self,
            forKey: .unreadCount
        ) ?? 0
    }
}

struct NeteasePrivateMessage: Decodable, Hashable, Identifiable {
    let id: Int64
    let fromUser: NeteaseMessageContact?
    let toUser: NeteaseMessageContact?
    let time: Int64
    let payload: NeteasePrivateMessagePayload

    func isOutgoing(currentUserID: Int) -> Bool {
        fromUser?.id == currentUserID
    }

    enum CodingKeys: String, CodingKey {
        case id, fromUser, toUser, time
        case payload = "msg"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fromUser = try container.decodeIfPresent(
            NeteaseMessageContact.self,
            forKey: .fromUser
        )
        toUser = try container.decodeIfPresent(
            NeteaseMessageContact.self,
            forKey: .toUser
        )
        time = try container.decodeIfPresent(Int64.self, forKey: .time) ?? 0
        id = try container.decodeIfPresent(Int64.self, forKey: .id) ?? time
        let serialized = try container.decodeIfPresent(
            String.self,
            forKey: .payload
        ) ?? ""
        payload = .decode(serialized)
    }
}

struct NeteasePrivateConversationsResponse: Decodable {
    let code: Int
    let messages: [NeteasePrivateConversation]
    let more: Bool?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, more, message
        case messages = "msgs"
    }
}

struct NeteasePrivateMessageHistoryResponse: Decodable {
    let code: Int
    let messages: [NeteasePrivateMessage]
    let more: Bool?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, more, message
        case messages = "msgs"
    }
}

private struct NeteasePrivateMessagePayloadWire: Decodable {
    let message: String?
    let song: Song?
    let playlist: Playlist?
    let album: Album?

    enum CodingKeys: String, CodingKey {
        case message = "msg"
        case song, playlist, album
    }
}
