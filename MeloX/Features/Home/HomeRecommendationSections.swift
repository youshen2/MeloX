import SwiftUI

struct HomeRecommendationSectionView: View {
    @Environment(PlayerStore.self) private var player

    let section: HomeRecommendationSection

    var body: some View {
        switch section.content {
        case .playlists(let playlists):
            playlistSection(playlists)
        case .songs(let songs):
            songSection(songs)
        case .podcastPrograms(let programs):
            podcastSection(programs)
        }
    }

    private func playlistSection(
        _ playlists: [Playlist]
    ) -> some View {
        HomeMediaStrip(title: section.title) {
            ForEach(playlists) { playlist in
                let route = playlistRoute(for: playlist)
                NavigationLink(value: route) {
                    HomePlaylistCard(playlist: playlist)
                }
                .buttonStyle(.plain)
                .musicMatchedTransitionSource(for: route)
            }
        }
    }

    private func songSection(
        _ songs: [Song]
    ) -> some View {
        HomeMediaStrip(
            title: section.title,
            playAll: {
                Task { await player.playAll(songs) }
            }
        ) {
            ForEach(songs) { song in
                Button {
                    Task { await player.play(song, in: songs) }
                } label: {
                    HomeSongCard(song: song)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func podcastSection(
        _ programs: [PodcastProgram]
    ) -> some View {
        HomeMediaStrip(title: section.title) {
            ForEach(programs) { program in
                NavigationLink(
                    value: MusicRoute.podcastProgram(program)
                ) {
                    HomePodcastProgramCard(program: program)
                }
                .buttonStyle(.plain)
                .musicMatchedTransitionSource(
                    for: MusicRoute.podcastProgram(program)
                )
            }
        }
    }

    private func playlistRoute(for playlist: Playlist) -> MusicRoute {
        section.slot == .charts
            ? .toplist(playlist)
            : .playlist(playlist)
    }
}

private struct HomeMediaStrip<Content: View>: View {
    @Environment(\.musicShelfLayout) private var layout
    let title: String
    var playAll: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.bold())

                Spacer()

                if let playAll {
                    Button(action: playAll) {
                        Label("ui.common.play_all", systemImage: "play.fill")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(L10n.format("ui.common.play_named", title))
                }
            }
            .padding(.horizontal, layout.horizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: layout.spacing) {
                    content()
                }
            }
            .contentMargins(.horizontal, layout.horizontalPadding, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
    }
}

private struct HomeSongCard: View {
    @Environment(\.musicShelfLayout) private var layout
    let song: Song

    var body: some View {
        MediaCardView(
            title: song.name,
            subtitle: song.artistText,
            artworkURL: song.album?.artworkURL,
            artworkSize: layout.artworkSize(compact: 154)
        )
        .frame(width: layout.artworkSize(compact: 154))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct HomePodcastProgramCard: View {
    @Environment(\.musicShelfLayout) private var layout
    let program: PodcastProgram

    var body: some View {
        MediaCardView(
            title: program.name,
            subtitle: program.radio.name,
            artworkURL: program.artworkURL,
            artworkSize: layout.artworkSize(compact: 154)
        )
        .frame(width: layout.artworkSize(compact: 154))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
