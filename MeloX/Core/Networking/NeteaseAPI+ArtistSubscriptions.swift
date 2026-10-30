import Foundation

extension NeteaseAPI {
    func subscribedArtists(limit: Int = 2_000) async throws -> [Artist] {
        let path = "/api/artist/sublist"
        let data: [String: Any] = [
            "limit": max(limit, 1),
            "offset": 0,
            "total": true,
        ]
        let response: SubscribedArtistsResponse
        do {
            // Mirrors @neteaseapireborn/api/module/artist_sublist.js.
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            response = try await client.eapi(
                path,
                data: data,
                authenticated: true
            )
        }
        try validate(responseCode: response.code, message: response.message)
        return response.artists
    }

    func setArtistFollowed(id: Int, isFollowed: Bool) async throws {
        let path = isFollowed ? "/api/artist/sub" : "/api/artist/unsub"
        let data: [String: Any] = [
            "artistId": id,
            "artistIds": "[\(id)]",
        ]
        let response: APIStatusResponse
        do {
            // Mirrors @neteaseapireborn/api/module/artist_sub.js.
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            response = try await client.eapi(
                path,
                data: data,
                authenticated: true
            )
        }
        try validate(responseCode: response.code, message: response.message)
    }

}

private struct SubscribedArtistsResponse: Decodable {
    let code: Int
    let artists: [Artist]
    let hasMore: Bool?
    let count: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code
        case artists = "data"
        case hasMore, count, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        artists = try container.decodeIfPresent(
            [Artist].self,
            forKey: .artists
        ) ?? []
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
        count = try container.decodeIfPresent(Int.self, forKey: .count)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

