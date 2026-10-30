import Foundation

struct HomePageResponse: Decodable {
    let code: Int
    let data: HomePagePayload?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, data, message, msg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        data = try container.decodeIfPresent(
            HomePagePayload.self,
            forKey: .data
        )
        message =
            try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .msg)
    }
}

struct HomePagePayload: Codable {
    let blocks: [HomePageBlock]
    let hasMore: Bool
    let cursor: String?

    enum CodingKeys: String, CodingKey {
        case blocks, hasMore, cursor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blocks = try container.decodeIfPresent(
            [HomePageBlock].self,
            forKey: .blocks
        ) ?? []
        hasMore = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasMore
        ) ?? false
        cursor = try container.decodeIfPresent(
            String.self,
            forKey: .cursor
        )
    }
}

struct HomePageBlock: Codable, Identifiable {
    let blockCode: String
    let showType: String?
    let uiElement: HomePageUIElement?
    let creatives: [HomePageCreative]
    let action: String?

    var id: String {
        [
            blockCode,
            title ?? "",
            creatives.first?.creativeID ?? "",
            creatives.first?.resources.first?.resourceID ?? "",
        ].joined(separator: "|")
    }

    var sectionTitle: String? {
        uiElement?.subTitle?.nonemptyTitle
            ?? uiElement?.mainTitle?.nonemptyTitle
    }

    var title: String? {
        sectionTitle
            ?? creatives.lazy.compactMap {
                $0.uiElement?.mainTitle?.nonemptyTitle
            }.first
    }

    var resources: [HomePageResource] {
        var seen: Set<String> = []
        return creatives
            .flatMap(\.resources)
            .filter { resource in
                seen.insert(resource.id).inserted
            }
    }

    var playlists: [Playlist] {
        resources.compactMap(\.playlist)
    }

    var songs: [Song] {
        resources.compactMap(\.song)
    }

    var podcastPrograms: [PodcastProgram] {
        resources.compactMap(\.podcastProgram)
    }

    enum CodingKeys: String, CodingKey {
        case blockCode, showType, uiElement, creatives, action
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockCode = try container.decodeIfPresent(
            String.self,
            forKey: .blockCode
        ) ?? "HOMEPAGE_BLOCK_UNKNOWN"
        showType = try container.decodeIfPresent(
            String.self,
            forKey: .showType
        )
        uiElement = try container.decodeIfPresent(
            HomePageUIElement.self,
            forKey: .uiElement
        )
        creatives = try container.decodeIfPresent(
            [HomePageCreative].self,
            forKey: .creatives
        ) ?? []
        action = try container.decodeIfPresent(
            String.self,
            forKey: .action
        )
    }
}

struct HomePageCreative: Codable {
    let creativeType: String?
    let creativeID: String?
    let action: String?
    let uiElement: HomePageUIElement?
    let resources: [HomePageResource]

    enum CodingKeys: String, CodingKey {
        case creativeType, action, uiElement, resources
        case creativeID = "creativeId"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        creativeType = try container.decodeIfPresent(
            String.self,
            forKey: .creativeType
        )
        creativeID = Self.decodeString(
            from: container,
            forKey: .creativeID
        )
        action = try container.decodeIfPresent(
            String.self,
            forKey: .action
        )
        uiElement = try container.decodeIfPresent(
            HomePageUIElement.self,
            forKey: .uiElement
        )
        resources = try container.decodeIfPresent(
            [HomePageResource].self,
            forKey: .resources
        ) ?? []
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
