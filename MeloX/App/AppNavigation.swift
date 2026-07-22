import SwiftUI

enum AppTab: Hashable {
    case home
    case explore
    case library
    case search
    case settings
}

enum MusicRoute: Hashable {
    case song(Song)
    case playlist(Int)
    case playlistCategory(String)
    case album(Int)
    case artist(Int)
    case dailySongs
    case newAlbums
    case toplists
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
            case .playlist(let id):
                PlaylistDetailView(id: id)
            case .playlistCategory(let category):
                PlaylistCategoryView(category: category)
            case .album(let id):
                AlbumDetailView(id: id)
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
