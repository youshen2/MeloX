import SwiftUI

struct LibraryAlbumsView: View {
    let searchQuery: String

    @Environment(LibraryStore.self) private var library

    var body: some View {
        let query = normalizedLibrarySearchQuery(searchQuery)
        let albums = library.favoriteAlbums.filter { album in
            query.isEmpty
                || album.name.localizedCaseInsensitiveContains(query)
                || album.artistText.localizedCaseInsensitiveContains(query)
        }

        List(albums) { album in
            NavigationLink(value: MusicRoute.album(album)) {
                HStack(spacing: 12) {
                    ArtworkImage(url: album.artworkURL, cornerRadius: 7)
                        .frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.name)
                            .lineLimit(1)
                        Text(album.artistText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .musicMatchedTransitionSource(for: MusicRoute.album(album))
        }
        .listStyle(.plain)
        .refreshable {
            await library.refresh(force: true)
        }
        .overlay {
            if library.favoriteAlbums.isEmpty, library.phase == .loading {
                ProgressView("ui.library.loading")
            } else if albums.isEmpty {
                if !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ContentUnavailableView(
                        "ui.library.no_favorite_albums",
                        systemImage: "square.stack",
                        description: Text("ui.library.no_favorite_albums.message")
                    )
                }
            }
        }
    }
}
