import SwiftUI

enum AppTab: Hashable {
    case home
    case explore
    case library
    case search
    case settings
}

enum MusicRoute: Hashable {
    case playlist(Int)
    case playlistCategory(String)
    case album(Int)
    case artist(Int)
    case dailySongs
    case newAlbums
}

enum PlayerPresentation: String, Identifiable {
    case nowPlaying

    var id: String { rawValue }
}

extension View {
    func musicDestinations() -> some View {
        navigationDestination(for: MusicRoute.self) { route in
            switch route {
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
            }
        }
    }
}
