import SwiftUI

struct ExploreView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(AppSettings.self) private var settings

    let showsNavigationTitle: Bool
    let navigationTitle: String

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

    init(
        showsNavigationTitle: Bool = true,
        navigationTitle: String = L10n.string("ui.navigation.discover")
    ) {
        self.showsNavigationTitle = showsNavigationTitle
        self.navigationTitle = navigationTitle
    }

    @ViewBuilder
    var body: some View {
        if showsNavigationTitle {
            content
                .navigationTitle(navigationTitle)
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                ExploreCategoryPicker(
                    categories: categories,
                    selection: category,
                    select: selectCategory
                )

                categoryContent
                    .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
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
                ProgressView("ui.explore.loading")
                    .frame(maxWidth: .infinity, minHeight: 320)
            case .failed(let message):
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
                .frame(maxWidth: .infinity, minHeight: 320)
            case .loaded:
                ContentUnavailableView("ui.playlists.empty", systemImage: "music.note.list")
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

                    Text(L10n.format("ui.common.playlist_count", playlists.count))
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
        case "推荐歌单": L10n.string("ui.explore.badge.today")
        case "排行榜": L10n.string("ui.explore.badge.popular_toplists")
        case "精品歌单": L10n.string("ui.explore.badge.editors_choice")
        default: localizedPlaylistCategory(category)
        }
    }

    private var collectionTitle: String {
        switch category {
        case "推荐歌单": L10n.string("ui.explore.more_recommendations")
        case "排行榜": L10n.string("ui.toplists.all")
        case "精品歌单": L10n.string("ui.explore.more_featured")
        case "全部": L10n.string("ui.explore.popular_playlists")
        default: L10n.format("ui.explore.category_playlists", localizedPlaylistCategory(category))
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
