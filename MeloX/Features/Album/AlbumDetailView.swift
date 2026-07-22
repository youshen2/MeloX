import SwiftUI

struct AlbumDetailView: View {
    let id: Int

    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library

    @State private var album: Album?
    @State private var songs: [Song] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    var body: some View {
        Group {
            switch phase {
            case .loading where album == nil:
                ProgressView("正在载入专辑")
            case .failed(let message) where album == nil:
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            default:
                if let album {
                    content(album)
                }
            }
        }
        .navigationTitle(album?.name ?? "专辑")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reloadToken) {
            guard album == nil else { return }
            await load()
        }
    }

    private func content(_ album: Album) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        ArtworkImage(url: album.artworkURL, cornerRadius: 12)
                            .frame(width: 132, height: 132)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(album.name)
                                .font(.title2.bold())
                            if let artist = album.artists.first {
                                NavigationLink(value: MusicRoute.artist(artist.id)) {
                                    Text(album.artistText)
                                }
                            } else {
                                Text(album.artistText)
                            }
                            if let publishTime = album.publishTime {
                                Text(Date(timeIntervalSince1970: publishTime / 1_000), format: .dateTime.year().month().day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let description = album.albumDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }

                    Button {
                        Task { await player.playAll(songs) }
                    } label: {
                        Text("播放全部")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(songs.isEmpty)
                }
                .padding(.vertical, 8)
            }

            Section("歌曲") {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    Button {
                        Task { await player.play(song, in: songs) }
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
        }
        .listStyle(.insetGrouped)
    }

    private func load() async {
        phase = .loading
        do {
            (album, songs) = try await api.album(id: id)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
