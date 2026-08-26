import Foundation
import Observation

@MainActor
@Observable
final class LibraryStore {
    private(set) var profile: AccountProfile?
    private(set) var accountDetail: AccountDetail?
    private(set) var favoriteSongs: [Song] = []
    private(set) var favoritePlaylists: [Playlist] = []
    private(set) var favoriteAlbums: [Album] = []
    private(set) var favoriteArtists: [Artist] = []
    private(set) var subscribedPodcasts: [Podcast] = []
    private(set) var recentSongs: [Song] = []
    private(set) var likedPlaylistID: Int?
    private(set) var favoriteSongTotalCount = 0
    private(set) var favoriteSongsNextOffset = 0
    private(set) var isLoadingMoreFavoriteSongs = false
    private(set) var favoriteSongsLoadMoreError: String?
    private(set) var subscribedPodcastTotalCount = 0
    private(set) var subscribedPodcastsNextOffset = 0
    private(set) var hasMoreSubscribedPodcasts = false
    private(set) var isLoadingMoreSubscribedPodcasts = false
    private(set) var subscribedPodcastsLoadMoreError: String?
    private(set) var phase: LoadingPhase = .loaded
    private(set) var errorMessage: String?
    private(set) var operationErrorMessage: String?

    @ObservationIgnored
    private let api: NeteaseAPI

    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private var loadedCookie: String?

    @ObservationIgnored
    private var refreshingCookie: String?

    @ObservationIgnored
    private var favoriteSongIDs: [Int] = []

    private var favoriteSongIDSet: Set<Int> = []

    @ObservationIgnored
    private let favoriteSongPageSize = 100

    @ObservationIgnored
    private var favoriteSongPageLoadTask: Task<Void, Never>?

    @ObservationIgnored
    private var favoriteSongPageLoadID: UUID?

    @ObservationIgnored
    private let subscribedPodcastPageSize = 50

    @ObservationIgnored
    private var subscribedPodcastPageLoadTask: Task<Void, Never>?

    @ObservationIgnored
    private var subscribedPodcastPageLoadID: UUID?

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

    var hasMoreFavoriteSongs: Bool {
        favoriteSongsNextOffset < favoriteSongTotalCount
    }

    var canStartHeartMode: Bool {
        likedPlaylistID != nil && favoriteSongTotalCount > 0
    }

    func randomHeartModeSeedSongID() -> Int? {
        favoriteSongIDs.randomElement()
    }

    func contains(song: Song) -> Bool {
        favoriteSongIDSet.contains(song.id)
    }

    func contains(playlist: Playlist) -> Bool {
        favoritePlaylists.contains { $0.id == playlist.id }
    }

    func contains(album: Album) -> Bool {
        favoriteAlbums.contains { $0.id == album.id }
    }

    func contains(artist: Artist) -> Bool {
        favoriteArtists.contains { $0.id == artist.id }
    }

    func contains(podcast: Podcast) -> Bool {
        subscribedPodcasts.contains { $0.id == podcast.id }
    }

    func recordRecentlyPlayed(_ song: Song) {
        guard settings.isContentFeatureEnabled(.listeningHistory) else {
            return
        }
        recentSongs.removeAll { $0.id == song.id }
        recentSongs.insert(song, at: 0)
        if recentSongs.count > 100 {
            recentSongs.removeLast(recentSongs.count - 100)
        }
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
        favoriteSongsLoadMoreError = nil
        subscribedPodcastsLoadMoreError = nil

        do {
            let loadedProfile = try await api.accountProfile()
            try Task.checkCancellation()

            profile = loadedProfile
            loadedCookie = cookie

            var partialFailures: [String] = []
            do {
                let loadedAccountDetail = try await api.userDetail(
                    userID: loadedProfile.id
                )
                accountDetail = loadedAccountDetail
                profile = loadedAccountDetail.profile
            } catch is CancellationError {
                return
            } catch {
                // The account endpoint still provides enough identity data
                // for the settings row when extended profile details fail.
            }

            var loadedPlaylists: [Playlist] = []
            do {
                loadedPlaylists = try await api.userPlaylists(userID: loadedProfile.id)
                // 网易云把“我喜欢的音乐”作为返回列表的第一项；参考项目
                // 同样在歌单页隐藏这一项，歌曲页单独展示其中的歌曲。
                likedPlaylistID = loadedPlaylists.first?.id
                favoritePlaylists = Array(loadedPlaylists.dropFirst())
            } catch is CancellationError {
                return
            } catch {
                partialFailures.append(
                    L10n.format("ui.library.error.playlists", error.localizedDescription)
                )
            }

            do {
                favoriteAlbums = try await api.subscribedAlbums()
            } catch is CancellationError {
                return
            } catch {
                partialFailures.append(
                    L10n.format("ui.desktop.library.error.favorite_albums", error.localizedDescription)
                )
            }

            do {
                favoriteArtists = try await api.subscribedArtists()
            } catch is CancellationError {
                return
            } catch {
                partialFailures.append(
                    L10n.format("ui.desktop.library.error.favorite_artists", error.localizedDescription)
                )
            }

            if settings.isContentFeatureEnabled(.podcasts) {
                do {
                    let page = try await api.subscribedPodcasts(
                        limit: subscribedPodcastPageSize
                    )
                    try Task.checkCancellation()
                    subscribedPodcasts = normalizedSubscribedPodcasts(
                        page.podcasts
                    )
                    subscribedPodcastTotalCount = max(
                        page.totalCount ?? subscribedPodcasts.count,
                        subscribedPodcasts.count
                    )
                    subscribedPodcastsNextOffset = page.podcasts.count
                    hasMoreSubscribedPodcasts = page.hasMore
                    subscribedPodcastsLoadMoreError = nil
                } catch is CancellationError {
                    return
                } catch {
                    partialFailures.append(
                        L10n.format("ui.library.error.subscribed_podcasts", error.localizedDescription)
                    )
                }
            }

            do {
                let loadedSongIDs = try await api.likedSongIDs(
                    userID: loadedProfile.id,
                    likedPlaylistID: likedPlaylistID
                )
                let firstPage = try await api.songDetailsPage(
                    ids: loadedSongIDs,
                    offset: 0,
                    limit: favoriteSongPageSize
                )
                try Task.checkCancellation()
                favoriteSongIDs = loadedSongIDs
                favoriteSongIDSet = Set(loadedSongIDs)
                favoriteSongTotalCount = loadedSongIDs.count
                favoriteSongs = firstPage.songs
                favoriteSongsNextOffset = firstPage.nextOffset
                favoriteSongsLoadMoreError = nil
            } catch is CancellationError {
                return
            } catch {
                partialFailures.append(
                    L10n.format("ui.library.error.favorite_songs", error.localizedDescription)
                )
            }

            if settings.isContentFeatureEnabled(.listeningHistory) {
                do {
                    recentSongs = try await api.recentSongs()
                } catch is CancellationError {
                    return
                } catch {
                    partialFailures.append(
                        L10n.format("ui.library.error.history", error.localizedDescription)
                    )
                }
            }

            if !partialFailures.isEmpty {
                errorMessage = L10n.format(
                    "ui.library.error.partial",
                    partialFailures.joined(separator: "\n")
                )
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
                errorMessage = L10n.format(
                    "ui.library.error.account_refresh",
                    error.localizedDescription
                )
            }
        }
    }

    func loadMoreFavoriteSongs() async {
        if let favoriteSongPageLoadTask {
            await favoriteSongPageLoadTask.value
            return
        }

        guard hasMoreFavoriteSongs else { return }

        let requestedOffset = favoriteSongsNextOffset
        let requestedIDs = favoriteSongIDs
        let loadID = UUID()
        let loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.loadFavoriteSongsPage(
                ids: requestedIDs,
                offset: requestedOffset
            )
        }
        favoriteSongPageLoadID = loadID
        favoriteSongPageLoadTask = loadTask

        await loadTask.value

        guard favoriteSongPageLoadID == loadID else { return }
        favoriteSongPageLoadTask = nil
        favoriteSongPageLoadID = nil
    }

    func loadRemainingFavoriteSongs() async {
        while hasMoreFavoriteSongs {
            guard !Task.isCancelled else { return }
            let previousOffset = favoriteSongsNextOffset
            await loadMoreFavoriteSongs()
            guard favoriteSongsNextOffset > previousOffset else { return }
        }
    }

    func favoriteSongsForPlayback() async throws -> [Song] {
        if let favoriteSongPageLoadTask {
            await favoriteSongPageLoadTask.value
        }

        let requestedIDs = favoriteSongIDs
        let songs = try await api.songDetailsCollection(
            ids: requestedIDs,
            prefetched: favoriteSongs
        )
        try Task.checkCancellation()

        if favoriteSongIDs == requestedIDs {
            favoriteSongs = songs
            favoriteSongsNextOffset = requestedIDs.count
            favoriteSongsLoadMoreError = nil
        }
        return songs
    }

    private func loadFavoriteSongsPage(
        ids requestedIDs: [Int],
        offset requestedOffset: Int
    ) async {
        isLoadingMoreFavoriteSongs = true
        favoriteSongsLoadMoreError = nil
        defer { isLoadingMoreFavoriteSongs = false }

        do {
            let page = try await api.songDetailsPage(
                ids: requestedIDs,
                offset: requestedOffset,
                limit: favoriteSongPageSize
            )
            try Task.checkCancellation()
            guard favoriteSongIDs == requestedIDs,
                  favoriteSongsNextOffset == requestedOffset else {
                return
            }

            var loadedIDs = Set(favoriteSongs.map(\.id))
            favoriteSongs.append(
                contentsOf: page.songs.filter {
                    loadedIDs.insert($0.id).inserted
                }
            )
            favoriteSongsNextOffset = page.nextOffset
        } catch is CancellationError {
            return
        } catch {
            favoriteSongsLoadMoreError = error.localizedDescription
        }
    }

    func loadMoreSubscribedPodcasts() async {
        guard settings.isContentFeatureEnabled(.podcasts) else { return }
        if let subscribedPodcastPageLoadTask {
            await subscribedPodcastPageLoadTask.value
            return
        }

        guard hasMoreSubscribedPodcasts else { return }

        let requestedOffset = subscribedPodcastsNextOffset
        let loadID = UUID()
        let loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.loadSubscribedPodcastPage(
                offset: requestedOffset
            )
        }
        subscribedPodcastPageLoadID = loadID
        subscribedPodcastPageLoadTask = loadTask

        await loadTask.value

        guard subscribedPodcastPageLoadID == loadID else { return }
        subscribedPodcastPageLoadTask = nil
        subscribedPodcastPageLoadID = nil
    }

    func loadRemainingSubscribedPodcasts() async {
        while hasMoreSubscribedPodcasts {
            guard !Task.isCancelled else { return }
            let previousOffset = subscribedPodcastsNextOffset
            await loadMoreSubscribedPodcasts()
            guard subscribedPodcastsNextOffset > previousOffset else {
                return
            }
        }
    }

    private func loadSubscribedPodcastPage(
        offset requestedOffset: Int
    ) async {
        isLoadingMoreSubscribedPodcasts = true
        subscribedPodcastsLoadMoreError = nil
        defer { isLoadingMoreSubscribedPodcasts = false }

        do {
            let page = try await api.subscribedPodcasts(
                offset: requestedOffset,
                limit: subscribedPodcastPageSize
            )
            try Task.checkCancellation()
            guard subscribedPodcastsNextOffset == requestedOffset else {
                return
            }

            var loadedIDs = Set(subscribedPodcasts.map(\.id))
            subscribedPodcasts.append(
                contentsOf: normalizedSubscribedPodcasts(
                    page.podcasts
                ).filter {
                    loadedIDs.insert($0.id).inserted
                }
            )
            subscribedPodcastsNextOffset =
                requestedOffset + page.podcasts.count
            subscribedPodcastTotalCount = max(
                page.totalCount ?? subscribedPodcastTotalCount,
                subscribedPodcasts.count
            )
            hasMoreSubscribedPodcasts =
                page.hasMore && !page.podcasts.isEmpty
        } catch is CancellationError {
            return
        } catch {
            subscribedPodcastsLoadMoreError =
                error.localizedDescription
        }
    }

    func toggle(song: Song) {
        guard isLoggedIn else {
            operationErrorMessage = APIError.notLoggedIn.localizedDescription
            return
        }

        let wasLiked = contains(song: song)
        setLocalSong(song, isLiked: !wasLiked)

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.api.setSongLiked(id: song.id, isLiked: !wasLiked)
            } catch {
                self.setLocalSong(song, isLiked: wasLiked)
                self.operationErrorMessage = error.localizedDescription
            }
        }
    }

    func toggle(playlist: Playlist) {
        guard isLoggedIn else {
            operationErrorMessage = APIError.notLoggedIn.localizedDescription
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
                self.operationErrorMessage = error.localizedDescription
            }
        }
    }

    func setAlbumSubscribed(
        _ album: Album,
        isSubscribed: Bool
    ) async throws {
        guard isLoggedIn else { throw APIError.notLoggedIn }

        let previousAlbums = favoriteAlbums
        setLocalAlbum(album, isSubscribed: isSubscribed)
        do {
            try await api.setAlbumSubscribed(
                id: album.id,
                isSubscribed: isSubscribed
            )
        } catch {
            favoriteAlbums = previousAlbums
            throw error
        }
    }

    func setArtistFollowed(
        _ artist: Artist,
        isFollowed: Bool
    ) async throws {
        guard isLoggedIn else { throw APIError.notLoggedIn }

        let previousArtists = favoriteArtists
        setLocalArtist(artist, isFollowed: isFollowed)
        do {
            try await api.setArtistFollowed(
                id: artist.id,
                isFollowed: isFollowed
            )
        } catch {
            favoriteArtists = previousArtists
            throw error
        }
    }

    func toggle(podcast: Podcast) {
        guard isLoggedIn else {
            operationErrorMessage = APIError.notLoggedIn.localizedDescription
            return
        }

        let desiredState = !contains(podcast: podcast)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.setPodcastSubscribed(
                    podcast,
                    isSubscribed: desiredState
                )
            } catch is CancellationError {
                return
            } catch {
                self.operationErrorMessage = error.localizedDescription
            }
        }
    }

    func setPodcastSubscribed(
        _ podcast: Podcast,
        isSubscribed: Bool
    ) async throws {
        guard isLoggedIn else { throw APIError.notLoggedIn }

        let previousPodcasts = subscribedPodcasts
        let previousTotalCount = subscribedPodcastTotalCount
        let previousNextOffset = subscribedPodcastsNextOffset
        let previousHasMore = hasMoreSubscribedPodcasts
        setLocalPodcast(podcast, isSubscribed: isSubscribed)

        do {
            try await api.setPodcastSubscribed(
                id: podcast.id,
                isSubscribed: isSubscribed
            )
        } catch {
            subscribedPodcasts = previousPodcasts
            subscribedPodcastTotalCount = previousTotalCount
            subscribedPodcastsNextOffset = previousNextOffset
            hasMoreSubscribedPodcasts = previousHasMore
            throw error
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
        operationErrorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func clearOperationError() {
        operationErrorMessage = nil
    }

    private func clearRemoteContent() {
        favoriteSongPageLoadTask?.cancel()
        favoriteSongPageLoadTask = nil
        favoriteSongPageLoadID = nil
        subscribedPodcastPageLoadTask?.cancel()
        subscribedPodcastPageLoadTask = nil
        subscribedPodcastPageLoadID = nil
        profile = nil
        accountDetail = nil
        favoriteSongs = []
        favoritePlaylists = []
        favoriteAlbums = []
        favoriteArtists = []
        subscribedPodcasts = []
        recentSongs = []
        likedPlaylistID = nil
        favoriteSongIDs = []
        favoriteSongIDSet = []
        favoriteSongTotalCount = 0
        favoriteSongsNextOffset = 0
        isLoadingMoreFavoriteSongs = false
        favoriteSongsLoadMoreError = nil
        subscribedPodcastTotalCount = 0
        subscribedPodcastsNextOffset = 0
        hasMoreSubscribedPodcasts = false
        isLoadingMoreSubscribedPodcasts = false
        subscribedPodcastsLoadMoreError = nil
    }

    private func setLocalSong(
        _ song: Song,
        isLiked: Bool
    ) {
        if let index = favoriteSongIDs.firstIndex(of: song.id) {
            favoriteSongIDs.remove(at: index)
            if index < favoriteSongsNextOffset {
                favoriteSongsNextOffset -= 1
            }
        }
        favoriteSongIDSet.remove(song.id)
        favoriteSongs.removeAll { $0.id == song.id }

        if isLiked {
            favoriteSongIDs.insert(song.id, at: 0)
            favoriteSongIDSet.insert(song.id)
            favoriteSongs.insert(song, at: 0)
            favoriteSongsNextOffset += 1
        }
        favoriteSongTotalCount = favoriteSongIDs.count
    }

    private func setLocalAlbum(
        _ album: Album,
        isSubscribed: Bool
    ) {
        favoriteAlbums.removeAll { $0.id == album.id }
        if isSubscribed {
            favoriteAlbums.insert(album, at: 0)
        }
    }

    private func setLocalArtist(
        _ artist: Artist,
        isFollowed: Bool
    ) {
        favoriteArtists.removeAll { $0.id == artist.id }
        if isFollowed {
            favoriteArtists.insert(artist, at: 0)
        }
    }

    private func setLocalPodcast(
        _ podcast: Podcast,
        isSubscribed: Bool
    ) {
        let wasSubscribed =
            contains(podcast: podcast) || podcast.isSubscribed
        subscribedPodcasts.removeAll { $0.id == podcast.id }

        if isSubscribed {
            var summary = podcast
            summary.isSubscribed = true
            subscribedPodcasts.insert(summary, at: 0)
        }

        if wasSubscribed != isSubscribed {
            subscribedPodcastTotalCount += isSubscribed ? 1 : -1
        }
        subscribedPodcastTotalCount = max(
            subscribedPodcastTotalCount,
            subscribedPodcasts.count
        )
        subscribedPodcastsNextOffset = subscribedPodcasts.count
        hasMoreSubscribedPodcasts =
            subscribedPodcastsNextOffset < subscribedPodcastTotalCount
    }

    private func normalizedSubscribedPodcasts(
        _ podcasts: [Podcast]
    ) -> [Podcast] {
        var identifiers = Set<Int>()
        return podcasts.compactMap { podcast in
            guard podcast.id > 0,
                  identifiers.insert(podcast.id).inserted else {
                return nil
            }
            var subscribedPodcast = podcast
            subscribedPodcast.isSubscribed = true
            return subscribedPodcast
        }
    }
}

private enum LibraryOperationError: LocalizedError {
    case playlistIsNotOwned

    var errorDescription: String? {
        switch self {
        case .playlistIsNotOwned:
            L10n.string("ui.library.error.owned_playlist_only")
        }
    }
}
