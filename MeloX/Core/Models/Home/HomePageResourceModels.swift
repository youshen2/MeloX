import Foundation

struct HomePageResource: Codable, Identifiable {
    let resourceType: String?
    let resourceID: String?
    let action: String?
    let uiElement: HomePageUIElement?
    let extensionInfo: HomePageResourceExtension?

    var id: String {
        [
            resourceType ?? "unknown",
            resourceID ?? "",
            uiElement?.mainTitle?.title ?? "",
        ].joined(separator: "|")
    }

    var title: String {
        uiElement?.mainTitle?.nonemptyTitle
            ?? extensionInfo?.song?.name
            ?? extensionInfo?.podcastProgram?.name
            ?? L10n.string("ui.common.netease_cloud_music")
    }

    var subtitle: String? {
        uiElement?.subTitle?.nonemptyTitle
    }

    var playlist: Playlist? {
        guard ["list", "playlist"].contains(
            resourceType?.lowercased() ?? ""
        ),
              let resourceID,
              let id = Int(resourceID),
              id > 0 else {
            return nil
        }
        return Playlist(
            id: id,
            name: title,
            coverURLString: uiElement?.image?.imageURL,
            playCount: extensionInfo?.playCount ?? 0,
            copywriter: subtitle
        )
    }

    var song: Song? {
        if let song = extensionInfo?.song, song.id > 0 {
            return song
        }
        guard resourceType?.lowercased() == "song",
              let resourceID,
              let id = Int(resourceID),
              id > 0 else {
            return nil
        }
        let artists = extensionInfo?.artists ?? []
        return Song(
            id: id,
            name: title,
            artists: artists,
            album: Album(
                id: 0,
                name: title,
                picURL: uiElement?.image?.imageURL,
                artists: artists
            )
        )
    }

    var podcastProgram: PodcastProgram? {
        guard ["voice", "program", "dj_program"].contains(
            resourceType?.lowercased() ?? ""
        ) else {
            return nil
        }
        return extensionInfo?.podcastProgram
    }

    enum CodingKeys: String, CodingKey {
        case resourceType, action, uiElement
        case resourceID = "resourceId"
        case extensionInfo = "resourceExtInfo"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resourceType = try container.decodeIfPresent(
            String.self,
            forKey: .resourceType
        )
        resourceID = Self.decodeString(
            from: container,
            forKey: .resourceID
        )
        action = try container.decodeIfPresent(
            String.self,
            forKey: .action
        )
        uiElement = try container.decodeIfPresent(
            HomePageUIElement.self,
            forKey: .uiElement
        )
        extensionInfo = try? container.decodeIfPresent(
            HomePageResourceExtension.self,
            forKey: .extensionInfo
        )
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int64.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}

struct HomePageUIElement: Codable {
    let mainTitle: HomePageTitle?
    let subTitle: HomePageTitle?
    let image: HomePageImage?
    let labelTexts: [String]

    enum CodingKeys: String, CodingKey {
        case mainTitle, subTitle, image, labelTexts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainTitle = try container.decodeIfPresent(
            HomePageTitle.self,
            forKey: .mainTitle
        )
        subTitle = try container.decodeIfPresent(
            HomePageTitle.self,
            forKey: .subTitle
        )
        image = try container.decodeIfPresent(
            HomePageImage.self,
            forKey: .image
        )
        labelTexts =
            (try? container.decodeIfPresent(
                [String].self,
                forKey: .labelTexts
            )) ?? []
    }
}

struct HomePageTitle: Codable {
    let title: String?

    var nonemptyTitle: String? {
        guard let title = title?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !title.isEmpty else {
            return nil
        }
        return title
    }
}

struct HomePageImage: Codable {
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case imageURL = "imageUrl"
    }
}

struct HomePageResourceExtension: Codable {
    let artists: [Artist]
    let song: Song?
    let podcastProgram: PodcastProgram?
    let playCount: Int?

    enum CodingKeys: String, CodingKey {
        case artists, song, songData, djProgram, playCount
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(artists, forKey: .artists)
        try container.encodeIfPresent(song, forKey: .song)
        try container.encodeIfPresent(podcastProgram, forKey: .djProgram)
        try container.encodeIfPresent(playCount, forKey: .playCount)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artists =
            (try? container.decodeIfPresent(
                [Artist].self,
                forKey: .artists
            )) ?? []
        song =
            (try? container.decodeIfPresent(
                Song.self,
                forKey: .songData
            ))
            ?? (try? container.decodeIfPresent(
                Song.self,
                forKey: .song
            ))
        podcastProgram = try? container.decodeIfPresent(
            PodcastProgram.self,
            forKey: .djProgram
        )
        playCount = try? container.decodeIfPresent(
            Int.self,
            forKey: .playCount
        )
    }
}
