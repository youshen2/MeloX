import SwiftUI

struct ExploreCategoryPicker: View {
    let categories: [String]
    let selection: String
    let select: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button(categoryTitle(for: category)) {
                        select(category)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(category == selection ? .accentColor : Color.secondary.opacity(0.14))
                    .foregroundStyle(category == selection ? .white : .primary)
                    .accessibilityAddTraits(category == selection ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func categoryTitle(for category: String) -> String {
        switch category {
        case "推荐歌单": "推荐"
        case "精品歌单": "精品"
        default: category
        }
    }
}

struct ExploreFeaturedPlaylistView: View {
    let playlist: Playlist
    let badge: String
    let showsPlayCount: Bool

    var body: some View {
        NavigationLink(value: MusicRoute.playlist(playlist)) {
            ZStack(alignment: .bottomLeading) {
                ArtworkImage(
                    url: playlist.artworkURL,
                    cornerRadius: 22,
                    aspectRatio: 1.55
                )

                LinearGradient(
                    colors: [.clear, .black.opacity(0.78)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(.rect(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 6) {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.78))

                    Text(playlist.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let subtitle = playlist.updateFrequency ?? playlist.creator?.nickname {
                            Text(subtitle)
                                .lineLimit(1)
                        }

                        if showsPlayCount, playlist.playCount > 0 {
                            Label(playCountText(playlist.playCount), systemImage: "play.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                }
                .padding(20)
                .padding(.trailing, 20)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .musicMatchedTransitionSource(for: MusicRoute.playlist(playlist))
        .accessibilityLabel("\(badge)，\(playlist.name)")
    }
}

struct ExplorePlaylistCardView: View {
    let playlist: Playlist
    let showsPlayCount: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkImage(url: playlist.artworkURL, cornerRadius: 12)
                .overlay(alignment: .topTrailing) {
                    if showsPlayCount, playlist.playCount > 0 {
                        Label(playCountText(playlist.playCount), systemImage: "play.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.48), in: .capsule)
                            .padding(8)
                    }
                }

            Text(playlist.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(playlist.updateFrequency ?? playlist.creator?.nickname ?? "\(playlist.trackCount) 首歌曲")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private func playCountText(_ count: Int) -> String {
    switch count {
    case 100_000_000...:
        return "\(formattedCount(Double(count) / 100_000_000))亿"
    case 10_000...:
        return "\(formattedCount(Double(count) / 10_000))万"
    default:
        return "\(count)"
    }
}

private func formattedCount(_ value: Double) -> String {
    if value >= 10 || value.rounded() == value {
        return String(Int(value.rounded()))
    }
    return value.formatted(.number.precision(.fractionLength(1)))
}
