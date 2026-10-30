import Foundation

nonisolated struct ManagedStorageUsage: Equatable, Sendable {
    let downloadsBytes: Int64
    let networkCacheBytes: Int64
    let temporaryFilesBytes: Int64
    let databaseBytes: Int64
    let deviceTotalBytes: Int64?
    let deviceAvailableBytes: Int64?

    static let empty = ManagedStorageUsage(
        downloadsBytes: 0,
        networkCacheBytes: 0,
        temporaryFilesBytes: 0,
        databaseBytes: 0,
        deviceTotalBytes: nil,
        deviceAvailableBytes: nil
    )

    var totalManagedBytes: Int64 {
        downloadsBytes
            + networkCacheBytes
            + temporaryFilesBytes
            + databaseBytes
    }

    var reclaimableCacheBytes: Int64 {
        networkCacheBytes + temporaryFilesBytes
    }
}

enum StorageMaintenance {
    @MainActor
    static func usage() async -> ManagedStorageUsage {
        let networkCacheBytes = Int64(
            URLCache.shared.currentDiskUsage
        )
        let diskUsage = await measuredDiskUsage()
        return ManagedStorageUsage(
            downloadsBytes: diskUsage.downloadsBytes,
            networkCacheBytes: networkCacheBytes + diskUsage.pageContentCacheBytes,
            temporaryFilesBytes:
                diskUsage.temporaryFilesBytes,
            databaseBytes: diskUsage.databaseBytes,
            deviceTotalBytes: diskUsage.deviceTotalBytes,
            deviceAvailableBytes:
                diskUsage.deviceAvailableBytes
        )
    }

    @MainActor
    static func clearNetworkAndArtworkCaches() async {
        URLCache.shared.removeAllCachedResponses()
        ArtworkAccentColorProvider.clearCache()
        await PageContentCache.clear()
    }

    nonisolated static func clearTemporaryFiles(
        preservingDownloadTransfers: Bool
    ) async throws -> Int64 {
        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let beatDirectories =
                AppStorageLocations.beatAnalysisDirectories(
                    fileManager: fileManager
                )
            let preservedBeatDirectory =
                mostRecentlyModifiedURL(
                    in: beatDirectories
                )

            var candidates = beatDirectories.filter {
                $0 != preservedBeatDirectory
            }
            candidates.append(
                AppStorageLocations
                    .lyricsNotificationAttachmentDirectory(
                        fileManager: fileManager
                    )
            )
            if !preservingDownloadTransfers {
                candidates.append(
                    AppStorageLocations
                        .downloadTransferDirectory(
                            fileManager: fileManager
                        )
                )
            }
            if let legacyDirectory =
                AppStorageLocations
                    .legacyLyricsNotificationArtworkDirectory(
                        fileManager: fileManager
                    ) {
                candidates.append(legacyDirectory)
            }

            let byteCount = candidates.reduce(Int64(0)) {
                $0 + allocatedSize(
                    at: $1,
                    fileManager: fileManager
                )
            }
            var failures: [String] = []
            for url in candidates
            where fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    failures.append(
                        L10n.format(
                            "ui.settings.storage.error.file_detail",
                            url.lastPathComponent,
                            error.localizedDescription
                        )
                    )
                }
            }
            guard failures.isEmpty else {
                throw StorageMaintenanceError
                    .unableToRemove(failures)
            }
            return byteCount
        }.value
    }

    private nonisolated static func measuredDiskUsage()
        async -> MeasuredDiskUsage {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let downloadsBytes = allocatedSize(
                at:
                    AppStorageLocations.downloadsDirectory(
                        fileManager: fileManager
                    ),
                fileManager: fileManager
            )
            let databaseBytes = allocatedSize(
                at:
                    AppStorageLocations.databaseDirectory(
                        fileManager: fileManager
                    ),
                fileManager: fileManager
            )
            let pageContentCacheBytes = allocatedSize(
                at: AppStorageLocations.pageContentCacheDirectory(fileManager: fileManager),
                fileManager: fileManager
            )

            var temporaryURLs =
                AppStorageLocations.beatAnalysisDirectories(
                    fileManager: fileManager
                )
            temporaryURLs.append(
                AppStorageLocations
                    .lyricsNotificationAttachmentDirectory(
                        fileManager: fileManager
                    )
            )
            temporaryURLs.append(
                AppStorageLocations.downloadTransferDirectory(
                    fileManager: fileManager
                )
            )
            if let legacyDirectory =
                AppStorageLocations
                    .legacyLyricsNotificationArtworkDirectory(
                        fileManager: fileManager
                    ) {
                temporaryURLs.append(legacyDirectory)
            }
            let temporaryFilesBytes =
                temporaryURLs.reduce(Int64(0)) {
                    $0 + allocatedSize(
                        at: $1,
                        fileManager: fileManager
                    )
                }

            let capacityValues = try? URL(
                fileURLWithPath: NSHomeDirectory()
            ).resourceValues(
                forKeys: [
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityForImportantUsageKey,
                ]
            )

            return MeasuredDiskUsage(
                downloadsBytes: downloadsBytes,
                temporaryFilesBytes: temporaryFilesBytes,
                databaseBytes: databaseBytes,
                pageContentCacheBytes: pageContentCacheBytes,
                deviceTotalBytes:
                    capacityValues?.volumeTotalCapacity
                        .map(Int64.init),
                deviceAvailableBytes:
                    capacityValues?
                        .volumeAvailableCapacityForImportantUsage
            )
        }.value
    }

    private nonisolated static func allocatedSize(
        at url: URL,
        fileManager: FileManager
    ) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else {
            return 0
        }

        let keys: Set<URLResourceKey> = [
            .fileAllocatedSizeKey,
            .fileSizeKey,
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
        ]
        if let values = try? url.resourceValues(
            forKeys: keys
        ),
           values.isRegularFile == true {
            return Int64(
                values.totalFileAllocatedSize
                    ?? values.fileAllocatedSize
                    ?? values.fileSize
                    ?? 0
            )
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        var total = Int64(0)
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(
                forKeys: keys
            ),
                values.isRegularFile == true else {
                continue
            }
            total += Int64(
                values.totalFileAllocatedSize
                    ?? values.fileAllocatedSize
                    ?? values.fileSize
                    ?? 0
            )
        }
        return total
    }

    private nonisolated static func mostRecentlyModifiedURL(
        in urls: [URL]
    ) -> URL? {
        urls.max {
            let lhsDate = (
                try? $0.resourceValues(
                    forKeys: [.contentModificationDateKey]
                )
            )?.contentModificationDate ?? .distantPast
            let rhsDate = (
                try? $1.resourceValues(
                    forKeys: [.contentModificationDateKey]
                )
            )?.contentModificationDate ?? .distantPast
            return lhsDate < rhsDate
        }
    }
}

private nonisolated struct MeasuredDiskUsage: Sendable {
    let downloadsBytes: Int64
    let temporaryFilesBytes: Int64
    let databaseBytes: Int64
    let pageContentCacheBytes: Int64
    let deviceTotalBytes: Int64?
    let deviceAvailableBytes: Int64?
}

nonisolated enum StorageMaintenanceError:
    LocalizedError,
    Sendable {
    case unableToRemove([String])

    var errorDescription: String? {
        switch self {
        case .unableToRemove(let failures):
            L10n.format(
                "ui.error.storage.partial_cleanup",
                failures.joined(separator: L10n.string("ui.common.list_separator"))
            )
        }
    }
}
