import SwiftUI

struct PlaylistRouteContext: Hashable {
    let id: Int
    let name: String
    let coverURLString: String?
    let playlistDescription: String?
    let trackCount: Int
    let playCount: Int
    let updateFrequency: String?
    let toplistType: String?
    let copywriter: String?
    let creator: UserSummary?
    let subscribed: Bool

    init(_ playlist: Playlist) {
        id = playlist.id
        name = playlist.name
        coverURLString = playlist.coverURLString
        playlistDescription = playlist.playlistDescription
        trackCount = playlist.trackCount
        playCount = playlist.playCount
        updateFrequency = playlist.updateFrequency
        toplistType = playlist.toplistType
        copywriter = playlist.copywriter
        creator = playlist.creator
        subscribed = playlist.subscribed
    }

    var playlistSummary: Playlist {
        Playlist(
            id: id,
            name: name,
            coverURLString: coverURLString,
            playlistDescription: playlistDescription,
            trackCount: trackCount,
            playCount: playCount,
            updateFrequency: updateFrequency,
            toplistType: toplistType,
            copywriter: copywriter,
            creator: creator,
            subscribed: subscribed
        )
    }
}

struct AlbumRouteContext: Hashable {
    let id: Int
    let name: String
    let picURL: String?
    let picID: Int64?
    let artists: [Artist]
    let publishTime: Double?
    let size: Int?
    let type: String?
    let albumDescription: String?

    init(_ album: Album) {
        id = album.id
        name = album.name
        picURL = album.picURL
        picID = album.picID
        artists = album.artists
        publishTime = album.publishTime
        size = album.size
        type = album.type
        albumDescription = album.albumDescription
    }

    var albumSummary: Album {
        Album(
            id: id,
            name: name,
            picURL: picURL,
            picID: picID,
            artists: artists,
            publishTime: publishTime,
            size: size,
            type: type,
            albumDescription: albumDescription
        )
    }
}

enum MusicRoute: Hashable {
    case song(Song)
    case playlist(PlaylistRouteContext)
    case toplist(PlaylistRouteContext)
    case playlistCategory(String)
    case album(AlbumRouteContext)
    case artist(Int)
    case podcasts
    case podcast(Podcast)
    case podcastCategory(PodcastCategory)
    case podcastProgram(PodcastProgram)
    case dailySongs
    case newAlbums
    case toplists

    static func playlist(_ playlist: Playlist) -> Self {
        .playlist(PlaylistRouteContext(playlist))
    }

    static func toplist(_ playlist: Playlist) -> Self {
        .toplist(PlaylistRouteContext(playlist))
    }

    static func album(_ album: Album) -> Self {
        .album(AlbumRouteContext(album))
    }

    var usesCardExpansionTransition: Bool {
        switch self {
        case .song, .playlist, .toplist, .album, .artist:
            true
        case .playlistCategory,
             .podcasts,
             .podcast,
             .podcastCategory,
             .podcastProgram,
             .dailySongs,
             .newAlbums,
             .toplists:
            false
        }
    }

    var transitionID: String {
        switch self {
        case .song(let song):
            "song-\(song.id)"
        case .playlist(let context):
            "playlist-\(context.id)"
        case .toplist(let context):
            "toplist-\(context.id)"
        case .playlistCategory(let category):
            "playlist-category-\(category)"
        case .album(let context):
            "album-\(context.id)"
        case .artist(let id):
            "artist-\(id)"
        case .podcasts:
            "podcasts"
        case .podcast(let podcast):
            "podcast-\(podcast.id)"
        case .podcastCategory(let category):
            "podcast-category-\(category.id)"
        case .podcastProgram(let program):
            "podcast-program-\(program.id)"
        case .dailySongs:
            "daily-songs"
        case .newAlbums:
            "new-albums"
        case .toplists:
            "toplists"
        }
    }

    var transitionArtworkURL: URL? {
        switch self {
        case .playlist(let context), .toplist(let context):
            context.coverURLString.flatMap(URL.init(string:))
        case .album(let context):
            context.picURL.flatMap(URL.init(string:))
        case .podcast(let podcast):
            podcast.artworkURL
        case .podcastProgram(let program):
            program.artworkURL
        case .song,
             .artist,
             .playlistCategory,
             .podcasts,
             .podcastCategory,
             .dailySongs,
             .newAlbums,
             .toplists:
            nil
        }
    }
}

struct OpenMusicRouteAction {
    private let action: (MusicRoute) -> Void

    init(action: @escaping (MusicRoute) -> Void = { _ in }) {
        self.action = action
    }

    func callAsFunction(_ route: MusicRoute) {
        action(route)
    }
}

private struct OpenMusicRouteActionKey: EnvironmentKey {
    static let defaultValue = OpenMusicRouteAction()
}

extension EnvironmentValues {
    var openMusicRoute: OpenMusicRouteAction {
        get { self[OpenMusicRouteActionKey.self] }
        set { self[OpenMusicRouteActionKey.self] = newValue }
    }
}

struct SetTabViewBottomAccessorySuppressedAction {
    private let action: (Bool) -> Void

    init(action: @escaping (Bool) -> Void = { _ in }) {
        self.action = action
    }

    func callAsFunction(_ isSuppressed: Bool) {
        action(isSuppressed)
    }
}

private struct SetTabViewBottomAccessorySuppressedActionKey:
    EnvironmentKey {
    static let defaultValue =
        SetTabViewBottomAccessorySuppressedAction()
}

extension EnvironmentValues {
    var setTabViewBottomAccessorySuppressed:
        SetTabViewBottomAccessorySuppressedAction {
        get {
            self[SetTabViewBottomAccessorySuppressedActionKey.self]
        }
        set {
            self[SetTabViewBottomAccessorySuppressedActionKey.self] =
                newValue
        }
    }
}

enum PlayerPresentation: Hashable, Identifiable {
    case nowPlaying(initialPage: NowPlayingPage)

    var id: String {
        switch self {
        case .nowPlaying(let page): "now-playing-\(page.rawValue)"
        }
    }
}

extension View {
    func musicDestinations(in namespace: Namespace.ID) -> some View {
        navigationDestination(for: MusicRoute.self) { route in
            MusicRouteDestination(route: route)
                .musicNavigationTransition(for: route, in: namespace)
        }
    }
}

private struct MusicRouteDestination: View {
    let route: MusicRoute

    @ViewBuilder
    var body: some View {
        switch route {
        case .song(let song):
            SongDetailView(song: song)
        case .playlist(let context):
            PlaylistDetailView(playlist: context)
        case .toplist(let context):
            PlaylistDetailView(toplist: context)
        case .playlistCategory(let category):
            PlaylistCategoryView(category: category)
        case .album(let context):
            AlbumDetailView(context: context)
        case .artist(let id):
            ArtistDetailView(id: id)
        case .podcasts:
            PodcastHomeView()
        case .podcast(let podcast):
            PodcastDetailView(podcast: podcast)
        case .podcastCategory(let category):
            PodcastCategoryView(category: category)
        case .podcastProgram(let program):
            PodcastProgramDetailView(program: program)
        case .dailySongs:
            DailySongsView()
        case .newAlbums:
            NewAlbumsView()
        case .toplists:
            ToplistsView()
        }
    }
}
