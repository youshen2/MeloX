import SwiftUI

struct ToplistsView: View {
    @Environment(NeteaseAPI.self) private var api

    @State private var playlists: [Playlist] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    private var officialToplists: [Playlist] {
        playlists.filter(\.isOfficialToplist)
    }

    private var globalToplists: [Playlist] {
        playlists.filter { !$0.isOfficialToplist }
    }

    var body: some View {
        Group {
            switch phase {
            case .loading where playlists.isEmpty:
                ProgressView("正在载入排行榜")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message) where playlists.isEmpty:
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            default:
                content
            }
        }
        .navigationTitle("排行榜")
        .navigationBarTitleDisplayMode(.large)
        .task(id: reloadToken) {
            guard playlists.isEmpty else { return }
            await load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if playlists.isEmpty {
            ContentUnavailableView("暂无榜单", systemImage: "chart.bar")
        } else {
            GeometryReader { proxy in
                let layout = MediaCardGridLayout(
                    containerWidth: proxy.size.width,
                    minimumItemWidth: 148
                )

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        if officialToplists.isEmpty {
                            ToplistGridSection(
                                title: "全部榜单",
                                playlists: playlists,
                                layout: layout
                            )
                        } else {
                            ToplistGridSection(
                                title: "官方榜",
                                playlists: officialToplists,
                                layout: layout
                            )

                            if !globalToplists.isEmpty {
                                ToplistGridSection(
                                    title: "全球榜",
                                    playlists: globalToplists,
                                    layout: layout
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await load()
                }
            }
        }
    }

    private func load() async {
        phase = .loading
        do {
            let loadedPlaylists = try await api.toplists()
            try Task.checkCancellation()
            playlists = loadedPlaylists
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

private struct ToplistGridSection: View {
    let title: String
    let playlists: [Playlist]
    let layout: MediaCardGridLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.bold())

                Spacer()

                Text("\(playlists.count) 个榜单")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: layout.columns,
                alignment: .leading,
                spacing: 22
            ) {
                ForEach(playlists) { playlist in
                    NavigationLink(value: MusicRoute.toplist(playlist)) {
                        MediaCardView(
                            title: playlist.name,
                            subtitle: playlist.updateFrequency ?? "\(playlist.trackCount) 首歌曲",
                            artworkURL: playlist.artworkURL,
                            artworkSize: layout.itemWidth
                        )
                        .frame(width: layout.itemWidth)
                    }
                    .buttonStyle(.plain)
                    .musicMatchedTransitionSource(for: MusicRoute.toplist(playlist))
                    .accessibilityHint("查看榜单歌曲")
                }
            }
        }
    }
}
