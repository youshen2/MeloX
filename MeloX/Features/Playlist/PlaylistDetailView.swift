import SwiftUI

struct PlaylistDetailView: View {
    let id: Int

    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library

    @State private var playlist: Playlist?
    @State private var phase: LoadingPhase = .loading
    @State private var query = ""
    @State private var reloadToken = 0

    var body: some View {
        Group {
            switch phase {
            case .loading where playlist == nil:
                ProgressView("正在载入歌单")
            case .failed(let message) where playlist == nil:
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            default:
                if let playlist {
                    playlistContent(playlist)
                }
            }
        }
        .navigationTitle(playlist?.name ?? "歌单")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "在歌单中搜索")
        .task(id: reloadToken) {
            guard playlist == nil else { return }
            await load()
        }
    }

    private func playlistContent(_ playlist: Playlist) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        ArtworkImage(url: playlist.artworkURL, cornerRadius: 12)
                            .frame(width: 132, height: 132)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(playlist.name)
                                .font(.title2.bold())
                            if let creator = playlist.creator {
                                Text(creator.nickname)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(playlist.trackCount) 首歌曲")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let description = playlist.playlistDescription,
                       !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }

                    HStack {
                        Button {
                            Task { await player.playAll(playlist.tracks) }
                        } label: {
                            Text("播放全部")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(playlist.tracks.isEmpty)

                        Button {
                            library.toggle(playlist: playlist)
                        } label: {
                            Label(
                                library.contains(playlist: playlist) ? "已收藏" : "收藏",
                                systemImage: library.contains(playlist: playlist) ? "heart.fill" : "heart"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("歌曲") {
                ForEach(filteredTracks) { song in
                    Button {
                        Task { await player.play(song, in: playlist.tracks) }
                    } label: {
                        TrackRowView(song: song, showsArtwork: true)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button {
                            library.toggle(song: song)
                        } label: {
                            Label(
                                library.contains(song: song) ? "取消收藏" : "收藏",
                                systemImage: library.contains(song: song) ? "heart.slash" : "heart"
                            )
                        }
                        .tint(.pink)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await load()
        }
    }

    private var filteredTracks: [Song] {
        guard let tracks = playlist?.tracks else { return [] }
        let keywords = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keywords.isEmpty else { return tracks }
        return tracks.filter { song in
            song.name.localizedCaseInsensitiveContains(keywords)
                || song.artistText.localizedCaseInsensitiveContains(keywords)
                || (song.album?.name.localizedCaseInsensitiveContains(keywords) ?? false)
        }
    }

    private func load() async {
        phase = .loading
        do {
            playlist = try await api.playlist(id: id)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
