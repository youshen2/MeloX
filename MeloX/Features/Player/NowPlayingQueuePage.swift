import SwiftUI

struct NowPlayingQueuePage: View {
    @Environment(PlayerStore.self) private var player

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("接下来播放")
                    .font(.title2.bold())

                Spacer()

                Button {
                    player.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(player.isShuffled ? 0.24 : 0.1), in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isShuffled ? "关闭随机播放" : "开启随机播放")

                Button {
                    player.cycleRepeatMode()
                } label: {
                    Image(systemName: player.repeatMode.systemImage)
                        .frame(width: 40, height: 40)
                        .background(
                            .white.opacity(player.repeatMode == .off ? 0.1 : 0.24),
                            in: .circle
                        )
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.repeatMode.accessibilityTitle)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(player.queue.enumerated()), id: \.offset) { index, song in
                        Button {
                            Task { await player.playFromQueue(at: index) }
                        } label: {
                            HStack(spacing: 12) {
                                ArtworkImage(url: song.album?.artworkURL, cornerRadius: 6)
                                    .frame(width: 48, height: 48)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)

                                    Text(song.artistText)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.58))
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                if index == player.currentIndex {
                                    Image(
                                        systemName: player.isPlaying
                                            ? "speaker.wave.2.fill"
                                            : "speaker.fill"
                                    )
                                    .foregroundStyle(.white.opacity(0.72))
                                    .accessibilityLabel("当前歌曲")
                                }
                            }
                            .padding(.vertical, 8)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)

                        if index < player.queue.count - 1 {
                            Divider()
                                .overlay(.white.opacity(0.12))
                                .padding(.leading, 60)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .overlay {
                if player.queue.isEmpty {
                    ContentUnavailableView("播放队列为空", systemImage: "list.bullet")
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}
