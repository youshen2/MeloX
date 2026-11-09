import SwiftUI

struct ExploreCategoryPicker: View {
    let categories: [String]
    let selection: String
    let select: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button(categoryTitle(for: category)) {
                        select(category)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.regular)
                    .tint(category == selection ? .accentColor : Color.secondary.opacity(0.14))
                    .foregroundStyle(category == selection ? .white : .primary)
                    .accessibilityAddTraits(category == selection ? .isSelected : [])
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollIndicators(.hidden)
    }

    private func categoryTitle(for category: String) -> String {
        switch category {
        case "推荐歌单": L10n.string("ui.navigation.recommended")
        case "精品歌单": L10n.string("ui.category.featured_short")
        default: localizedPlaylistCategory(category)
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
        .accessibilityLabel(
            L10n.format(
                "ui.accessibility.badge_and_title",
                badge,
                playlist.name
            )
        )
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

            Text(playlist.updateFrequency ?? playlist.creator?.nickname ?? L10n.format("ui.common.song_count", playlist.trackCount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private func playCountText(_ count: Int) -> String {
    count.formatted(
        .number
            .notation(.compactName)
            .locale(L10n.locale)
    )
}
