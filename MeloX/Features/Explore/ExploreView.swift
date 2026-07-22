import SwiftUI

struct ExploreView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(AppSettings.self) private var settings

    @State private var category = "推荐歌单"
    @State private var playlists: [Playlist] = []
    @State private var playlistsByCategory: [String: [Playlist]] = [:]
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var loadedCategory: String?

    private let categories = [
        "推荐歌单", "排行榜", "精品歌单", "全部", "华语", "欧美", "流行",
        "摇滚", "民谣", "电子", "轻音乐", "影视原声", "ACG",
    ]
    private let columns = [
        GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                ExploreCategoryPicker(
                    categories: categories,
                    selection: category,
                    select: selectCategory
                )

                categoryContent
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .navigationTitle("发现")
        .refreshable {
            await load(category: category, force: true)
        }
        .task(id: ExploreLoadRequest(category: category, token: reloadToken)) {
            await load(category: category)
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        if playlists.isEmpty {
            switch phase {
            case .loading:
                ProgressView("正在发现好音乐")
                    .frame(maxWidth: .infinity, minHeight: 320)
            case .failed(let message):
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
                .frame(maxWidth: .infinity, minHeight: 320)
            case .loaded:
                ContentUnavailableView("暂无歌单", systemImage: "music.note.list")
                    .frame(maxWidth: .infinity, minHeight: 320)
            }
        } else {
            if let featuredPlaylist = playlists.first {
                ExploreFeaturedPlaylistView(
                    playlist: featuredPlaylist,
                    badge: featuredBadge,
                    showsPlayCount: settings.showPlayCount
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(collectionTitle)
                        .font(.title2.bold())

                    Spacer()

                    Text("\(playlists.count) 个歌单")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                    ForEach(playlists.dropFirst()) { playlist in
                        NavigationLink(value: MusicRoute.playlist(playlist)) {
                            ExplorePlaylistCardView(
                                playlist: playlist,
                                showsPlayCount: settings.showPlayCount
                            )
                        }
                        .buttonStyle(.plain)
                        .musicMatchedTransitionSource(for: MusicRoute.playlist(playlist))
                    }
                }
            }

            if phase == .loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var featuredBadge: String {
        switch category {
        case "推荐歌单": "今日推荐"
        case "排行榜": "热门榜单"
        case "精品歌单": "编辑精选"
        default: category
        }
    }

    private var collectionTitle: String {
        switch category {
        case "推荐歌单": "更多推荐"
        case "排行榜": "全部榜单"
        case "精品歌单": "更多精品"
        case "全部": "热门歌单"
        default: "\(category)歌单"
        }
    }

    private func selectCategory(_ newCategory: String) {
        guard category != newCategory else { return }
        category = newCategory

        if let cached = playlistsByCategory[newCategory] {
            playlists = cached
            loadedCategory = newCategory
            phase = .loaded
        } else {
            playlists = []
            loadedCategory = nil
            phase = .loading
        }
    }

    private func load(category requestedCategory: String, force: Bool = false) async {
        if !force, loadedCategory == requestedCategory {
            return
        }
        if !force, let cached = playlistsByCategory[requestedCategory] {
            playlists = cached
            loadedCategory = requestedCategory
            phase = .loaded
            return
        }

        phase = .loading
        do {
            let loadedPlaylists = try await api.playlists(category: requestedCategory, limit: 50)
            try Task.checkCancellation()
            playlistsByCategory[requestedCategory] = loadedPlaylists
            guard category == requestedCategory else { return }
            playlists = loadedPlaylists
            loadedCategory = requestedCategory
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard category == requestedCategory else { return }
            phase = .failed(error.localizedDescription)
        }
    }
}

private struct ExploreLoadRequest: Hashable {
    let category: String
    let token: Int
}
