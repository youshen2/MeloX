import SwiftUI

struct NowPlayingSongDetailsPage: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(\.openMusicRoute) private var openMusicRoute

    let song: Song
    let showsArtworkToggle: Bool
    let artworkNamespace: Namespace.ID
    let onShowArtwork: () -> Void

    @State private var loadedSong: Song?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if showsArtworkToggle {
                    detailsHeader
                }

                HStack {
                    Text("歌曲资料")
                        .font(.title2.bold())

                    Spacer()

                    NowPlayingSongActions(
                        song: displayedSong,
                        isShowingDetails: true,
                        onToggleDetails: onShowArtwork
                    )
                }

                detailsCard
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .task(id: song.id) {
            await loadDetails()
        }
    }

    private var displayedSong: Song {
        guard loadedSong?.id == song.id else { return song }
        return loadedSong ?? song
    }

    private var detailsHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onShowArtwork) {
                ArtworkImage(url: displayedSong.album?.artworkURL, cornerRadius: 10)
                    .matchedGeometryEffect(
                        id: song.id,
                        in: artworkNamespace,
                        properties: .frame
                    )
                    .frame(width: 82, height: 82)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回封面")
            .accessibilityHint("轻点切换回大封面")

            VStack(alignment: .leading, spacing: 5) {
                Text(displayedSong.name)
                    .font(.title3.bold())
                    .lineLimit(2)

                Text(displayedSong.artistText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(2)

                if !displayedSong.aliases.isEmpty {
                    Text(displayedSong.aliases.joined(separator: " / "))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(displayedSong.artists.enumerated()), id: \.element.id) { index, artist in
                if index > 0 {
                    Divider().overlay(.white.opacity(0.12))
                }
                destinationRow(
                    title: "歌手",
                    value: artist.name,
                    route: .artist(artist.id)
                )
            }

            if let album = displayedSong.album {
                Divider().overlay(.white.opacity(0.12))
                destinationRow(
                    title: "专辑",
                    value: album.name,
                    route: .album(album)
                )
            }

            if let publishTime = displayedSong.publishTime ?? displayedSong.album?.publishTime {
                Divider().overlay(.white.opacity(0.12))
                valueRow(
                    title: "发行日期",
                    value: Date(timeIntervalSince1970: publishTime / 1_000).formatted(
                        .dateTime.year().month().day()
                    )
                )
            }

        }
        .padding(.horizontal, 16)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
    }

    private func destinationRow(
        title: String,
        value: String,
        route: MusicRoute
    ) -> some View {
        Button {
            openMusicRoute(route)
        } label: {
            HStack(spacing: 10) {
                Text(title)
                Spacer(minLength: 12)
                Text(value)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.36))
            }
            .frame(minHeight: 46)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("收起播放器并打开\(title)详情")
    }

    private func valueRow(title: String, value: String) -> some View {
        LabeledContent(title, value: value)
            .frame(minHeight: 46)
    }

    private func loadDetails() async {
        loadedSong = nil
        do {
            loadedSong = try await api.songDetails(ids: [song.id]).first
        } catch is CancellationError {
            return
        } catch {
            // 播放队列中的歌曲数据仍可展示基础资料。
        }
    }
}
