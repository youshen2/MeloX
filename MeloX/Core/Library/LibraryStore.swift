import Foundation
import Observation

@MainActor
@Observable
final class LibraryStore {
    private(set) var profile: AccountProfile?
    private(set) var favoriteSongs: [Song] = []
    private(set) var favoritePlaylists: [Playlist] = []
    private(set) var recentSongs: [Song] = []
    private(set) var phase: LoadingPhase = .loaded
    private(set) var errorMessage: String?

    @ObservationIgnored
    private let api: NeteaseAPI

    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private var loadedCookie: String?

    @ObservationIgnored
    private var refreshingCookie: String?

    init(api: NeteaseAPI, settings: AppSettings) {
        self.api = api
        self.settings = settings
    }

    var isLoggedIn: Bool {
        !settings.cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var ownedPlaylists: [Playlist] {
        guard let userID = profile?.id else { return [] }
        return favoritePlaylists.filter { $0.creator?.userID == userID }
    }

    func contains(song: Song) -> Bool {
        favoriteSongs.contains { $0.id == song.id }
    }

    func contains(playlist: Playlist) -> Bool {
        favoritePlaylists.contains { $0.id == playlist.id }
    }

    func canUnsubscribe(_ playlist: Playlist) -> Bool {
        playlist.creator?.userID != profile?.id
    }

    func refresh(force: Bool = false) async {
        let cookie = settings.cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cookie.isEmpty else {
            clearAccountData()
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
            let loadedProfile = try await api.accountProfile()
            try Task.checkCancellation()

            profile = loadedProfile
            loadedCookie = cookie

            var partialFailures: [String] = []
            var loadedPlaylists: [Playlist] = []
            do {
                loadedPlaylists = try await api.userPlaylists(userID: loadedProfile.id)
                // 网易云把“我喜欢的音乐”作为返回列表的第一项；参考项目
                // 同样在歌单页隐藏这一项，歌曲页单独展示其中的歌曲。
                favoritePlaylists = Array(loadedPlaylists.dropFirst())
            } catch is CancellationError {
                return
            } catch {
                partialFailures.append("歌单：\(error.localizedDescription)")
            }

            do {
                let likedPlaylistID = loadedPlaylists.first?.id
                favoriteSongs = try await api.likedSongs(
                    userID: loadedProfile.id,
                    likedPlaylistID: likedPlaylistID
                )
            } catch is CancellationError {
                return
            } catch {
                partialFailures.append("收藏歌曲：\(error.localizedDescription)")
            }

            do {
                recentSongs = try await api.recentSongs()
            } catch is CancellationError {
                return
            } catch {
                partialFailures.append("播放历史：\(error.localizedDescription)")
            }

            if !partialFailures.isEmpty {
                errorMessage = "部分音乐库内容暂时无法读取。\n" + partialFailures.joined(separator: "\n")
            }
            phase = .loaded
        } catch is CancellationError {
            return
        } catch APIError.notLoggedIn {
            settings.clearAccount()
            clearAccountData()
        } catch {
            if profile == nil {
                phase = .failed(error.localizedDescription)
            } else {
                phase = .loaded
                errorMessage = "账号刷新失败：\(error.localizedDescription)"
            }
        }
    }

    func toggle(song: Song) {
        guard isLoggedIn else {
            errorMessage = APIError.notLoggedIn.localizedDescription
            return
        }

        let wasLiked = contains(song: song)
        if wasLiked {
            favoriteSongs.removeAll { $0.id == song.id }
        } else {
            favoriteSongs.insert(song, at: 0)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.api.setSongLiked(id: song.id, isLiked: !wasLiked)
            } catch {
                if wasLiked {
                    self.favoriteSongs.insert(song, at: 0)
                } else {
                    self.favoriteSongs.removeAll { $0.id == song.id }
                }
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func toggle(playlist: Playlist) {
        guard isLoggedIn else {
            errorMessage = APIError.notLoggedIn.localizedDescription
            return
        }

        let wasSubscribed = contains(playlist: playlist)
        guard !wasSubscribed || canUnsubscribe(playlist) else { return }
        if wasSubscribed {
            favoritePlaylists.removeAll { $0.id == playlist.id }
        } else {
            var summary = playlist
            summary.tracks = []
            favoritePlaylists.insert(summary, at: 0)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.api.setPlaylistSubscribed(
                    id: playlist.id,
                    isSubscribed: !wasSubscribed
                )
            } catch {
                if wasSubscribed {
                    self.favoritePlaylists.insert(playlist, at: 0)
                } else {
                    self.favoritePlaylists.removeAll { $0.id == playlist.id }
                }
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func add(song: Song, to playlist: Playlist) async throws {
        guard isLoggedIn else { throw APIError.notLoggedIn }
        guard playlist.creator?.userID == profile?.id else {
            throw LibraryOperationError.playlistIsNotOwned
        }
        try await api.addSong(id: song.id, toPlaylistID: playlist.id)
    }

    func clearAccountData() {
        loadedCookie = nil
        clearRemoteContent()
        phase = .loaded
        errorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private func clearRemoteContent() {
        profile = nil
        favoriteSongs = []
        favoritePlaylists = []
        recentSongs = []
    }
}

private enum LibraryOperationError: LocalizedError {
    case playlistIsNotOwned

    var errorDescription: String? {
        switch self {
        case .playlistIsNotOwned:
            "只能向自己创建的歌单添加歌曲。"
        }
    }
}
