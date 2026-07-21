import SwiftUI

struct AddToPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var library

    let song: Song

    @State private var addingToPlaylistID: Playlist.ID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("添加到歌单")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }
        }
        .interactiveDismissDisabled(addingToPlaylistID != nil)
        .alert(
            "添加失败",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    @ViewBuilder
    private var content: some View {
        if !library.isLoggedIn {
            ContentUnavailableView(
                "需要登录",
                systemImage: "person.crop.circle.badge.exclamationmark",
                description: Text("登录网易云音乐后，才能把歌曲添加到自己的歌单。")
            )
        } else if library.phase == .loading, library.ownedPlaylists.isEmpty {
            ProgressView("正在读取歌单")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if library.ownedPlaylists.isEmpty {
            ContentUnavailableView {
                Label("没有可选歌单", systemImage: "music.note.list")
            } description: {
                Text(library.errorMessage ?? "请先在网易云音乐中创建一个歌单。")
            } actions: {
                Button("重新加载") {
                    Task {
                        await library.refresh(force: true)
                    }
                }
            }
        } else {
            List(library.ownedPlaylists) { playlist in
                Button {
                    Task {
                        await addSong(to: playlist)
                    }
                } label: {
                    HStack(spacing: 12) {
                        ArtworkImage(url: playlist.artworkURL, cornerRadius: 7)
                            .frame(width: 52, height: 52)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(playlist.name)
                                .lineLimit(1)

                            Text("\(playlist.trackCount) 首歌曲")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if addingToPlaylistID == playlist.id {
                            ProgressView()
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .disabled(addingToPlaylistID != nil)
                .accessibilityLabel("添加到\(playlist.name)，\(playlist.trackCount) 首歌曲")
            }
            .listStyle(.plain)
            .refreshable {
                await library.refresh(force: true)
            }
        }
    }

    private func addSong(to playlist: Playlist) async {
        guard addingToPlaylistID == nil else { return }
        addingToPlaylistID = playlist.id
        defer { addingToPlaylistID = nil }

        do {
            try await library.add(song: song, to: playlist)
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
