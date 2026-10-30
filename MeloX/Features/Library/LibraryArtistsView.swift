import SwiftUI

struct LibraryArtistsView: View {
    @Environment(LibraryStore.self) private var library
    let searchQuery: String

    var body: some View {
        let query = normalizedLibrarySearchQuery(searchQuery)
        let artists = library.favoriteArtists.filter {
            query.isEmpty || ([$0.name] + $0.aliases).contains { $0.localizedCaseInsensitiveContains(query) }
        }

        List(artists) { artist in
            NavigationLink(value: MusicRoute.artist(artist.id)) {
                HStack(spacing: 12) {
                    ArtworkImage(url: artist.artworkURL, cornerRadius: 1_000)
                        .frame(width: 54, height: 54)
                    Text(artist.name)
                        .lineLimit(1)
                }
            }
            .musicMatchedTransitionSource(for: .artist(artist.id))
        }
        .listStyle(.plain)
        .refreshable { await library.refresh(force: true) }
        .overlay {
            if library.phase == .loading, library.favoriteArtists.isEmpty {
                ProgressView("ui.library.loading")
            } else if artists.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView("ui.library.artists.empty", systemImage: "music.mic")
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
    }
}
