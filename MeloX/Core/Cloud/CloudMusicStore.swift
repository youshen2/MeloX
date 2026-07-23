import Foundation
import Observation

@MainActor
@Observable
final class CloudMusicStore {
    private(set) var items: [CloudSong] = []
    private(set) var phase: LoadingPhase = .loaded
    private(set) var totalCount = 0
    private(set) var usedSize: Int64 = 0
    private(set) var maxSize: Int64 = 0
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    private(set) var isUploading = false
    private(set) var deletingSongIDs: Set<Int> = []
    private(set) var errorMessage: String?

    @ObservationIgnored
    private let api: NeteaseAPI

    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private var loadedCookie: String?

    @ObservationIgnored
    private var refreshingCookie: String?

    private let pageSize = 200

    init(api: NeteaseAPI, settings: AppSettings) {
        self.api = api
        self.settings = settings
    }

    var songs: [Song] {
        items.map(\.simpleSong)
    }

    var quotaDescription: String? {
        guard maxSize > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "已使用 \(formatter.string(fromByteCount: usedSize))，共 \(formatter.string(fromByteCount: maxSize))"
    }

    func refresh(force: Bool = false) async {
        let cookie = settings.cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cookie.isEmpty else {
            clear()
            return
        }
        guard refreshingCookie != cookie else { return }
        guard force || loadedCookie != cookie || phase != .loaded else { return }

        if loadedCookie != cookie {
            clearRemoteContent()
        }
        refreshingCookie = cookie
        defer {
            if refreshingCookie == cookie {
                refreshingCookie = nil
            }
        }
        phase = .loading
        errorMessage = nil

        do {
            let page = try await api.cloudSongs(limit: pageSize)
            try Task.checkCancellation()
            apply(page, replacing: true)
            loadedCookie = cookie
            phase = .loaded
        } catch is CancellationError {
            return
        } catch APIError.notLoggedIn {
            clear()
        } catch {
            if items.isEmpty {
                phase = .failed(error.localizedDescription)
            } else {
                phase = .loaded
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadMoreIfNeeded(after item: CloudSong) async {
        guard item.id == items.last?.id, hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await api.cloudSongs(limit: pageSize, offset: items.count)
            try Task.checkCancellation()
            apply(page, replacing: false)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upload(fileAt url: URL) async {
        guard !isUploading else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        do {
            try await api.uploadCloudSong(fileAt: url)
            loadedCookie = nil
            await refresh(force: true)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "上传失败：\(error.localizedDescription)"
        }
    }

    func delete(_ item: CloudSong) async {
        guard !deletingSongIDs.contains(item.id) else { return }
        deletingSongIDs.insert(item.id)
        defer { deletingSongIDs.remove(item.id) }

        do {
            try await api.deleteCloudSong(id: item.id)
            items.removeAll { $0.id == item.id }
            totalCount = max(totalCount - 1, 0)
            usedSize = max(usedSize - item.fileSize, 0)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func isDeleting(_ item: CloudSong) -> Bool {
        deletingSongIDs.contains(item.id)
    }

    func reportImportError(_ error: Error) {
        errorMessage = "无法读取所选文件：\(error.localizedDescription)"
    }

    func clearError() {
        errorMessage = nil
    }

    private func apply(_ page: CloudMusicPage, replacing: Bool) {
        if replacing {
            items = page.data
        } else {
            let existingIDs = Set(items.map(\.id))
            items.append(contentsOf: page.data.filter { !existingIDs.contains($0.id) })
        }
        totalCount = page.count
        usedSize = page.size
        maxSize = page.maxSize
        hasMore = page.hasMore && items.count < page.count
    }

    private func clear() {
        loadedCookie = nil
        refreshingCookie = nil
        clearRemoteContent()
        phase = .loaded
        errorMessage = nil
    }

    private func clearRemoteContent() {
        items = []
        totalCount = 0
        usedSize = 0
        maxSize = 0
        hasMore = false
    }
}
