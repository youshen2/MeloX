import SwiftUI

struct QueueView: View {
    @Environment(PlayerStore.self) private var player

    var body: some View {
        List(Array(player.queue.enumerated()), id: \.element.id) { index, song in
            Button {
                Task { await player.playFromQueue(at: index) }
            } label: {
                HStack {
                    TrackRowView(song: song, showsArtwork: true)
                    if index == player.currentIndex {
                        Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                            .foregroundStyle(.tint)
                            .accessibilityLabel("当前歌曲")
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .navigationTitle("接下来播放")
        .overlay {
            if player.queue.isEmpty {
                ContentUnavailableView("播放队列为空", systemImage: "list.bullet")
            }
        }
    }
}
