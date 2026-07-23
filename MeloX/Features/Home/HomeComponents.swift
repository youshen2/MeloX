import SwiftUI

struct HomeEditorialCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let systemImage: String
    let colors: [Color]

    var body: some View {
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .padding(18)
            }
            .aspectRatio(1.48, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 14))
            .padding(.top, 8)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct HomeFeaturedPlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("编辑推荐")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(playlist.name)
                .font(.title3)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(playlist.copywriter ?? playlist.creator?.nickname ?? "网易云音乐歌单")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ArtworkImage(url: playlist.artworkURL, cornerRadius: 14, aspectRatio: 1.48)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.48, contentMode: .fit)
                .clipped()
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct HomeHorizontalSection<Content: View>: View {
    let title: String
    var destination: MusicRoute?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: title, destination: destination)
                .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    content()
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
    }
}

struct HomePlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        MediaCardView(
            title: playlist.name,
            subtitle: playlist.copywriter ?? playlist.updateFrequency ?? playlist.creator?.nickname,
            artworkURL: playlist.artworkURL,
            artworkSize: 166
        )
        .frame(width: 166)
    }
}

struct HomeAlbumCard: View {
    let album: Album

    var body: some View {
        MediaCardView(
            title: album.name,
            subtitle: album.artistText,
            artworkURL: album.artworkURL,
            artworkSize: 166
        )
        .frame(width: 166)
    }
}

struct HomeArtistCard: View {
    let artist: Artist

    var body: some View {
        MediaCardView(
            title: artist.name,
            subtitle: artist.aliases.first ?? "歌手",
            artworkURL: artist.artworkURL,
            circular: true,
            artworkSize: 148
        )
        .frame(width: 148)
    }
}
