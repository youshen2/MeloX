import SwiftUI

struct PlaylistCategoryView: View {
    let category: String

    @Environment(NeteaseAPI.self) private var api

    @State private var playlists: [Playlist] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 16)]

    var body: some View {
        Group {
            switch phase {
            case .loading where playlists.isEmpty:
                ProgressView("正在载入\(category)歌单")
            case .failed(let message) where playlists.isEmpty:
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            default:
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                        ForEach(playlists) { playlist in
                            NavigationLink(value: MusicRoute.playlist(playlist.id)) {
                                MediaCardView(
                                    title: playlist.name,
                                    subtitle: playlist.creator?.nickname,
                                    artworkURL: playlist.artworkURL
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await load()
                }
            }
        }
        .navigationTitle(category)
        .task(id: reloadToken) {
            guard playlists.isEmpty else { return }
            await load()
        }
    }

    private func load() async {
        phase = .loading
        do {
            playlists = try await api.playlists(category: category, limit: 50)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
