import Foundation

nonisolated struct PodcastHost: Codable, Hashable, Identifiable {
    let id: Int
    let nickname: String
    let avatarURLString: String?

    var artworkURL: URL? {
        makeArtworkURL(from: avatarURLString, dimension: 320)
    }

    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case nickname
        case avatarURLString = "avatarUrl"
    }

    init(
        id: Int = 0,
        nickname: String = L10n.string("ui.metadata.netease_host"),
        avatarURLString: String? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.avatarURLString = avatarURLString
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        nickname = try container.decodeIfPresent(
            String.self,
            forKey: .nickname
        ) ?? L10n.string("ui.metadata.netease_host")
        avatarURLString = try container.decodeIfPresent(
            String.self,
            forKey: .avatarURLString
        )
    }
}

nonisolated struct Podcast: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let picURLString: String?
    let podcastDescription: String?
    let recommendationText: String?
    let categoryID: Int?
    let category: String?
    let secondCategory: String?
    let programCount: Int
    let subscriberCount: Int
    let playCount: Int
    let host: PodcastHost?
    var isSubscribed: Bool
    let feeType: Int?

    var artworkURL: URL? {
        makeArtworkURL(from: picURLString)
    }

    var subtitle: String? {
        recommendationText?.podcastNonempty
            ?? host?.nickname.podcastNonempty
            ?? category?.podcastNonempty
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case picURLString = "picUrl"
        case podcastDescription = "desc"
        case recommendationText = "rcmdText"
        case legacyRecommendationText = "rcmdtext"
        case categoryID = "categoryId"
        case category, secondCategory, programCount
        case subscriberCount = "subCount"
        case playCount
        case host = "dj"
        case isSubscribed = "subed"
        case feeType = "radioFeeType"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(picURLString, forKey: .picURLString)
        try container.encodeIfPresent(podcastDescription, forKey: .podcastDescription)
        try container.encodeIfPresent(recommendationText, forKey: .recommendationText)
        try container.encodeIfPresent(categoryID, forKey: .categoryID)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(secondCategory, forKey: .secondCategory)
        try container.encode(programCount, forKey: .programCount)
        try container.encode(subscriberCount, forKey: .subscriberCount)
        try container.encode(playCount, forKey: .playCount)
        try container.encodeIfPresent(host, forKey: .host)
        try container.encode(isSubscribed, forKey: .isSubscribed)
        try container.encodeIfPresent(feeType, forKey: .feeType)
    }

    init(
        id: Int,
        name: String,
        picURLString: String? = nil,
        podcastDescription: String? = nil,
        recommendationText: String? = nil,
        categoryID: Int? = nil,
        category: String? = nil,
        secondCategory: String? = nil,
        programCount: Int = 0,
        subscriberCount: Int = 0,
        playCount: Int = 0,
        host: PodcastHost? = nil,
        isSubscribed: Bool = false,
        feeType: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.picURLString = picURLString
        self.podcastDescription = podcastDescription
        self.recommendationText = recommendationText
        self.categoryID = categoryID
        self.category = category
        self.secondCategory = secondCategory
        self.programCount = programCount
        self.subscriberCount = subscriberCount
        self.playCount = playCount
        self.host = host
        self.isSubscribed = isSubscribed
        self.feeType = feeType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(
            String.self,
            forKey: .name
        ) ?? L10n.string("ui.metadata.unknown_podcast")
        picURLString = try container.decodeIfPresent(
            String.self,
            forKey: .picURLString
        )
        podcastDescription = try container.decodeIfPresent(
            String.self,
            forKey: .podcastDescription
        )
        recommendationText =
            try container.decodeIfPresent(
                String.self,
                forKey: .recommendationText
            )
            ?? container.decodeIfPresent(
                String.self,
                forKey: .legacyRecommendationText
            )
        categoryID = try container.decodeIfPresent(
            Int.self,
            forKey: .categoryID
        )
        category = try container.decodeIfPresent(
            String.self,
            forKey: .category
        )
        secondCategory = try container.decodeIfPresent(
            String.self,
            forKey: .secondCategory
        )
        programCount = try container.decodeIfPresent(
            Int.self,
            forKey: .programCount
        ) ?? 0
        subscriberCount = try container.decodeIfPresent(
            Int.self,
            forKey: .subscriberCount
        ) ?? 0
        playCount = try container.decodeIfPresent(
            Int.self,
            forKey: .playCount
        ) ?? 0
        host = try container.decodeIfPresent(
            PodcastHost.self,
            forKey: .host
        )
        isSubscribed = try container.decodeIfPresent(
            Bool.self,
            forKey: .isSubscribed
        ) ?? false
        feeType = try container.decodeIfPresent(
            Int.self,
            forKey: .feeType
        )
    }
}

struct PodcastCategory: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    let picURLString: String?

    var artworkURL: URL? {
        makeArtworkURL(from: picURLString, dimension: 192)
    }

    var localizedName: String {
        let key: String
        switch name {
        case "创作翻唱": key = "ui.podcasts.category.covers"
        case "3D电子", "电音": key = "ui.podcasts.category.electronic"
        case "情感": key = "ui.podcasts.category.emotions"
        case "音乐播客": key = "ui.podcasts.category.music"
        case "有声书": key = "ui.podcasts.category.audiobooks"
        case "脱口秀": key = "ui.podcasts.category.talk_shows"
        case "创意播客": key = "ui.podcasts.category.creative"
        case "知识": key = "ui.podcasts.category.knowledge"
        case "二次元": key = "ui.podcasts.category.anime"
        case "明星专区": key = "ui.podcasts.category.celebrities"
        case "生活": key = "ui.podcasts.category.lifestyle"
        case "亲子": key = "ui.podcasts.category.parenting"
        case "资讯": key = "ui.podcasts.category.news"
        case "广播剧": key = "ui.podcasts.category.audio_drama"
        case "故事": key = "ui.podcasts.category.stories"
        case "人文历史": key = "ui.podcasts.category.humanities_history"
        case "其他": key = "ui.podcasts.category.other"
        default: return name
        }
        return L10n.string(key)
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case picURLString = "pic96x96Url"
        case fallbackPicURLString = "pic56x56Url"
    }

    init(
        id: Int,
        name: String,
        picURLString: String? = nil
    ) {
        self.id = id
        self.name = name
        self.picURLString = picURLString
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(
            String.self,
            forKey: .name
        ) ?? L10n.string("ui.common.podcast")
        picURLString =
            try container.decodeIfPresent(
                String.self,
                forKey: .picURLString
            )
            ?? container.decodeIfPresent(
                String.self,
                forKey: .fallbackPicURLString
            )
    }
}

struct PodcastProgramRadio: Codable, Hashable {
    let id: Int
    let name: String
    let picURLString: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case picURLString = "picUrl"
    }

    init(
        id: Int,
        name: String,
        picURLString: String? = nil
    ) {
        self.id = id
        self.name = name
        self.picURLString = picURLString
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(
            String.self,
            forKey: .name
        ) ?? L10n.string("ui.metadata.unknown_podcast")
        picURLString = try container.decodeIfPresent(
            String.self,
            forKey: .picURLString
        )
    }
}

struct PodcastProgram: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let coverURLString: String?
    let programDescription: String?
    let createTime: Int64?
    let durationMS: Int
    let listenerCount: Int
    let likedCount: Int
    let commentCount: Int
    let serialNumber: Int?
    let feeScope: Int?
    let radio: PodcastProgramRadio
    let host: PodcastHost?
    let mainSong: Song?

    var artworkURL: URL? {
        makeArtworkURL(
            from: coverURLString ?? radio.picURLString
        )
    }

    var playbackSong: Song? {
        guard let mainSong, mainSong.id > 0 else { return nil }

        let resolvedHostName =
            host?.nickname.podcastNonempty
            ?? mainSong.artists.first?.name.podcastNonempty
            ?? radio.name
        let artist = Artist(
            id: 0,
            name: resolvedHostName,
            picURL: host?.avatarURLString,
            avatarURL: host?.avatarURLString
        )
        let album = Album(
            id: 0,
            name: radio.name,
            picURL: coverURLString ?? radio.picURLString,
            artists: [artist],
            publishTime: createTime.map { Double($0) },
            type: L10n.string("ui.common.podcast"),
            albumDescription: programDescription
        )
        let metadata = PodcastPlaybackMetadata(
            programID: id,
            radioID: radio.id,
            radioName: radio.name,
            coverURLString: coverURLString ?? radio.picURLString,
            hostName: resolvedHostName,
            hostAvatarURLString: host?.avatarURLString,
            programDescription: programDescription
        )

        return Song(
            id: mainSong.id,
            name: name,
            artists: [artist],
            album: album,
            durationMS: durationMS > 0
                ? durationMS
                : mainSong.durationMS,
            trackNumber: serialNumber,
            fee: mainSong.fee,
            aliases: mainSong.aliases,
            popularity: mainSong.popularity,
            publishTime: createTime.map { Double($0) }
                ?? mainSong.publishTime,
            copyright: mainSong.copyright,
            podcastMetadata: metadata,
            audioAvailability: mainSong.audioAvailability
        )
    }

    var podcastSummary: Podcast {
        Podcast(
            id: radio.id,
            name: radio.name,
            picURLString: radio.picURLString,
            programCount: 0,
            host: host
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case coverURLString = "coverUrl"
        case programDescription = "description"
        case createTime, listenerCount, likedCount, commentCount
        case durationMS = "duration"
        case serialNumber = "serialNum"
        case feeScope, radio
        case host = "dj"
        case mainSong
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(
            String.self,
            forKey: .name
        ) ?? L10n.string("ui.metadata.unknown_program")
        coverURLString = try container.decodeIfPresent(
            String.self,
            forKey: .coverURLString
        )
        programDescription = try container.decodeIfPresent(
            String.self,
            forKey: .programDescription
        )
        createTime = try container.decodeFlexibleInt64IfPresent(
            forKey: .createTime
        )
        durationMS = try container.decodeIfPresent(
            Int.self,
            forKey: .durationMS
        ) ?? 0
        listenerCount = try container.decodeIfPresent(
            Int.self,
            forKey: .listenerCount
        ) ?? 0
        likedCount = try container.decodeIfPresent(
            Int.self,
            forKey: .likedCount
        ) ?? 0
        commentCount = try container.decodeIfPresent(
            Int.self,
            forKey: .commentCount
        ) ?? 0
        serialNumber = try container.decodeIfPresent(
            Int.self,
            forKey: .serialNumber
        )
        feeScope = try container.decodeIfPresent(
            Int.self,
            forKey: .feeScope
        )
        radio = try container.decodeIfPresent(
            PodcastProgramRadio.self,
            forKey: .radio
        ) ?? PodcastProgramRadio(
            id: 0,
            name: L10n.string("ui.metadata.unknown_podcast")
        )
        host = try container.decodeIfPresent(
            PodcastHost.self,
            forKey: .host
        )
        mainSong = try container.decodeIfPresent(
            Song.self,
            forKey: .mainSong
        )
    }
}

nonisolated struct PodcastPlaybackMetadata: Codable, Hashable {
    let programID: Int
    let radioID: Int
    let radioName: String
    let coverURLString: String?
    let hostName: String
    let hostAvatarURLString: String?
    let programDescription: String?

    var podcastSummary: Podcast {
        Podcast(
            id: radioID,
            name: radioName,
            picURLString: coverURLString,
            podcastDescription: nil,
            programCount: 0,
            host: PodcastHost(
                nickname: hostName,
                avatarURLString: hostAvatarURLString
            )
        )
    }
}

struct PodcastPage {
    let podcasts: [Podcast]
    let hasMore: Bool
    let totalCount: Int?
}

struct PodcastProgramPage {
    let programs: [PodcastProgram]
    let hasMore: Bool
    let totalCount: Int
}

enum PodcastProgramOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: L10n.string("ui.podcast.sort.newest")
        case .oldest: L10n.string("ui.podcast.sort.oldest")
        }
    }

    var ascending: Bool {
        self == .oldest
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt64IfPresent(
        forKey key: Key
    ) throws -> Int64? {
        if let value = try? decode(Int64.self, forKey: key) {
            return value
        }
        if let value = try? decode(Double.self, forKey: key) {
            return Int64(value)
        }
        if let value = try? decode(String.self, forKey: key) {
            return Int64(value)
        }
        return nil
    }
}

extension String {
    nonisolated var podcastNonempty: String? {
        let value = trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return value.isEmpty ? nil : value
    }
}
