import Foundation
import Observation

@MainActor
@Observable
final class DownloadStore {
    private(set) var downloads: [DownloadedSong]
    private(set) var activeDownloads: [Int: ActiveSongDownload] = [:]
    private(set) var errorMessage: String?

    var activeSongs: [Int: Song] {
        activeDownloads.mapValues(\.song)
    }

    var downloadedSongs: [Song] {
        downloads.map(\.song)
    }

    var totalByteCount: Int64 {
        downloads.reduce(0) { $0 + $1.byteCount }
    }

    @ObservationIgnored
    private let api: NeteaseAPI

    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private let storage: DownloadStorage

    @ObservationIgnored
    private let transferClient: DownloadTransferClient

    @ObservationIgnored
    private let database: DownloadDatabase?

    @ObservationIgnored
    private var tasks: [Int: Task<Void, Never>] = [:]

    init(
        api: NeteaseAPI,
        settings: AppSettings,
        storage: DownloadStorage? = nil,
        transferClient: DownloadTransferClient? = nil,
        database: DownloadDatabase? = nil
    ) {
        let storage = storage ?? DownloadStorage()
        self.api = api
        self.settings = settings
        self.storage = storage
        self.transferClient = transferClient ?? DownloadTransferClient()

        var resolvedDatabase: DownloadDatabase?
        var resolvedDownloads: [DownloadedSong] = []
        var initialErrorMessage: String?
        do {
            let openedDatabase: DownloadDatabase
            if let database {
                openedDatabase = database
            } else {
                openedDatabase = try DownloadDatabase()
            }

            let storedDownloads = try openedDatabase.fetchDownloads()
            resolvedDownloads = storedDownloads.filter {
                storage.containsFile(named: $0.fileName)
            }
            let missingSongIDs = Set(storedDownloads.map(\.id))
                .subtracting(resolvedDownloads.map(\.id))
            for songID in missingSongIDs {
                try openedDatabase.removeDownload(songID: songID)
            }
            resolvedDatabase = openedDatabase
        } catch {
            initialErrorMessage = "无法打开下载数据库：\(error.localizedDescription)"
        }

        self.database = resolvedDatabase
        downloads = resolvedDownloads
        errorMessage = initialErrorMessage
    }

    func contains(songID: Int) -> Bool {
        downloads.contains { $0.id == songID }
    }

    func isDownloading(songID: Int) -> Bool {
        activeDownloads[songID] != nil
    }

    func localPlaybackSource(songID: Int) -> PlaybackSource? {
        guard let download = downloads.first(where: { $0.id == songID }) else {
            return nil
        }
        guard storage.containsFile(named: download.fileName) else {
            removeMissingDownload(songID: songID)
            return nil
        }
        return PlaybackSource(
            url: storage.fileURL(fileName: download.fileName),
            bitrate: download.bitrate,
            format: download.format
        )
    }

    func start(_ song: Song, quality: MusicQuality) {
        guard database != nil else {
            errorMessage = DownloadDatabaseError.unavailable.localizedDescription
            return
        }
        guard !contains(songID: song.id), !isDownloading(songID: song.id) else { return }
        errorMessage = nil
        activeDownloads[song.id] = ActiveSongDownload(
            song: song,
            quality: quality,
            receivedByteCount: 0,
            expectedByteCount: nil
        )
        tasks[song.id] = Task { [weak self] in
            await self?.download(song, quality: quality)
        }
    }

    func recordPlayback(_ song: Song) {
        do {
            guard let database else { return }
            let count = try database.recordPlayback(songID: song.id)
            guard settings.automaticallyCachesFrequentlyPlayedSongs,
                  count >= settings.automaticCachePlaybackThreshold,
                  !contains(songID: song.id),
                  !isDownloading(songID: song.id) else {
                return
            }
            start(song, quality: settings.automaticCacheQuality)
        } catch {
            errorMessage = "无法记录歌曲播放次数：\(error.localizedDescription)"
        }
    }

    func cancel(songID: Int) {
        tasks[songID]?.cancel()
        tasks[songID] = nil
        activeDownloads[songID] = nil
    }

    func remove(songID: Int) {
        cancel(songID: songID)
        guard let index = downloads.firstIndex(where: { $0.id == songID }) else { return }
        let download = downloads[index]
        do {
            guard let database else { throw DownloadDatabaseError.unavailable }
            try database.removeDownload(songID: songID)
            downloads.remove(at: index)
            try storage.removeFile(named: download.fileName)
        } catch {
            errorMessage = "无法删除已下载歌曲：\(error.localizedDescription)"
        }
    }

    func discardInvalidDownload(songID: Int) {
        cancel(songID: songID)
        guard let index = downloads.firstIndex(where: { $0.id == songID }) else { return }
        let download = downloads.remove(at: index)

        var failures: [String] = []
        do {
            guard let database else { throw DownloadDatabaseError.unavailable }
            try database.removeDownload(songID: songID)
        } catch {
            failures.append(error.localizedDescription)
        }
        do {
            try storage.removeFile(named: download.fileName)
        } catch {
            failures.append(error.localizedDescription)
        }

        if !failures.isEmpty {
            errorMessage = "本地歌曲已失效，部分缓存清理失败：\(failures.joined(separator: "；"))"
        }
    }

    func removeAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        activeDownloads.removeAll()
        do {
            guard let database else { throw DownloadDatabaseError.unavailable }
            try database.removeAllDownloads()
            downloads.removeAll()
            try storage.removeAllFiles()
        } catch {
            errorMessage = "无法清除下载内容：\(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func download(_ song: Song, quality: MusicQuality) async {
        defer {
            tasks[song.id] = nil
            activeDownloads[song.id] = nil
        }

        do {
            let source = try await api.downloadSource(id: song.id, quality: quality)
            try Task.checkCancellation()
            let transfer = try await transferClient.download(from: source.url) { [weak self] progress in
                self?.updateProgress(progress, songID: song.id)
            }
            let temporaryURL = transfer.temporaryURL
            defer { try? FileManager.default.removeItem(at: temporaryURL) }
            try Task.checkCancellation()
            guard let httpResponse = transfer.response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw DownloadError.invalidResponse
            }

            let installed = try storage.installDownloadedFile(
                from: temporaryURL,
                songID: song.id,
                format: source.format,
                sourceURL: source.url
            )

            let completedDownload = DownloadedSong(
                song: song,
                fileName: installed.fileName,
                byteCount: installed.byteCount,
                bitrate: source.bitrate,
                format: source.format,
                quality: quality,
                downloadedAt: Date()
            )
            do {
                guard let database else { throw DownloadDatabaseError.unavailable }
                try database.save(completedDownload)
                downloads.removeAll { $0.id == song.id }
                downloads.insert(completedDownload, at: 0)
            } catch {
                try? storage.removeFile(named: installed.fileName)
                throw error
            }
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            errorMessage = "《\(song.name)》下载失败：\(error.localizedDescription)"
        }
    }

    private func removeMissingDownload(songID: Int) {
        downloads.removeAll { $0.id == songID }
        do {
            guard let database else { throw DownloadDatabaseError.unavailable }
            try database.removeDownload(songID: songID)
        } catch {
            errorMessage = "无法更新下载记录：\(error.localizedDescription)"
        }
    }

    private func updateProgress(
        _ progress: DownloadTransferProgress,
        songID: Int
    ) {
        guard var download = activeDownloads[songID] else { return }
        download.receivedByteCount = progress.receivedByteCount
        download.expectedByteCount = progress.expectedByteCount
        activeDownloads[songID] = download
    }
}
