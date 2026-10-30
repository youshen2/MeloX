import SwiftUI

struct AddToPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var library

    let song: Song

    @State private var showsCreation = false
    @State private var addingToPlaylistID: Playlist.ID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("ui.playlists.add_to")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("ui.playlists.create.title", systemImage: "plus") { showsCreation = true }
                            .disabled(!library.isLoggedIn || addingToPlaylistID != nil)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("ui.common.cancel") {
                            dismiss()
                        }
                    }
                }
        }
        .sheet(isPresented: $showsCreation) {
            PlaylistCreationSheet { name, isPrivate in
                try await library.createPlaylist(name: name, isPrivate: isPrivate)
            }
            .presentationDetents([.medium])
        }
        .interactiveDismissDisabled(addingToPlaylistID != nil)
        .alert(
            "ui.playlists.add_failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? L10n.string("ui.common.unknown_error"))
        }
    }

    @ViewBuilder
    private var content: some View {
        if !library.isLoggedIn {
            ContentUnavailableView(
                "ui.account.login_required",
                systemImage: "person.crop.circle.badge.exclamationmark",
                description: Text("ui.playlists.login_to_add")
            )
        } else if library.phase == .loading, library.ownedPlaylists.isEmpty {
            ProgressView("ui.playlists.loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if library.ownedPlaylists.isEmpty {
            ContentUnavailableView {
                Label("ui.playlists.none_available", systemImage: "music.note.list")
            } description: {
                Text(library.errorMessage ?? L10n.string("ui.playlists.create_first"))
            } actions: {
                Button("ui.common.reload") {
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

                            Text(L10n.format("ui.common.song_count", playlist.trackCount))
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
                .accessibilityLabel(
                    L10n.format(
                        "ui.playlists.add_to_accessibility",
                        playlist.name,
                        playlist.trackCount
                    )
                )
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
