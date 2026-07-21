import SwiftUI

struct NowPlayingArtworkPage: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let song: Song

    var body: some View {
        GeometryReader { proxy in
            let artworkSize = max(
                170,
                min(proxy.size.width - 28, proxy.size.height - 104)
            )

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                ArtworkImage(url: song.album?.artworkURL, cornerRadius: 12)
                    .frame(width: artworkSize, height: artworkSize)
                    .scaleEffect(player.isPlaying || !settings.shrinksPausedArtwork ? 1 : 0.9)
                    .shadow(color: .black.opacity(0.24), radius: 22, y: 12)
                    .animation(.smooth(duration: 0.45), value: player.isPlaying)

                Spacer(minLength: 22)

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.name)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)

                        Text(song.artistText)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    NowPlayingSongActions(song: song)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

struct NowPlayingSongActions: View {
    @Environment(LibraryStore.self) private var library

    let song: Song

    @State private var songForPlaylistSelection: Song?

    var body: some View {
        HStack(spacing: 10) {
            Button {
                library.toggle(song: song)
            } label: {
                Image(systemName: library.contains(song: song) ? "star.fill" : "star")
                    .font(.title3.weight(.medium))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.13), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(library.contains(song: song) ? "取消收藏" : "收藏")

            Menu {
                Button {
                    songForPlaylistSelection = song
                } label: {
                    Label("添加到歌单", systemImage: "text.badge.plus")
                }

                ShareLink(item: "\(song.name) — \(song.artistText)") {
                    Label("分享歌曲信息", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.13), in: .circle)
                    .contentShape(.circle)
            }
            .accessibilityLabel("更多")
        }
        .sheet(item: $songForPlaylistSelection) { selectedSong in
            AddToPlaylistSheet(song: selectedSong)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
