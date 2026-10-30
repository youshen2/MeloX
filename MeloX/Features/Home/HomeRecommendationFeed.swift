import Foundation

enum HomeRecommendationContent: Codable {
    case playlists([Playlist])
    case songs([Song])
    case podcastPrograms([PodcastProgram])

    var isEmpty: Bool {
        switch self {
        case .playlists(let playlists):
            playlists.isEmpty
        case .songs(let songs):
            songs.isEmpty
        case .podcastPrograms(let programs):
            programs.isEmpty
        }
    }

    init?(block: HomePageBlock) {
        if !block.playlists.isEmpty {
            self = .playlists(block.playlists)
        } else if !block.songs.isEmpty {
            self = .songs(block.songs)
        } else if !block.podcastPrograms.isEmpty {
            self = .podcastPrograms(block.podcastPrograms)
        } else {
            return nil
        }
    }
}

struct HomeRecommendationFallback: Codable {
    let title: HomeRecommendationTitle
    let content: HomeRecommendationContent
}

enum HomeRecommendationTitle: Codable {
    case standard
    case tailoredForSong(String)
    case userPlaylists(String)
    case userRadar(String)
    case regionalHits(HomeMusicRegion)

    func localized(for slot: HomeRecommendationSlot) -> String {
        switch self {
        case .standard:
            slot.fallbackTitle
        case .tailoredForSong(let songName):
            L10n.format("ui.home.section.tailored_for_song", songName)
        case .userPlaylists(let nickname):
            L10n.format("ui.home.section.user_playlists", nickname)
        case .userRadar(let nickname):
            L10n.format("ui.home.section.user_radar", nickname)
        case .regionalHits(let region):
            L10n.format(
                "ui.home.section.region_recent_hits",
                region.title
            )
        }
    }
}

struct HomeRecommendationSection: Identifiable {
    let slot: HomeRecommendationSlot
    private let titleSource: HomeRecommendationTitle
    let content: HomeRecommendationContent

    var id: HomeRecommendationSlot { slot }
    var title: String { titleSource.localized(for: slot) }

    init?(
        slot: HomeRecommendationSlot,
        block: HomePageBlock
    ) {
        guard let content = HomeRecommendationContent(block: block)
        else {
            return nil
        }
        self.slot = slot
        titleSource = .standard
        self.content = content
    }

    init?(
        slot: HomeRecommendationSlot,
        fallback: HomeRecommendationFallback
    ) {
        guard !fallback.content.isEmpty else { return nil }
        self.slot = slot
        titleSource = fallback.title
        content = fallback.content
    }
}

enum HomeRecommendationSlot: Int, Codable, CaseIterable, Identifiable {
    case recommendedPlaylists
    case recentlyTrending
    case tailoredRecommendation
    case charts
    case personalPlaylists
    case radarPlaylists
    case regionalHits
    case likedSongRoaming
    case likedSongRecommendations
    case listenedPodcastRecommendations

    var id: Int { rawValue }

    var fallbackTitle: String {
        switch self {
        case .recommendedPlaylists:
            L10n.string("ui.home.section.recommended_playlists")
        case .recentlyTrending:
            L10n.string("ui.home.section.recently_trending")
        case .tailoredRecommendation:
            L10n.string("ui.home.section.tailored")
        case .charts:
            L10n.string("ui.home.section.charts")
        case .personalPlaylists:
            L10n.string("ui.home.section.your_playlists")
        case .radarPlaylists:
            L10n.string("ui.home.section.your_radar")
        case .regionalHits:
            L10n.string("ui.home.section.regional_hits")
        case .likedSongRoaming:
            L10n.string("ui.home.section.liked_song_roaming")
        case .likedSongRecommendations:
            L10n.string("ui.home.section.liked_song_recommendations")
        case .listenedPodcastRecommendations:
            L10n.string("ui.home.section.podcast_recommendations")
        }
    }

}

struct HomeRecommendationFeed {
    let sections: [HomeRecommendationSection]

    init(
        blocks: [HomePageBlock],
        fallbacks: [
            HomeRecommendationSlot: HomeRecommendationFallback
        ] = [:],
        includesPodcasts: Bool = true
    ) {
        var blocksBySlot: [
            HomeRecommendationSlot: HomePageBlock
        ] = [:]

        for block in blocks {
            guard HomeRecommendationContent(block: block) != nil,
                  let slot = Self.slot(for: block),
                  blocksBySlot[slot] == nil else {
                continue
            }
            blocksBySlot[slot] = block
        }

        let availableSlots = HomeRecommendationSlot.allCases.filter {
            includesPodcasts
                || $0 != .listenedPodcastRecommendations
        }
        sections = availableSlots.compactMap {
            slot in
            if let block = blocksBySlot[slot],
               let section = HomeRecommendationSection(
                   slot: slot,
                   block: block
               ) {
                return section
            }
            guard let fallback = fallbacks[slot] else {
                return nil
            }
            return HomeRecommendationSection(
                slot: slot,
                fallback: fallback
            )
        }
    }

    func contains(_ slot: HomeRecommendationSlot) -> Bool {
        sections.contains { $0.slot == slot }
    }

    var firstRadarPlaylist: Playlist? {
        guard let section = sections.first(
            where: { $0.slot == .radarPlaylists }
        ), case .playlists(let playlists) = section.content else {
            return nil
        }
        return playlists.first
    }

    private static func slot(
        for block: HomePageBlock
    ) -> HomeRecommendationSlot? {
        let code = block.blockCode.uppercased()
        let title = normalized(block.title)

        if code == "HOMEPAGE_BLOCK_PLAYLIST_RCMD"
            || title == "推荐歌单" {
            return .recommendedPlaylists
        }
        if title.contains("近期云村热播") {
            return .recentlyTrending
        }
        if code.contains("TOPLIST")
            || code.contains("RANK")
            || title == "排行榜" {
            return .charts
        }
        if code == "HOMEPAGE_BLOCK_MGC_PLAYLIST"
            || title.contains("雷达歌单") {
            return .radarPlaylists
        }
        if title.contains("最近的热门歌曲") {
            return .regionalHits
        }
        if title.contains("从你喜欢的歌开始漫游") {
            return .likedSongRoaming
        }
        if title.contains("根据你喜爱的歌曲推荐") {
            return .likedSongRecommendations
        }
        if code == "HOMEPAGE_VOICELIST_RCMD"
            || title.contains("根据你听过的热门节目推荐") {
            return .listenedPodcastRecommendations
        }
        if title.hasSuffix("的歌单"), title != "推荐歌单" {
            return .personalPlaylists
        }
        if title.hasPrefix("根据"), title.hasSuffix("为你推荐") {
            return .tailoredRecommendation
        }
        if code == "HOMEPAGE_BLOCK_STYLE_RCMD" {
            return .recentlyTrending
        }
        return nil
    }

    private static func normalized(_ value: String?) -> String {
        value?
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined()
            ?? ""
    }
}
