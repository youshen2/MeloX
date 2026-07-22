// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Native rendering cache added under the PV Tool Non-Commercial License.

import SwiftUI

final class TextPVPathCache: @unchecked Sendable {
    static let shared = TextPVPathCache()

    private let paths = NSCache<NSString, TextPVPathBox>()
    private let pathPairs = NSCache<NSString, TextPVPathPairBox>()

    private init() {
        paths.countLimit = 96
        pathPairs.countLimit = 32
    }

    func path(for key: String, make: () -> Path) -> Path {
        let cacheKey = key as NSString
        if let cached = paths.object(forKey: cacheKey) {
            return cached.path
        }

        let path = make()
        paths.setObject(TextPVPathBox(path), forKey: cacheKey)
        return path
    }

    func pair(for key: String, make: () -> (Path, Path)) -> (Path, Path) {
        let cacheKey = key as NSString
        if let cached = pathPairs.object(forKey: cacheKey) {
            return (cached.first, cached.second)
        }

        let pair = make()
        pathPairs.setObject(
            TextPVPathPairBox(first: pair.0, second: pair.1),
            forKey: cacheKey
        )
        return pair
    }
}

private final class TextPVPathBox {
    let path: Path

    init(_ path: Path) {
        self.path = path
    }
}

private final class TextPVPathPairBox {
    let first: Path
    let second: Path

    init(first: Path, second: Path) {
        self.first = first
        self.second = second
    }
}
