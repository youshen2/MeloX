import Foundation

struct HomeContentSnapshot: Codable {
    let payload: HomePagePayload
    let charts: [Playlist]
    let fallbacks: [HomeRecommendationSlot: HomeRecommendationFallback]

    static func cacheKey(musicArea: String) -> String {
        "home.v1.\(musicArea)"
    }
}
