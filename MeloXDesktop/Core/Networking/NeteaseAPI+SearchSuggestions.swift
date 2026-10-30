import Foundation

extension NeteaseAPI {
    func searchSuggestions(_ keywords: String) async throws -> [String] {
        // Mirrors search_suggest.js with type=mobile.
        let response: SearchSuggestionsResponse = try await client.weapi(
            "/api/search/suggest/keyword",
            data: ["s": keywords]
        )
        try validate(responseCode: response.code, message: response.message)
        var seen = Set<String>()
        return Array((response.result?.allMatch ?? []).map(\.keyword)
            .filter { seen.insert($0).inserted }.prefix(8))
    }
}

private struct SearchSuggestionsResponse: Decodable {
    let code: Int
    let result: Suggestions?
    let message: String?

    struct Suggestions: Decodable {
        let allMatch: [Match]?
    }

    struct Match: Decodable {
        let keyword: String
    }
}
