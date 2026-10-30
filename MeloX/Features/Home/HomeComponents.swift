import SwiftUI

struct HomeEditorialCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let systemImage: String
    let colors: [Color]
    let isCompact: Bool

    @ScaledMetric(relativeTo: .body) private var compactCardHeight = 132.0

    var body: some View {
        Group {
            if isCompact {
                compactContent
            } else {
                standardContent
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            Text(title)
                .font(.headline)
                .lineLimit(2)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: compactCardHeight)
        .background {
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(.rect(cornerRadius: 14))
    }

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: systemImage)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.24))
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .padding(18)
            }
            .aspectRatio(1.48, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 14))
            .padding(.top, 8)
        }
    }
}

struct HomePlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        MediaCardView(
            title: playlist.name,
            subtitle:
                playlist.copywriter
                ?? playlist.updateFrequency
                ?? playlist.creator?.nickname,
            artworkURL: playlist.artworkURL,
            artworkSize: 166
        )
        .frame(width: 166)
    }
}
