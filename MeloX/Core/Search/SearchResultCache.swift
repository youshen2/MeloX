import Foundation

/// Keeps the current keyword's categories in memory for the search session.
struct SearchResultCache {
    private var keyword: String?
    private var payloads: [SearchKind: SearchPayload] = [:]

    mutating func value(for keyword: String, kind: SearchKind) -> SearchPayload? {
        if self.keyword != keyword {
            self.keyword = keyword
            payloads.removeAll(keepingCapacity: true)
        }
        return payloads[kind]
    }

    mutating func insert(_ payload: SearchPayload, for keyword: String, kind: SearchKind) {
        guard self.keyword == keyword else { return }
        payloads[kind] = payload
    }

    mutating func clear() {
        keyword = nil
        payloads.removeAll(keepingCapacity: true)
    }
}
