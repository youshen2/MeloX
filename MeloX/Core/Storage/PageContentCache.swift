import CryptoKit
import Foundation
import GRDB

@MainActor
final class PageContentCache {
    private let settings: AppSettings
    private let storage: PageContentCacheStorage

    init(settings: AppSettings, directory: URL? = nil) {
        self.settings = settings
        storage = directory.map { PageContentCacheStorage(directory: $0) } ?? .shared
    }

    func value<Value: Decodable>(for key: String) async -> Value? {
        guard settings.automaticallyCachesPageContent else { return nil }
        let scope = Self.scope(for: settings.cookie)
        guard let data = await storage.data(scope: scope, key: key),
              !Task.isCancelled,
              settings.automaticallyCachesPageContent,
              scope == Self.scope(for: settings.cookie) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func store<Value: Encodable>(_ value: Value, for key: String) async {
        guard settings.automaticallyCachesPageContent,
              !Task.isCancelled,
              let data = try? JSONEncoder().encode(value) else { return }
        await storage.store(data, scope: Self.scope(for: settings.cookie), key: key)
    }

    func removeAccount(cookie: String) async {
        await storage.remove(scope: Self.scope(for: cookie))
    }

    static func clear() async {
        await PageContentCacheStorage.shared.removeAll()
    }

    private static func scope(for cookie: String) -> String {
        let cookie = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        return SHA256.hash(data: Data(cookie.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}

private actor PageContentCacheStorage {
    static let shared = PageContentCacheStorage()
    private let database: DatabaseQueue?

    init(directory: URL = AppStorageLocations.pageContentCacheDirectory()) {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let database = try DatabaseQueue(
                path: directory.appending(path: "content.sqlite").path
            )
            try database.write { db in
                try db.execute(sql: """
                    CREATE TABLE IF NOT EXISTS pageContent (
                        scope TEXT NOT NULL,
                        cacheKey TEXT NOT NULL,
                        payload BLOB NOT NULL,
                        updatedAt DOUBLE NOT NULL,
                        PRIMARY KEY (scope, cacheKey)
                    )
                    """)
            }
            self.database = database
        } catch {
            database = nil
        }
    }

    func data(scope: String, key: String) -> Data? {
        try? database?.read { db in
            try Data.fetchOne(
                db,
                sql: "SELECT payload FROM pageContent WHERE scope = ? AND cacheKey = ?",
                arguments: [scope, key]
            )
        }
    }

    func store(_ data: Data, scope: String, key: String) {
        try? database?.write { db in
            try db.execute(
                sql: """
                    INSERT INTO pageContent (scope, cacheKey, payload, updatedAt)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(scope, cacheKey) DO UPDATE SET
                        payload = excluded.payload, updatedAt = excluded.updatedAt
                    """,
                arguments: [scope, key, data, Date().timeIntervalSince1970]
            )
            try db.execute(sql: """
                DELETE FROM pageContent WHERE rowid NOT IN (
                    SELECT rowid FROM pageContent ORDER BY updatedAt DESC LIMIT 256
                )
                """)
        }
    }

    func remove(scope: String) {
        try? database?.write { db in
            try db.execute(sql: "DELETE FROM pageContent WHERE scope = ?", arguments: [scope])
        }
    }

    func removeAll() {
        try? database?.write { db in
            try db.execute(sql: "DELETE FROM pageContent")
        }
        try? database?.vacuum()
    }
}
