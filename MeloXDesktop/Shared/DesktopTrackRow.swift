import SwiftUI

struct DesktopTrackRow: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let song: Song
    let index: Int
    let songs: [Song]
    var sourceID: Int?
    var showsArtwork = false
    var showsAlbumColumn = true
    var displayNumber: String?
    var onRemoveSong: ((Song) -> Void)?
    var isHighlighted = false

    @State private var isHovered = false
    @State private var showsPlaylistCreation = false
    @State private var playlistError: String?

    private var isCurrent: Bool {
        model.player.currentSong?.id == song.id
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await model.player.play(
                        song,
                        in: songs,
                        sourceID: sourceID
                    )
                }
            } label: {
                ZStack {
                    if isHovered || isCurrent {
                        Image(
                            systemName: isCurrent && model.player.isPlaying
                                ? "waveform"
                                : "play.fill"
                        )
                        .foregroundStyle(isCurrent ? .red : .primary)
                    } else {
                        Text(displayNumber ?? L10n.integer(index + 1))
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.14),
                    value: isHovered
                )
            }
            .buttonStyle(.plain)
            .help(L10n.format("ui.common.play_named", song.name))

            if showsArtwork {
                DesktopArtworkView(url: song.album?.artworkURL, cornerRadius: 6)
                    .frame(width: 42, height: 42)
                    .scaleEffect(isHovered ? 1.025 : 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.system(size: 13.5, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? .red : .primary)
                    .lineLimit(1)
                Text(song.artistText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if !showsArtwork, showsAlbumColumn {
                Text(song.album?.name ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 180, alignment: .leading)
            }

            Text(song.durationText)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)

            songMenu
                .opacity(isHovered || isCurrent ? 1 : 0.16)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: showsArtwork ? 54 : 46)
        .background(
            isHighlighted
                ? Color.accentColor.opacity(0.16)
                : isHovered ? Color.primary.opacity(0.045) : .clear,
            in: .rect(cornerRadius: 8)
        )
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: isHovered
        )
        .onTapGesture(count: 2) {
            Task {
                await model.player.play(song, in: songs, sourceID: sourceID)
            }
        }
        .contextMenu { songMenuContent }
        .sheet(isPresented: $showsPlaylistCreation) {
            PlaylistCreationSheet { name, isPrivate in
                try await model.library.createPlaylist(name: name, isPrivate: isPrivate)
            }
        }
        .alert("ui.playlists.add_failed", isPresented: Binding(
            get: { playlistError != nil },
            set: { if !$0 { playlistError = nil } }
        )) {
            Button("ui.common.ok", role: .cancel) { playlistError = nil }
        } message: {
            Text(playlistError ?? "")
        }
    }

    private var songMenu: some View {
        Menu {
            songMenuContent
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 28, height: 28)
                .contentShape(.circle)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private var songMenuContent: some View {
        Button("ui.player.play_next", systemImage: "text.line.first.and.arrowtriangle.forward") {
            Task { await model.player.playNext(song) }
        }
        Button("ui.player.add_to_queue", systemImage: "text.badge.plus") {
            model.player.addToPlaybackQueue(song)
        }

        Menu("ui.playlists.add_to", systemImage: "text.badge.plus") {
            Button("ui.playlists.create.title", systemImage: "plus") { showsPlaylistCreation = true }
                .disabled(!model.library.isLoggedIn)
            Divider()
            if model.library.ownedPlaylists.isEmpty {
                Text("ui.playlists.none_available")
            } else {
                ForEach(model.library.ownedPlaylists) { playlist in
                    Button(playlist.name) {
                        Task {
                            do {
                                try await model.library.add(song: song, to: playlist)
                            } catch {
                                playlistError = error.localizedDescription
                            }
                        }
                    }
                }
            }
        }

        if let onRemoveSong {
            Button("ui.playlists.remove_song", systemImage: "minus.circle", role: .destructive) {
                onRemoveSong(song)
            }
        }

        Divider()
        Button(
            model.library.contains(song: song)
                ? L10n.string("ui.song.unlike")
                : L10n.string("ui.song.like"),
            systemImage: model.library.contains(song: song) ? "star.fill" : "star"
        ) {
            model.library.toggle(song: song)
        }
        Button("ui.common.download", systemImage: "arrow.down.circle") {
            model.downloads.start(song, quality: model.settings.quality)
        }

        Divider()
        Button("ui.song.view_information", systemImage: "info.circle") {
            model.ui.navigate(to: .song(song.id))
        }
        if let artist = song.artists.first {
            Button("ui.artist.go_to_generic", systemImage: "music.mic") {
                model.ui.navigate(to: .artist(artist.id))
            }
        }
        if let album = song.album {
            Button("ui.common.album", systemImage: "square.stack") {
                model.ui.navigate(to: .album(album.id))
            }
        }

        if let url = URL(string: "https://music.163.com/#/song?id=\(song.id)") {
            ShareLink(item: url) {
                Label("ui.common.share", systemImage: "square.and.arrow.up")
            }
        }
    }
}
