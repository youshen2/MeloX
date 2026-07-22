import SwiftUI

struct ArtistDetailView: View {
    let id: Int

    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library

    @State private var artist: Artist?
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    var body: some View {
        Group {
            switch phase {
            case .loading where artist == nil:
                ProgressView("正在载入歌手")
            case .failed(let message) where artist == nil:
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            default:
                if let artist {
                    content(artist)
                }
            }
        }
        .navigationTitle(artist?.name ?? "歌手")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reloadToken) {
            guard artist == nil else { return }
            await load()
        }
    }

    private func content(_ artist: Artist) -> some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ArtworkImage(url: artist.artworkURL, cornerRadius: 1_000)
                        .frame(width: 150, height: 150)
                    Text(artist.name)
                        .font(.title.bold())
                    if !artist.aliases.isEmpty {
                        Text(artist.aliases.joined(separator: " / "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await player.playAll(songs, sourceID: artist.id) }
                    } label: {
                        Text("播放热门歌曲")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(songs.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("热门歌曲") {
                ForEach(Array(songs.prefix(20).enumerated()), id: \.element.id) { index, song in
                    Button {
                        Task {
                            await player.play(song, in: songs, sourceID: artist.id)
                        }
                    } label: {
                        TrackRowView(song: song, index: index)
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

            Section("专辑") {
                ForEach(albums) { album in
                    NavigationLink(value: MusicRoute.album(album)) {
                        HStack(spacing: 12) {
                            ArtworkImage(url: album.artworkURL, cornerRadius: 7)
                                .frame(width: 54, height: 54)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(album.name)
                                    .lineLimit(1)
                                Text(album.type ?? "专辑")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .musicMatchedTransitionSource(for: MusicRoute.album(album))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func load() async {
        phase = .loading
        do {
            (artist, songs, albums) = try await api.artist(id: id)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
