import SwiftUI

struct TrackRowView: View {
    @Environment(\.openMusicRoute) private var openMusicRoute

    let song: Song
    var index: Int?
    var showsArtwork = false

    @State private var commentSong: Song?

    var body: some View {
        HStack(spacing: 12) {
            if showsArtwork {
                ArtworkImage(url: song.album?.artworkURL, cornerRadius: 6)
                    .frame(width: 44, height: 44)
            } else if let index {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.body)
                    .lineLimit(1)
                Text(song.artistText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if song.durationMS > 0 {
                Text(song.durationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
        .contextMenu {
            Button {
                openMusicRoute(.song(song))
            } label: {
                Label("歌曲资料", systemImage: "info.circle")
            }

            Button {
                commentSong = song
            } label: {
                Label("评论", systemImage: "bubble.left.and.bubble.right")
            }
        }
        .sheet(item: $commentSong) { selectedSong in
            SongCommentsSheet(song: selectedSong)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(song.name)，\(song.artistText)")
        .accessibilityAction(named: "查看歌曲资料") {
            openMusicRoute(.song(song))
        }
        .accessibilityAction(named: "查看评论") {
            commentSong = song
        }
    }
}
