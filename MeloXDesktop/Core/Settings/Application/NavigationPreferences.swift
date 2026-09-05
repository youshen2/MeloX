import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case recommended
    case music
    case podcasts
    case explore
    case library
    case librarySongs
    case libraryPlaylists
    case libraryAlbums
    case libraryPodcasts
    case libraryDownloads
    case libraryCloud
    case libraryHistory
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: L10n.string("ui.navigation.home")
        case .recommended: L10n.string("ui.navigation.recommended")
        case .music: L10n.string("ui.navigation.music")
        case .podcasts: L10n.string("ui.navigation.podcasts")
        case .explore: L10n.string("ui.navigation.explore")
        case .library: L10n.string("ui.navigation.library")
        case .librarySongs: L10n.string("ui.navigation.library.liked_songs")
        case .libraryPlaylists: L10n.string("ui.navigation.library.liked_playlists")
        case .libraryAlbums: L10n.string("ui.navigation.library.liked_albums")
        case .libraryPodcasts: L10n.string("ui.navigation.library.subscribed_podcasts")
        case .libraryDownloads: L10n.string("ui.navigation.downloads")
        case .libraryCloud: L10n.string("ui.navigation.cloud")
        case .libraryHistory: L10n.string("ui.navigation.recently_played")
        case .search: L10n.string("ui.navigation.search")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .recommended: "sparkles"
        case .music: "music.note"
        case .podcasts: "dot.radiowaves.left.and.right"
        case .explore: "safari"
        case .library: "music.note.list"
        case .librarySongs: "heart"
        case .libraryPlaylists: "music.note.list"
        case .libraryAlbums: "square.stack"
        case .libraryPodcasts: "mic"
        case .libraryDownloads: "arrow.down.circle"
        case .libraryCloud: "icloud"
        case .libraryHistory: "clock"
        case .search: "magnifyingglass"
        }
    }

    var libraryPage: LibraryPage? {
        switch self {
        case .librarySongs: .songs
        case .libraryPlaylists: .playlists
        case .libraryAlbums: .albums
        case .libraryPodcasts: .podcasts
        case .libraryDownloads: .downloads
        case .libraryCloud: .cloud
        case .libraryHistory: .history
        case .home,
             .recommended,
             .music,
             .podcasts,
             .explore,
             .library,
             .search:
            nil
        }
    }

    var settingsTitle: String {
        libraryPage?.settingsTitle ?? title
    }

    var requiredContentFeature: ContentFeature? {
        switch self {
        case .podcasts:
            .podcasts
        case .libraryPodcasts:
            .podcasts
        case .libraryDownloads:
            .downloads
        case .libraryCloud:
            .cloudMusic
        case .libraryHistory:
            .listeningHistory
        case .home,
             .recommended,
             .music,
             .explore,
             .library,
             .librarySongs,
             .libraryPlaylists,
             .libraryAlbums,
             .search:
            nil
        }
    }

    var allowedPlacements: [AppPagePlacement] {
        if self == .recommended {
            return [.home]
        }
        return libraryPage == nil
            ? [.home, .tabBar]
            : AppPagePlacement.allCases
    }

    static let movablePrimaryContentPages: [AppTab] = [
        .music,
        .podcasts,
        .explore,
        .library,
    ]

    static var libraryContentPages: [AppTab] {
        var pages: [AppTab] = [
            .librarySongs,
            .libraryPlaylists,
            .libraryAlbums,
            .libraryPodcasts,
        ]
        if AppFeatureAvailability.downloads {
            pages.append(.libraryDownloads)
        }
        pages.append(contentsOf: [.libraryCloud, .libraryHistory])
        return pages
    }

    static var configurablePages: [AppTab] {
        movablePrimaryContentPages + libraryContentPages
    }

    init(libraryPage: LibraryPage) {
        switch libraryPage {
        case .songs:
            self = .librarySongs
        case .playlists:
            self = .libraryPlaylists
        case .albums:
            self = .libraryAlbums
        case .podcasts:
            self = .libraryPodcasts
        case .downloads:
            self = .libraryDownloads
        case .cloud:
            self = .libraryCloud
        case .history:
            self = .libraryHistory
        }
    }
}

enum AppPagePlacement: String, CaseIterable, Identifiable {
    case home
    case tabBar
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: L10n.string("ui.navigation.home")
        case .tabBar: L10n.string("ui.settings.navigation.placement.tab_bar")
        case .library: L10n.string("ui.navigation.library")
        }
    }
}

enum LibraryPage: String, CaseIterable, Identifiable {
    case songs
    case playlists
    case albums
    case podcasts
    case downloads
    case cloud
    case history

    var id: String { rawValue }

    static var availableCases: [LibraryPage] {
        allCases.filter {
            AppFeatureAvailability.downloads || $0 != .downloads
        }
    }

    var title: String {
        switch self {
        case .songs: L10n.string("ui.common.songs")
        case .playlists: L10n.string("ui.common.playlists")
        case .albums: L10n.string("ui.common.albums")
        case .podcasts: L10n.string("ui.navigation.podcasts")
        case .downloads: L10n.string("ui.navigation.downloads")
        case .cloud: L10n.string("ui.navigation.cloud")
        case .history: L10n.string("ui.common.history")
        }
    }

    var systemImage: String {
        switch self {
        case .songs: "music.note"
        case .playlists: "music.note.list"
        case .albums: "square.stack"
        case .podcasts: "mic"
        case .downloads: "arrow.down.circle"
        case .cloud: "icloud"
        case .history: "clock"
        }
    }

    var settingsTitle: String {
        switch self {
        case .songs: L10n.string("ui.settings.navigation.page.liked_songs")
        case .playlists: L10n.string("ui.settings.navigation.page.liked_playlists")
        case .albums: L10n.string("ui.settings.navigation.page.liked_albums")
        case .podcasts: L10n.string("ui.settings.navigation.page.subscribed_podcasts")
        case .downloads: L10n.string("ui.navigation.downloads")
        case .cloud: L10n.string("ui.navigation.cloud")
        case .history: L10n.string("ui.navigation.recently_played")
        }
    }

    var requiredContentFeature: ContentFeature? {
        switch self {
        case .podcasts: .podcasts
        case .downloads: .downloads
        case .cloud: .cloudMusic
        case .history: .listeningHistory
        case .songs, .playlists, .albums: nil
        }
    }
}
