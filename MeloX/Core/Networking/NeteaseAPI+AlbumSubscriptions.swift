import Foundation

extension NeteaseAPI {
    func subscribedAlbums(limit: Int = 2_000) async throws -> [Album] {
        // @neteaseapireborn/api/module/album_sublist.js uses this original
        // NetEase WEAPI endpoint with limit, offset, and total.
        let path = "/api/album/sublist"
        let data: [String: Any] = [
            "limit": max(limit, 1),
            "offset": 0,
            "total": true,
        ]
        let response: SubscribedAlbumsResponse
        do {
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
        return response.albums ?? []
    }
}

private struct SubscribedAlbumsResponse: Decodable {
    let code: Int
    let albums: [Album]?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code
        case albums = "data"
        case message
    }
}
