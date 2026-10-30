"""Exercise the production page cache and snapshot codecs without a simulator.

Set MELOX_GRDB_BUILD_PRODUCTS and MELOX_GRDB_SQLITE_INCLUDE to reuse a macOS
GRDB build; otherwise the harness resolves the project's pinned GRDB version.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCES = [
    "MeloX/Core/Storage/PageContentCache.swift",
    "MeloX/Core/Storage/AppStorageLocations.swift",
    "MeloX/Core/Models/Account/AccountModels.swift",
    "MeloX/Core/Models/Music/MusicModels.swift",
    "MeloX/Core/Models/Music/SongAudioAvailability.swift",
    "MeloX/Core/Models/Music/SongCollectionPage.swift",
    "MeloX/Core/Models/Podcast/PodcastModels.swift",
    "MeloX/Core/Models/Home/HomePageModels.swift",
    "MeloX/Core/Models/Home/HomePageResourceModels.swift",
    "MeloX/Core/Models/Home/HomeSupplementModels.swift",
    "MeloX/Core/Library/LibraryContentSnapshot.swift",
    "MeloX/Features/Home/HomeRecommendationFeed.swift",
    "MeloX/Features/Home/HomeContentSnapshot.swift",
    "MeloX/Features/Playlist/PlaylistContentSnapshot.swift",
]

HARNESS = r'''
import Foundation
import GRDB

nonisolated enum L10n {
    static func string(_ key: String) -> String { key }
    static func format(_ key: String, _ values: CVarArg...) -> String { key }
    static func joined(_ values: [String], separatorKey: String) -> String {
        values.joined(separator: ", ")
    }
}

@MainActor final class AppSettings {
    var cookie = "account-a"
    var automaticallyCachesPageContent = true
    func isContentFeatureEnabled(_ feature: ContentFeature) -> Bool { false }
    func clearAccount() { cookie = "" }
}

enum ContentFeature { case podcasts, listeningHistory }
enum APIError: Error { case invalidResponse, notLoggedIn }
enum FixtureError: Error { case offline }

@MainActor final class NeteaseAPI {
    let pageContentCache: PageContentCache
    var isOnline = true
    var failFavorites = false
    var profileRequests = 0
    let profile: AccountProfile

    init(cache: PageContentCache) throws {
        pageContentCache = cache
        profile = try JSONDecoder().decode(AccountProfile.self, from: Data(#"{"userId":1,"nickname":"Account"}"#.utf8))
    }
    func accountProfile() async throws -> AccountProfile {
        profileRequests += 1
        guard isOnline else { throw FixtureError.offline }
        return profile
    }
    func userDetail(userID: Int) async throws -> AccountDetail {
        AccountDetail(profile: profile, level: 1, listenSongs: 0, createDays: nil)
    }
    func userPlaylists(userID: Int) async throws -> [Playlist] {
        [Playlist(id: 43, name: "Liked")]
    }
    func subscribedAlbums() async throws -> [Album] { [] }
    func subscribedArtists() async throws -> [Artist] { [] }
    func subscribedPodcasts(limit: Int) async throws -> PodcastPage {
        PodcastPage(podcasts: [], hasMore: false, totalCount: 0)
    }
    func likedSongIDs(userID: Int, likedPlaylistID: Int?) async throws -> [Int] { [11] }
    func songDetailsPage(ids: [Int], offset: Int, limit: Int) async throws -> SongCollectionPage {
        guard !failFavorites else { throw FixtureError.offline }
        return SongCollectionPage(songs: [Song(id: 11, name: "Loaded song", artists: [])], nextOffset: 1, totalCount: 1)
    }
    func recentSongs() async throws -> [Song] { [] }
}

@MainActor final class LibraryRefreshHarness {
    let api: NeteaseAPI
    let settings: AppSettings
    var profile: AccountProfile?
    var accountDetail: AccountDetail?
    var favoriteSongs: [Song] = []
    var favoritePlaylists: [Playlist] = []
    var favoriteAlbums: [Album] = []
    var favoriteArtists: [Artist] = []
    var subscribedPodcasts: [Podcast] = []
    var recentSongs: [Song] = []
    var likedPlaylistID: Int?
    var favoriteSongTotalCount = 0
    var favoriteSongsNextOffset = 0
    var isLoadingMoreFavoriteSongs = false
    var favoriteSongsLoadMoreError: String?
    var subscribedPodcastTotalCount = 0
    var subscribedPodcastsNextOffset = 0
    var hasMoreSubscribedPodcasts = false
    var isLoadingMoreSubscribedPodcasts = false
    var subscribedPodcastsLoadMoreError: String?
    var phase: LoadingPhase = .loaded
    var errorMessage: String?
    var loadedCookie: String?
    var refreshingCookie: String?
    var lastSuccessfulRefresh: Date?
    var favoriteSongIDs: [Int] = []
    var favoriteSongIDSet: Set<Int> = []
    let favoriteSongPageSize = 100
    var favoriteSongPageLoadTask: Task<Void, Never>?
    var favoriteSongPageLoadID: UUID?
    let subscribedPodcastPageSize = 50
    var subscribedPodcastPageLoadTask: Task<Void, Never>?
    var subscribedPodcastPageLoadID: UUID?

    init(api: NeteaseAPI, settings: AppSettings) { self.api = api; self.settings = settings }
    func normalizedSubscribedPodcasts(_ values: [Podcast]) -> [Podcast] { values }
    // LIBRARY_METHODS
}

@main struct CacheRegression {
    @MainActor static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        let settings = AppSettings()
        let cache = PageContentCache(settings: settings, directory: directory)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(HomePagePayload.self, from: Data(#"""
        {"blocks":[{"blockCode":"HOMEPAGE_BLOCK_PLAYLIST_RCMD","creatives":[
          {"creativeId":123,"resources":[
            {"resourceType":"playlist","resourceId":42,"uiElement":{"mainTitle":{"title":"Cached playlist"}}},
            {"resourceType":"song","resourceId":11,"resourceExtInfo":{"songData":{"id":11,"name":"Cached song"}}}
          ]}]}]}
        """#.utf8))
        let program = try decoder.decode(PodcastProgram.self, from: Data(#"""
        {"id":7,"name":"Episode","duration":3210,"radio":{"id":8,"name":"Radio"},
         "dj":{"userId":9,"nickname":"Host"},"mainSong":{"id":22,"name":"Audio"}}
        """#.utf8))
        let snapshot = HomeContentSnapshot(
            payload: payload, charts: [],
            fallbacks: [.listenedPodcastRecommendations:
                HomeRecommendationFallback(title: .standard, content: .podcastPrograms([program]))]
        )
        await cache.store(snapshot, for: HomeContentSnapshot.cacheKey(musicArea: "ALL"))

        let reopened = PageContentCache(settings: settings, directory: directory)
        let restored: HomeContentSnapshot? = await reopened.value(
            for: HomeContentSnapshot.cacheKey(musicArea: "ALL")
        )
        precondition(restored?.payload.blocks.first?.playlists.first?.id == 42)
        precondition(restored?.payload.blocks.first?.songs.first?.id == 11)
        precondition(restored?.payload.blocks.first?.creatives.first?.creativeID == "123")
        guard case .podcastPrograms(let programs) = restored?.fallbacks[.listenedPodcastRecommendations]?.content else {
            fatalError("Podcast fallback was lost")
        }
        precondition(programs.first?.durationMS == 3210)
        precondition(programs.first?.mainSong?.id == 22)

        let profile = try decoder.decode(AccountProfile.self, from: Data(#"{"userId":1,"nickname":"Account"}"#.utf8))
        let song = Song(id: 11, name: "Cached song", artists: [])
        let podcast = Podcast(id: 8, name: "Radio", recommendationText: "Recommended", host: PodcastHost(id: 9, nickname: "Host"))
        let library = LibraryContentSnapshot(
            profile: profile, accountDetail: nil,
            favoriteSongs: [song], favoriteSongIDs: [11, 12], favoriteSongsNextOffset: 1,
            favoritePlaylists: [Playlist(id: 42, name: "Cached playlist")],
            favoriteAlbums: [], favoriteArtists: [], subscribedPodcasts: [podcast],
            subscribedPodcastTotalCount: 2, subscribedPodcastsNextOffset: 1,
            hasMoreSubscribedPodcasts: true, recentSongs: [song], likedPlaylistID: 43
        )
        await cache.store(library, for: LibraryContentSnapshot.cacheKey)
        let restoredLibrary: LibraryContentSnapshot? = await reopened.value(for: LibraryContentSnapshot.cacheKey)
        precondition(restoredLibrary?.favoriteSongs.first?.id == 11)
        precondition(restoredLibrary?.favoriteSongIDs == [11, 12])
        precondition(restoredLibrary?.favoriteSongsNextOffset == 1)
        precondition(restoredLibrary?.subscribedPodcasts.first?.recommendationText == "Recommended")
        precondition(restoredLibrary?.hasMoreSubscribedPodcasts == true)

        settings.cookie = "account-b"
        let otherAccount: LibraryContentSnapshot? = await reopened.value(for: LibraryContentSnapshot.cacheKey)
        precondition(otherAccount == nil)
        await cache.store([99], for: "account-test")
        settings.cookie = "account-a"
        settings.automaticallyCachesPageContent = false
        let disabled: LibraryContentSnapshot? = await cache.value(for: LibraryContentSnapshot.cacheKey)
        precondition(disabled == nil)
        await cache.store([99], for: "disabled-write")
        settings.automaticallyCachesPageContent = true
        let ignoredWrite: [Int]? = await cache.value(for: "disabled-write")
        precondition(ignoredWrite == nil)

        await cache.removeAccount(cookie: "account-a")
        let removed: LibraryContentSnapshot? = await cache.value(for: LibraryContentSnapshot.cacheKey)
        precondition(removed == nil)
        settings.cookie = "account-b"
        let preserved: [Int]? = await cache.value(for: "account-test")
        precondition(preserved == [99])

        let database = try DatabaseQueue(path: directory.appending(path: "content.sqlite").path)
        try await database.write { db in
            try db.execute(sql: "UPDATE pageContent SET payload = X'00'")
        }
        let corrupted: [Int]? = await cache.value(for: "account-test")
        precondition(corrupted == nil)

        let librarySettings = AppSettings()
        let libraryCache = PageContentCache(settings: librarySettings, directory: directory.appending(path: "Library"))
        let api = try NeteaseAPI(cache: libraryCache)
        let firstLibrary = LibraryRefreshHarness(api: api, settings: librarySettings)
        await firstLibrary.refresh()
        precondition(firstLibrary.favoriteSongs.first?.id == 11)
        api.isOnline = false
        let offlineLibrary = LibraryRefreshHarness(api: api, settings: librarySettings)
        await offlineLibrary.refresh()
        precondition(offlineLibrary.favoriteSongs.first?.id == 11)
        precondition(offlineLibrary.phase == .loaded)
        precondition(offlineLibrary.errorMessage != nil)
        api.isOnline = true
        api.failFavorites = true
        await offlineLibrary.refresh()
        precondition(offlineLibrary.favoriteSongs.first?.id == 11)
        precondition(offlineLibrary.lastSuccessfulRefresh == nil)
        api.failFavorites = false
        await offlineLibrary.refresh()
        precondition(offlineLibrary.lastSuccessfulRefresh != nil)
        precondition(api.profileRequests == 4)
        await offlineLibrary.refresh()
        precondition(api.profileRequests == 4)
        print("PASS: disk restoration, codecs, account isolation, disabled cache, logout cleanup, corrupt cache recovery, offline library, and retry after partial failure")
    }
}
'''


class PageContentCacheTests(unittest.TestCase):
    def test_persistent_account_scoped_content(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            harness = directory / "Harness.swift"
            source = (ROOT / "MeloX/Core/Library/LibraryStore.swift").read_text()
            methods = []
            for signature in ("func refresh(force:", "private func isCurrentRefresh(", "func clearAccountData()", "private func clearRemoteContent()", "private func restoreContent(", "private func persistContent()"):
                start = source.index(signature)
                opening = source.index("{", start)
                depth, end = 1, opening + 1
                while depth:
                    depth += (source[end] == "{") - (source[end] == "}")
                    end += 1
                methods.append(source[start:end])
            harness.write_text(HARNESS.replace("// LIBRARY_METHODS", "\n".join(methods)))
            products = os.environ.get("MELOX_GRDB_BUILD_PRODUCTS")
            if products:
                executable = directory / "regression"
                command = [
                    "xcrun", "swiftc", "-parse-as-library", "-swift-version", "5",
                    "-default-isolation", "MainActor", "-I", products,
                    "-I", os.environ["MELOX_GRDB_SQLITE_INCLUDE"],
                    *[str(ROOT / source) for source in SOURCES], str(harness),
                    str(Path(products) / "GRDB.o"), "-o", str(executable),
                ]
                compiled = subprocess.run(command, capture_output=True, text=True)
                self.assertEqual(compiled.returncode, 0, compiled.stderr)
                command = [str(executable)]
            else:
                pin_file = ROOT / "MeloX.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
                pins = json.loads(pin_file.read_text())["pins"]
                grdb = next(pin for pin in pins if pin["identity"] == "grdb.swift")
                sources = directory / "Sources/Regression"
                sources.mkdir(parents=True)
                for source in SOURCES:
                    shutil.copy2(ROOT / source, sources)
                shutil.copy2(harness, sources)
                (directory / "Package.swift").write_text(
                    '// swift-tools-version: 6.2\nimport PackageDescription\n'
                    'let package = Package(name: "Regression", platforms: [.macOS(.v14)], '
                    f'dependencies: [.package(url: "{grdb["location"]}", exact: "{grdb["state"]["version"]}")], '
                    'targets: [.executableTarget(name: "Regression", '
                    'dependencies: [.product(name: "GRDB", package: "GRDB.swift")], '
                    'swiftSettings: [.defaultIsolation(MainActor.self)])], swiftLanguageModes: [.v5])\n'
                )
                command = ["swift", "run", "--package-path", str(directory), "Regression"]
            result = subprocess.run(
                command + [str(directory / "Cache")], capture_output=True, text=True, timeout=600
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            print(result.stdout.strip())


if __name__ == "__main__":
    unittest.main()
