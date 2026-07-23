import Foundation

struct CloudSong: Decodable, Hashable, Identifiable {
    let songID: Int
    let songName: String
    let artist: String
    let album: String
    let fileSize: Int64
    let bitrate: Int
    let addTime: Int64
    let simpleSong: Song

    var id: Int { songID }

    enum CodingKeys: String, CodingKey {
        case songID = "songId"
        case songName, artist, album, fileSize, bitrate, addTime, simpleSong
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        simpleSong = try container.decode(Song.self, forKey: .simpleSong)
        songID = container.lossyInt(forKey: .songID) ?? simpleSong.id
        songName = try container.decodeIfPresent(String.self, forKey: .songName) ?? simpleSong.name
        artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? simpleSong.artistText
        album = try container.decodeIfPresent(String.self, forKey: .album) ?? simpleSong.album?.name ?? "未知专辑"
        fileSize = container.lossyInt64(forKey: .fileSize) ?? 0
        bitrate = container.lossyInt(forKey: .bitrate) ?? 0
        addTime = container.lossyInt64(forKey: .addTime) ?? 0
    }
}

struct CloudMusicPage: Decodable {
    let code: Int
    let data: [CloudSong]
    let count: Int
    let size: Int64
    let maxSize: Int64
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case code, data, count, size, maxSize, hasMore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        data = try container.decodeIfPresent([CloudSong].self, forKey: .data) ?? []
        count = container.lossyInt(forKey: .count) ?? data.count
        size = container.lossyInt64(forKey: .size) ?? 0
        maxSize = container.lossyInt64(forKey: .maxSize) ?? 0
        hasMore = container.lossyBool(forKey: .hasMore) ?? (data.count < count)
    }
}

struct CloudUploadCheckResponse: Decodable {
    let code: Int
    let needUpload: Bool
    let songID: Int
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, needUpload
        case songID = "songId"
        case message, msg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        needUpload = container.lossyBool(forKey: .needUpload) ?? false
        songID = container.lossyInt(forKey: .songID) ?? 0
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .msg)
    }
}

struct CloudNOSTokenResponse: Decodable {
    let code: Int
    let result: CloudNOSToken
    let message: String?
}

struct CloudNOSToken: Decodable {
    let objectKey: String
    let resourceID: String
    let token: String

    enum CodingKeys: String, CodingKey {
        case objectKey, token
        case resourceID = "resourceId"
    }
}

struct CloudUploadInfoResponse: Decodable {
    let code: Int
    let songID: Int
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code
        case songID = "songId"
        case message, msg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        songID = container.lossyInt(forKey: .songID) ?? 0
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .msg)
    }
}

struct NOSLBSResponse: Decodable {
    let upload: [String]
}

private extension KeyedDecodingContainer {
    func lossyInt(forKey key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        guard let value = try? decode(String.self, forKey: key) else { return nil }
        return Int(value)
    }

    func lossyInt64(forKey key: Key) -> Int64? {
        if let value = try? decode(Int64.self, forKey: key) {
            return value
        }
        guard let value = try? decode(String.self, forKey: key) else { return nil }
        return Int64(value)
    }

    func lossyBool(forKey key: Key) -> Bool? {
        if let value = try? decode(Bool.self, forKey: key) {
            return value
        }
        if let value = lossyInt(forKey: key) {
            return value != 0
        }
        guard let value = try? decode(String.self, forKey: key) else { return nil }
        switch value.lowercased() {
        case "true", "yes": return true
        case "false", "no": return false
        default: return nil
        }
    }
}
