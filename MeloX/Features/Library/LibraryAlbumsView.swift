import SwiftUI
import UIKit

struct LibraryAlbumsView: View {
    let searchQuery: String

    @Environment(LibraryStore.self) private var library
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let query = normalizedLibrarySearchQuery(searchQuery)
        let albums = library.favoriteAlbums.filter { album in
            query.isEmpty
                || album.name.localizedCaseInsensitiveContains(query)
                || album.artistText.localizedCaseInsensitiveContains(query)
        }

        GeometryReader { geometry in
            if UIDevice.current.userInterfaceIdiom == .pad,
               geometry.size.width >= 600, !dynamicTypeSize.isAccessibilitySize {
                albumGrid(albums, width: geometry.size.width)
            } else {
                albumList(albums)
            }
        }
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

    private func albumList(_ albums: [Album]) -> some View {
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
    }

    private func albumGrid(_ albums: [Album], width: CGFloat) -> some View {
        let layout = MediaCardGridLayout(containerWidth: width, minimumItemWidth: 145)

        return ScrollView {
            LazyVGrid(columns: layout.columns, alignment: .leading, spacing: 24) {
                ForEach(albums) { album in
                    let route = MusicRoute.album(album)
                    NavigationLink(value: route) {
                        MediaCardView(
                            title: album.name,
                            subtitle: album.artistText,
                            artworkURL: album.artworkURL,
                            artworkSize: layout.itemWidth
                        )
                        .frame(width: layout.itemWidth)
                    }
                    .buttonStyle(.plain)
                    .musicMatchedTransitionSource(for: route)
                }
            }
            .padding(16)
        }
    }
}
