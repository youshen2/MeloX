import SwiftUI

struct NewAlbumsView: View {
    @Environment(NeteaseAPI.self) private var api

    @State private var albums: [Album] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 16)]

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView("正在载入新碟")
            case .failed(let message):
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            case .loaded:
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                        ForEach(albums) { album in
                            NavigationLink(value: MusicRoute.album(album)) {
                                MediaCardView(
                                    title: album.name,
                                    subtitle: album.artistText,
                                    artworkURL: album.artworkURL
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("新碟上架")
        .task(id: reloadToken) {
            guard phase != .loaded else { return }
            await load()
        }
    }

    private func load() async {
        phase = .loading
        do {
            albums = try await api.newAlbums(limit: 100)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
