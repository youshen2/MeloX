import SwiftUI

enum AppTab: Hashable {
    case home
    case explore
    case library
    case search
    case settings
}

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
    let artists: [Artist]
    let publishTime: Double?
    let size: Int?
    let type: String?
    let albumDescription: String?

    init(_ album: Album) {
        id = album.id
        name = album.name
        picURL = album.picURL
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

enum PlayerPresentation: String, Identifiable {
    case nowPlaying

    var id: String { rawValue }
}

extension View {
    func musicDestinations() -> some View {
        navigationDestination(for: MusicRoute.self) { route in
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
            case .dailySongs:
                DailySongsView()
            case .newAlbums:
                NewAlbumsView()
            case .toplists:
                ToplistsView()
            }
        }
    }
}
