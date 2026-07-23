import Foundation
import GRDB

final class DownloadDatabase {
    private let databaseQueue: DatabaseQueue

    init(
        fileManager: FileManager = .default,
        databaseURL: URL? = nil
    ) throws {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let resolvedURL = databaseURL
            ?? applicationSupportURL
                .appending(path: "MeloX", directoryHint: .isDirectory)
                .appending(path: "Database", directoryHint: .isDirectory)
                .appending(path: "downloads.sqlite", directoryHint: .notDirectory)

        try fileManager.createDirectory(
            at: resolvedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        databaseQueue = try DatabaseQueue(path: resolvedURL.path)
        try migrate()

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = resolvedURL
        try? mutableURL.setResourceValues(resourceValues)
    }

    func fetchDownloads() throws -> [DownloadedSong] {
        try databaseQueue.read { database in
            try DownloadRecord
                .order(Column("downloadedAt").desc)
                .fetchAll(database)
                .map { try $0.downloadedSong() }
        }
    }

    func save(_ download: DownloadedSong) throws {
        let record = try DownloadRecord(download: download)
        try databaseQueue.write { database in
            try record.save(database)
        }
    }

    func removeDownload(songID: Int) throws {
        try databaseQueue.write { database in
            _ = try DownloadRecord.deleteOne(database, key: songID)
        }
    }

    func removeAllDownloads() throws {
        try databaseQueue.write { database in
            _ = try DownloadRecord.deleteAll(database)
        }
    }

    @discardableResult
    func recordPlayback(songID: Int) throws -> Int {
        try databaseQueue.write { database in
            try database.execute(
                sql: """
                INSERT INTO playbackCounts (songID, playCount)
                VALUES (?, 1)
                ON CONFLICT(songID) DO UPDATE SET playCount = playCount + 1
                """,
                arguments: [songID]
            )
            return try Int.fetchOne(
                database,
                sql: "SELECT playCount FROM playbackCounts WHERE songID = ?",
                arguments: [songID]
            ) ?? 0
        }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createDownloadStorage") { database in
            try database.create(table: DownloadRecord.databaseTableName) { table in
                table.column("songID", .integer).primaryKey()
                table.column("songJSON", .blob).notNull()
                table.column("fileName", .text).notNull()
                table.column("byteCount", .integer).notNull()
                table.column("bitrate", .integer)
                table.column("format", .text)
                table.column("quality", .text).notNull()
                table.column("downloadedAt", .datetime).notNull()
            }
            try database.create(table: "playbackCounts") { table in
                table.column("songID", .integer).primaryKey()
                table.column("playCount", .integer).notNull().defaults(to: 0)
            }
        }
        try migrator.migrate(databaseQueue)
    }
}

private struct DownloadRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "downloads"

    let songID: Int
    let songJSON: Data
    let fileName: String
    let byteCount: Int64
    let bitrate: Int?
    let format: String?
    let quality: String
    let downloadedAt: Date

    init(download: DownloadedSong) throws {
        songID = download.id
        songJSON = try JSONEncoder().encode(download.song)
        fileName = download.fileName
        byteCount = download.byteCount
        bitrate = download.bitrate
        format = download.format
        quality = download.quality.rawValue
        downloadedAt = download.downloadedAt
    }

    func downloadedSong() throws -> DownloadedSong {
        guard let quality = MusicQuality(rawValue: quality) else {
            throw DownloadDatabaseError.invalidQuality(quality)
        }
        return DownloadedSong(
            song: try JSONDecoder().decode(Song.self, from: songJSON),
            fileName: fileName,
            byteCount: byteCount,
            bitrate: bitrate,
            format: format,
            quality: quality,
            downloadedAt: downloadedAt
        )
    }
}

enum DownloadDatabaseError: LocalizedError {
    case unavailable
    case invalidQuality(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "下载数据库不可用。"
        case let .invalidQuality(quality):
            "下载记录包含无效音质：\(quality)"
        }
    }
}
