import SwiftUI

struct DesktopPlaylistDetailView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let playlistID: Int

    @State private var playlist: Playlist?
    @State private var pendingRemoval: Song?
    @State private var isRemovingTrack = false
    @State private var removalError: String?

    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadedTrackOffset = 0
    @State private var isLoadingMoreTracks = false
    @State private var loadMoreTracksError: String?
    @State private var isPreparingPlayback = false
    @State private var playbackErrorMessage: String?
    @State private var trackLocator = DesktopCollectionTrackLocator()
    @State private var songToLocate: Int?
    @State private var locateErrorMessage: String?

    private let trackPageSize = 100

    var body: some View {
        Group {
            if let playlist {
                ScrollViewReader { proxy in
                    ScrollView {
                        // Keep one lazy container for the track rows so appending
                        // a page does not remeasure nested lazy stacks.
                        VStack(alignment: .leading, spacing: 34) {
                            DesktopCollectionHeader(
                                artworkURL: playlist.artworkURL,
                                kind: playlist.isOfficialToplist
                                    ? L10n.string("ui.category.toplists")
                                    : L10n.string("ui.common.playlist"),
                                title: playlist.name,
                                subtitle: playlist.creator?.nickname,
                                metadata: metadata(for: playlist),
                                description: playlist.playlistDescription,
                                songs: songs,
                                sourceID: playlist.id,
                                isFavorite: model.library.contains(playlist: playlist),
                                favoriteAction: {
                                    model.library.toggle(playlist: playlist)
                                },
                                shareURL: URL(
                                    string: "https://music.163.com/#/playlist?id=\(playlist.id)"
                                ),
                                onPlayAll: { shuffled in
                                    await playAll(shuffled: shuffled)
                                }
                            )

                            Divider()
                            DesktopCollectionTrackList(
                                songs: songs,
                                sourceID: playlist.id,
                                footer: hasMoreTracks ? {
                                    AnyView(
                                        DesktopCollectionPaginationFooter(
                                            isLoading: isLoadingMoreTracks,
                                            failureMessage: loadMoreTracksError,
                                            loadToken: songToLocate == nil
                                                ? loadedTrackOffset
                                                : nil
                                        ) {
                                            await loadMoreTracks()
                                        }
                                    )
                                } : nil,
                                onRemoveSong: model.library.canDelete(playlist)
                                    && !isLoadingMoreTracks && songToLocate == nil
                                    ? { pendingRemoval = $0 }
                                    : nil,
                                highlightedSongID: trackLocator.highlightedSongID
                            )
                        }
                        .padding(.horizontal, 42)
                        .padding(.vertical, 34)
                    }
                    .contentMargins(.bottom, 48, for: .scrollContent)
                    .overlay(alignment: .bottomTrailing) {
                        let title = L10n.string(
                            songToLocate == nil
                                ? "ui.collection.locate_playing"
                                : "ui.collection.locating_playing"
                        )
                        Button(title, systemImage: "scope") {
                            songToLocate = currentSongID
                        }
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .disabled(
                            currentSongID == nil || isLoading
                                || isLoadingMoreTracks || songToLocate != nil
                        )
                        .help(title)
                        .padding(24)
                    }
                    .task(id: songToLocate) {
                        if let songToLocate {
                            await locateSong(songToLocate)
                        }
                    }
                    .task(id: trackLocator.request) {
                        await trackLocator.scroll(using: proxy, reduceMotion: reduceMotion)
                    }
                }
            } else if isLoading {
                DesktopDetailLoadingView(message: L10n.string("ui.playlists.loading"))
            } else {
                DesktopDetailErrorView(message: errorMessage ?? L10n.string("ui.error.unknown")) {
                    Task { await load() }
                }
            }
        }
        .desktopLoadingStatus(
            L10n.string("ui.collection.locating_playing"),
            isPresented: songToLocate != nil
        )
        .disabled(isRemovingTrack)
        .confirmationDialog(
            "ui.playlists.remove_song",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { song in
            Button("ui.playlists.remove_song", role: .destructive) {
                Task { await removeSong(song) }
            }
            Button("ui.common.cancel", role: .cancel) {}
        } message: { song in
            Text(L10n.format("ui.playlists.remove_song.message", song.name))
        }
        .alert("ui.library.error.title", isPresented: Binding(
            get: { removalError != nil },
            set: { if !$0 { removalError = nil } }
        )) {
            Button("ui.common.ok", role: .cancel) { removalError = nil }
        } message: {
            Text(removalError ?? "")
        }
        .navigationTitle(playlist?.name ?? L10n.string("ui.common.playlist"))
        .task(id: playlistID) { await load() }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.30),
            value: isLoading
        )
        .alert(
            L10n.string("ui.desktop.collection.play_all_failed"),
            isPresented: Binding(
                get: { playbackErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        playbackErrorMessage = nil
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                playbackErrorMessage = nil
            }
        } message: {
            Text(playbackErrorMessage ?? L10n.string("ui.playlists.load_complete_failed"))
        }
        .alert("ui.collection.locate_failed", isPresented: Binding(
            get: { locateErrorMessage != nil },
            set: { if !$0 { locateErrorMessage = nil } }
        )) {
            Button("ui.common.ok", role: .cancel) { locateErrorMessage = nil }
        } message: {
            Text(locateErrorMessage ?? "")
        }
    }

    private func metadata(for playlist: Playlist) -> String {
        var parts = [L10n.format("ui.common.song_count", playlist.trackCount)]
        if model.settings.showPlayCount {
            parts.append(L10n.format("ui.common.play_count", playlist.playCount))
        }
        return L10n.joined(
            parts,
            separatorKey: "ui.common.metadata_separator"
        )
    }

    private var hasMoreTracks: Bool {
        guard let playlist, !playlist.trackIDs.isEmpty else {
            return false
        }
        return loadedTrackOffset < playlist.trackIDs.count
    }

    private var currentSongID: Int? {
        guard let id = model.player.currentSong?.id,
              songs.contains(where: { $0.id == id })
                || playlist?.trackIDs.contains(where: { $0.id == id }) == true else {
            return nil
        }
        return id
    }

    private func locateSong(_ songID: Int) async {
        defer { songToLocate = nil }
        locateErrorMessage = nil

        do {
            if !songs.contains(where: { $0.id == songID }),
               let playlist,
               let index = playlist.trackIDs.firstIndex(where: { $0.id == songID }) {
                let endOffset = max(
                    loadedTrackOffset,
                    min((index / trackPageSize + 1) * trackPageSize, playlist.trackIDs.count)
                )
                let loadedSongs = try await model.api.songDetailsCollection(
                    ids: playlist.trackIDs.prefix(endOffset).map(\.id),
                    prefetched: songs
                )
                try Task.checkCancellation()
                guard self.playlist?.id == playlist.id else { return }
                songs = loadedSongs
                loadedTrackOffset = endOffset
                loadMoreTracksError = nil
            }

            guard songs.contains(where: { $0.id == songID }) else {
                locateErrorMessage = L10n.string("ui.collection.locate_unavailable")
                return
            }
            trackLocator.locate(songID)
        } catch is CancellationError {
            return
        } catch {
            locateErrorMessage = error.localizedDescription
        }
    }

    private func load() async {
        songToLocate = nil
        trackLocator.reset()
        locateErrorMessage = nil
        isLoading = true
        errorMessage = nil
        loadedTrackOffset = 0
        loadMoreTracksError = nil
        do {
            let detail = try await model.api.playlist(
                id: playlistID,
                trackLimit: trackPageSize
            )
            try Task.checkCancellation()
            playlist = detail
            songs = detail.tracks
            loadedTrackOffset = min(
                trackPageSize,
                detail.trackIDs.count
            )
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func removeSong(_ song: Song) async {
        guard let playlist, !isLoadingMoreTracks, songToLocate == nil else { return }
        isRemovingTrack = true
        defer { isRemovingTrack = false }
        do {
            try await model.library.remove(song: song, from: playlist)
            guard var updated = self.playlist else { return }
            if let index = updated.removeSong(id: song.id), index < loadedTrackOffset {
                loadedTrackOffset -= 1
            }
            self.playlist = updated
            songs.removeAll { $0.id == song.id }
        } catch {
            removalError = error.localizedDescription
        }
    }

    private func loadMoreTracks() async {
        guard let currentPlaylist = playlist,
              !isLoadingMoreTracks,
              !isRemovingTrack,
              songToLocate == nil,
              loadedTrackOffset < currentPlaylist.trackIDs.count else {
            return
        }

        let requestedOffset = loadedTrackOffset
        let trackIDs = currentPlaylist.trackIDs.map(\.id)
        isLoadingMoreTracks = true
        loadMoreTracksError = nil
        defer { isLoadingMoreTracks = false }

        do {
            let page = try await model.api.songDetailsPage(
                ids: trackIDs,
                offset: requestedOffset,
                limit: trackPageSize
            )
            try Task.checkCancellation()
            guard playlist?.id == currentPlaylist.id,
                  loadedTrackOffset == requestedOffset else {
                return
            }

            var loadedIDs = Set(songs.map(\.id))
            songs.append(
                contentsOf: page.songs.filter {
                    loadedIDs.insert($0.id).inserted
                }
            )
            loadedTrackOffset = page.nextOffset
        } catch is CancellationError {
            return
        } catch {
            loadMoreTracksError = error.localizedDescription
        }
    }

    private func playAll(shuffled: Bool) async {
        guard let currentPlaylist = playlist,
              !isPreparingPlayback else {
            return
        }

        isPreparingPlayback = true
        playbackErrorMessage = nil
        defer { isPreparingPlayback = false }

        do {
            let trackIDs = currentPlaylist.trackIDs.map(\.id)
            let completeSongs = if trackIDs.isEmpty {
                songs
            } else {
                try await model.api.songDetailsCollection(
                    ids: trackIDs,
                    prefetched: songs
                )
            }
            try Task.checkCancellation()
            guard playlist?.id == currentPlaylist.id else { return }
            await model.player.playAll(
                shuffled ? completeSongs.shuffled() : completeSongs,
                sourceID: currentPlaylist.id
            )
        } catch is CancellationError {
            return
        } catch {
            playbackErrorMessage = error.localizedDescription
        }
    }
}
