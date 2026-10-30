import Foundation

enum AppStorageLocations {
    nonisolated static let rootDirectoryName = "MeloX"
    nonisolated static let downloadTransferDirectoryName =
        "MeloXDownloadTransfers"
    nonisolated static let beatAnalysisDirectoryPrefix =
        "MeloX-BeatNet-"
    nonisolated static let lyricsNotificationAttachmentDirectoryName =
        "LyricsNotificationAttachments"
    nonisolated static let legacyLyricsNotificationArtworkDirectoryName =
        "LyricsNotificationArtwork"

    nonisolated static func applicationSupportRoot(
        fileManager: FileManager = .default
    ) -> URL {
        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return baseURL.appending(
            path: rootDirectoryName,
            directoryHint: .isDirectory
        )
    }

    nonisolated static func downloadsDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        applicationSupportRoot(fileManager: fileManager)
            .appending(
                path: "Downloads",
                directoryHint: .isDirectory
            )
    }

    nonisolated static func databaseDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        applicationSupportRoot(fileManager: fileManager)
            .appending(
                path: "Database",
                directoryHint: .isDirectory
            )
    }

    nonisolated static func pageContentCacheDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory
        return baseURL.appending(path: rootDirectoryName, directoryHint: .isDirectory)
            .appending(path: "PageContent", directoryHint: .isDirectory)
    }

    nonisolated static func downloadDatabaseURL(
        fileManager: FileManager = .default
    ) -> URL {
        databaseDirectory(fileManager: fileManager)
            .appending(
                path: "downloads.sqlite",
                directoryHint: .notDirectory
            )
    }

    nonisolated static func downloadTransferDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        fileManager.temporaryDirectory.appending(
            path: downloadTransferDirectoryName,
            directoryHint: .isDirectory
        )
    }

    nonisolated static func lyricsNotificationAttachmentDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        fileManager.temporaryDirectory.appending(
            path: lyricsNotificationAttachmentDirectoryName,
            directoryHint: .isDirectory
        )
    }

    nonisolated static func legacyLyricsNotificationArtworkDirectory(
        fileManager: FileManager = .default
    ) -> URL? {
        fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first?.appending(
            path: legacyLyricsNotificationArtworkDirectoryName,
            directoryHint: .isDirectory
        )
    }

    nonisolated static func beatAnalysisDirectories(
        fileManager: FileManager = .default
    ) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: fileManager.temporaryDirectory,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .isDirectoryKey,
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.filter {
            guard $0.lastPathComponent.hasPrefix(
                beatAnalysisDirectoryPrefix
            ) else {
                return false
            }
            let values = try? $0.resourceValues(
                forKeys: [.isDirectoryKey]
            )
            return values?.isDirectory == true
        }
    }
}
