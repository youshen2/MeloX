import Foundation
import Observation

@MainActor
@Observable
final class StorageManagementModel {
    private(set) var usage = ManagedStorageUsage.empty
    private(set) var hasLoadedUsage = false
    private(set) var isRefreshing = false
    private(set) var activeOperation: StorageCleanupAction?
    var confirmation: StorageCleanupAction?
    private(set) var operationMessage: String?
    var errorMessage: String?

    var isBusy: Bool {
        activeOperation != nil
    }

    func refreshUsage() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            hasLoadedUsage = true
        }

        let measuredUsage = await StorageMaintenance.usage()
        guard !Task.isCancelled else { return }
        usage = measuredUsage
    }

    func perform(
        _ action: StorageCleanupAction,
        downloads: DownloadStore,
        player: PlayerStore
    ) async {
        guard activeOperation == nil else { return }
        activeOperation = action
        operationMessage = nil
        downloads.clearError()

        defer {
            activeOperation = nil
        }
        do {
            switch action {
            case .allCaches:
                let networkBytes = usage.networkCacheBytes
                await StorageMaintenance.clearNetworkAndArtworkCaches()
                await player.clearPlaybackAnalysisCache()
                let temporaryBytes =
                    try await StorageMaintenance
                        .clearTemporaryFiles(
                            preservingDownloadTransfers:
                                !downloads.activeDownloads.isEmpty
                        )
                operationMessage = L10n.format(
                    "ui.settings.storage.operation.cleared_approximately",
                    formattedSize(networkBytes + temporaryBytes)
                )

            case .networkCache:
                let byteCount = usage.networkCacheBytes
                await StorageMaintenance.clearNetworkAndArtworkCaches()
                operationMessage = L10n.format(
                    "ui.settings.storage.operation.cleared_network_cache",
                    formattedSize(byteCount)
                )

            case .temporaryFiles:
                await player.clearPlaybackAnalysisCache()
                let byteCount =
                    try await StorageMaintenance
                        .clearTemporaryFiles(
                            preservingDownloadTransfers:
                                !downloads.activeDownloads.isEmpty
                        )
                operationMessage = L10n.format(
                    "ui.settings.storage.operation.cleared_temporary_files",
                    formattedSize(byteCount)
                )

            case .repairDownloads:
                let result = downloads.repairStorage()
                try checkDownloadOperation(downloads)
                operationMessage =
                    repairMessage(for: result)

            case .automaticCacheHistory:
                downloads.resetAutomaticCacheHistory()
                try checkDownloadOperation(downloads)
                operationMessage = L10n.string("ui.settings.storage.operation.reset_cache_history")

            case .optimizeDatabase:
                downloads.optimizeStorageDatabase()
                try checkDownloadOperation(downloads)
                operationMessage = L10n.string("ui.settings.storage.operation.database_optimized")

            case .allDownloads:
                let count = downloads.downloads.count
                downloads.removeAll()
                try checkDownloadOperation(downloads)
                operationMessage = L10n.format("ui.settings.storage.operation.deleted_songs", count)
            }

            await refreshUsage()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            await refreshUsage()
        }
    }

    private func checkDownloadOperation(
        _ downloads: DownloadStore
    ) throws {
        guard let message = downloads.errorMessage else {
            return
        }
        downloads.clearError()
        throw StorageManagementError(message: message)
    }

    private func formattedSize(_ byteCount: Int64) -> String {
        L10n.byteCount(byteCount)
    }

    private func repairMessage(
        for result: DownloadStorageRepairResult
    ) -> String {
        guard result.repairedAnything else {
            return L10n.string("ui.settings.storage.operation.repair_no_issues")
        }

        var repairs: [String] = []
        if result.removedMissingRecordCount > 0 {
            repairs.append(
                L10n.format(
                    "ui.settings.storage.operation.removed_records",
                    result.removedMissingRecordCount
                )
            )
        }
        if result.removedUntrackedByteCount > 0 {
            repairs.append(
                L10n.format(
                    "ui.settings.storage.operation.removed_untracked_files",
                    formattedSize(result.removedUntrackedByteCount)
                )
            )
        }
        return repairs.joined(separator: L10n.string("ui.common.list_separator"))
    }
}

enum StorageCleanupAction: String, Identifiable {
    case allCaches
    case networkCache
    case temporaryFiles
    case repairDownloads
    case automaticCacheHistory
    case optimizeDatabase
    case allDownloads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allCaches:
            L10n.string("ui.settings.storage.confirm.clear_all_caches.title")
        case .networkCache:
            L10n.string("ui.settings.storage.confirm.clear_network_cache.title")
        case .temporaryFiles:
            L10n.string("ui.settings.storage.confirm.clear_temporary_files.title")
        case .repairDownloads:
            L10n.string("ui.settings.storage.confirm.repair_downloads.title")
        case .automaticCacheHistory:
            L10n.string("ui.settings.storage.confirm.reset_cache_history.title")
        case .optimizeDatabase:
            L10n.string("ui.settings.storage.confirm.optimize_database.title")
        case .allDownloads:
            L10n.string("ui.settings.storage.confirm.delete_all_downloads.title")
        }
    }

    var confirmButtonTitle: String {
        switch self {
        case .repairDownloads:
            L10n.string("ui.settings.storage.confirm.repair")
        case .automaticCacheHistory:
            L10n.string("ui.settings.storage.confirm.reset_count")
        case .allDownloads:
            L10n.string("ui.settings.storage.delete_all_downloads")
        default:
            L10n.string("ui.settings.storage.confirm.clean_now")
        }
    }

    var confirmationMessage: String {
        switch self {
        case .allCaches:
            L10n.string("ui.settings.storage.confirm.clear_all_caches.message")
        case .networkCache:
            L10n.string("ui.settings.storage.confirm.clear_network_cache.message")
        case .temporaryFiles:
            L10n.string("ui.settings.storage.confirm.clear_temporary_files.message")
        case .repairDownloads:
            L10n.string("ui.settings.storage.confirm.repair_downloads.message")
        case .automaticCacheHistory:
            L10n.string("ui.settings.storage.confirm.reset_cache_history.message")
        case .optimizeDatabase:
            L10n.string("ui.settings.storage.confirm.optimize_database.message")
        case .allDownloads:
            L10n.string("ui.settings.storage.confirm.delete_all_downloads.message")
        }
    }
}

private struct StorageManagementError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
