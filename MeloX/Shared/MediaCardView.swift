import SwiftUI

struct MediaCardView: View {
    let title: String
    let subtitle: String?
    let artworkURL: URL?
    var circular = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkImage(url: artworkURL, cornerRadius: circular ? 1_000 : 10)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
