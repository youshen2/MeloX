import Foundation

struct SongCollectionPage {
    let songs: [Song]
    let nextOffset: Int
    let totalCount: Int

    var hasMore: Bool {
        nextOffset < totalCount
    }
}
