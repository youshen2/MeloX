import SwiftUI

struct LibraryPlaylistsView: View {
    let searchQuery: String

    @Environment(LibraryStore.self) private var library

    @State private var showsCreation = false
    @State private var pendingDeletion: Playlist?
    @State private var isDeletingPlaylist = false
    @State private var deletionError: String?


    var body: some View {
        List {
            if !isSearching, let userID = library.profile?.id {
                Section("ui.library.section.mine") {
                    NavigationLink {
                        UserListeningRankView(userID: userID)
                    } label: {
                        Label(
                            "ui.library.my_listening_rank",
                            systemImage: "chart.bar.xaxis"
                        )
                    }
                    .accessibilityHint("ui.library.my_listening_rank.hint")
                }
            }

            Section(
                isSearching
                    ? L10n.string("ui.common.search_results")
                    : L10n.string("ui.common.playlists")
            ) {
                ForEach(displayedPlaylists) { playlist in
                    NavigationLink(value: MusicRoute.playlist(playlist)) {
                        LibraryPlaylistRow(playlist: playlist)
                    }
                    .musicMatchedTransitionSource(
                        for: MusicRoute.playlist(playlist)
                    )
                    .swipeActions(edge: .trailing) {
                        if library.canDelete(playlist) {
                            Button(role: .destructive) { pendingDeletion = playlist } label: {
                                Label("ui.playlists.delete.action", systemImage: "trash")
                            }
                        } else if library.canUnsubscribe(playlist) {
                            Button(role: .destructive) {
                                library.toggle(playlist: playlist)
                            } label: {
                                Label(
                                    L10n.string("ui.common.unfavorite"),
                                    systemImage: "heart.slash"
                                )
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .disabled(isDeletingPlaylist)
        .confirmationDialog(
            "ui.playlists.delete.title",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { playlist in
            Button("ui.playlists.delete.action", role: .destructive) {
                Task { await deletePlaylist(playlist) }
            }
            Button("ui.common.cancel", role: .cancel) {}
        } message: { playlist in
            Text(L10n.format("ui.playlists.delete.message", playlist.name))
        }
        .alert("ui.library.error.title", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("ui.common.ok", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "")
        }

        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("ui.playlists.create.title", systemImage: "plus") { showsCreation = true }
                    .disabled(!library.isLoggedIn)
            }
        }
        .sheet(isPresented: $showsCreation) {
            PlaylistCreationSheet { name, isPrivate in
                try await library.createPlaylist(name: name, isPrivate: isPrivate)
            }
            .presentationDetents([.medium])
        }
        .refreshable {
            await library.refresh(force: true)
        }
        .overlay {
            Group {
                if displayedPlaylists.isEmpty {
                    if isSearching {
                        ContentUnavailableView.search(
                            text: normalizedSearchQuery
                        )
                    } else {
                        ContentUnavailableView(
                            "ui.library.no_favorite_playlists",
                            systemImage: "music.note.list",
                            description: Text(
                                "ui.library.no_favorite_playlists.message"
                            )
                        )
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func deletePlaylist(_ playlist: Playlist) async {
        isDeletingPlaylist = true
        defer { isDeletingPlaylist = false }
        do {
            try await library.deletePlaylist(playlist)
        } catch {
            deletionError = error.localizedDescription
        }
    }

    private var normalizedSearchQuery: String {
        normalizedLibrarySearchQuery(searchQuery)
    }

    private var isSearching: Bool {
        !normalizedSearchQuery.isEmpty
    }

    private var displayedPlaylists: [Playlist] {
        filterLibraryPlaylists(
            library.favoritePlaylists,
            query: normalizedSearchQuery
        )
    }
}

private struct LibraryPlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: playlist.artworkURL, cornerRadius: 7)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .lineLimit(1)
                Text(L10n.format("ui.common.song_count", playlist.trackCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
