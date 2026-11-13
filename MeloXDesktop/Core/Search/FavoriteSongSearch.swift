import Foundation

nonisolated enum FavoriteSongSearch {
    static func matches(
        query: String,
        title: String,
        artist: String,
        album: String?
    ) -> Bool {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        let fields = [title, artist] + [album].compactMap { $0 }
        return terms.allSatisfy { term in
            fields.contains {
                $0.range(
                    of: term,
                    options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                    locale: .current
                ) != nil
            }
        }
    }
}
