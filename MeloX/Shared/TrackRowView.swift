import SwiftUI

struct TrackRowView: View {
    let song: Song
    var index: Int?
    var showsArtwork = false

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(song.name)，\(song.artistText)")
    }
}
