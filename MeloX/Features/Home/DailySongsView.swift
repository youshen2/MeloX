import SwiftUI

struct DailySongsView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library

    @State private var songs: [Song] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView("正在载入每日推荐")
            case .failed(let message):
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            case .loaded:
                List {
                    Section {
                        Button {
                            Task { await player.playAll(songs) }
                        } label: {
                            Label("播放全部", systemImage: "play.fill")
                        }
                        .disabled(songs.isEmpty)
                    }
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        Button {
                            Task { await player.play(song, in: songs) }
                        } label: {
                            TrackRowView(song: song, index: index, showsArtwork: true)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button {
                                library.toggle(song: song)
                            } label: {
                                Label("收藏", systemImage: library.contains(song: song) ? "heart.slash" : "heart")
                            }
                            .tint(.pink)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("每日推荐")
        .task(id: reloadToken) {
            guard phase != .loaded else { return }
            await load()
        }
    }

    private func load() async {
        phase = .loading
        do {
            songs = try await api.dailySongs()
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
