import SwiftUI

struct PodcastHomeView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library

    let showsNavigationTitle: Bool

    @State private var recommended: [Podcast] = []
    @State private var categories: [PodcastCategory] = []
    @State private var subscriptions: [Podcast] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @ScaledMetric(relativeTo: .headline) private var categoryMinimumWidth: CGFloat = 154

    private var categoryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: categoryMinimumWidth), spacing: 12)]
    }

    init(showsNavigationTitle: Bool = true) {
        self.showsNavigationTitle = showsNavigationTitle
    }

    @ViewBuilder
    var body: some View {
        if showsNavigationTitle {
            pageContent
                .navigationTitle("ui.navigation.podcasts")
                .navigationBarTitleDisplayMode(.large)
        } else {
            pageContent
        }
    }

    private var pageContent: some View {
        Group {
            if hasLoadedContent {
                content
            } else {
                initialState
            }
        }
        .task(
            id: PodcastHomeLoadRequest(
                reloadToken: reloadToken,
                isLoggedIn: library.isLoggedIn
            )
        ) {
            await load()
        }
        .onChange(of: library.subscribedPodcasts) {
            subscriptions = library.subscribedPodcasts
        }
    }

    private var hasLoadedContent: Bool {
        !recommended.isEmpty
            || !categories.isEmpty
            || !subscriptions.isEmpty
    }

    @ViewBuilder
    private var initialState: some View {
        switch phase {
        case .loading:
            ProgressView("ui.podcasts.discovering")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ConnectionUnavailableView(message: message) {
                reloadToken += 1
            }
        case .loaded:
            ContentUnavailableView(
                "ui.podcasts.no_recommendations",
                systemImage: "mic"
            )
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                if !subscriptions.isEmpty {
                    podcastStrip(
                        title: L10n.string("ui.podcasts.my_subscriptions"),
                        podcasts: subscriptions
                    )
                }

                if let featured = recommended.first {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ui.podcasts.featured")
                            .font(.title2.bold())

                        NavigationLink(
                            value: MusicRoute.podcast(featured)
                        ) {
                            FeaturedPodcastView(podcast: featured)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }

                if recommended.count > 1 {
                    podcastStrip(
                        title: L10n.string("ui.podcasts.for_you"),
                        podcasts: Array(recommended.dropFirst())
                    )
                }

                if !categories.isEmpty {
                    categorySection
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
        .refreshable {
            await load()
        }
    }

    private func podcastStrip(
        title: String,
        podcasts: [Podcast]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(podcasts) { podcast in
                        NavigationLink(
                            value: MusicRoute.podcast(podcast)
                        ) {
                            PodcastCardView(podcast: podcast)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ui.podcasts.browse_categories")
                .font(.title2.bold())

            LazyVGrid(columns: categoryColumns, spacing: 12) {
                ForEach(categories) { category in
                    NavigationLink(
                        value: MusicRoute.podcastCategory(category)
                    ) {
                        PodcastCategoryTile(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }

    private func load() async {
        if !hasLoadedContent {
            phase = .loading
        }

        async let loadedPersonalized =
            try? api.personalizedPodcasts(limit: 12)
        async let loadedCategories =
            try? api.podcastCategories()
        async let loadedSubscriptions =
            loadSubscriptionsIfNeeded()

        do {
            let featured = try await api.featuredPodcasts()
            let (personalized, categoryItems, subscribed) = await (
                loadedPersonalized,
                loadedCategories,
                loadedSubscriptions
            )
            try Task.checkCancellation()

            recommended = uniquePodcasts(
                featured + (personalized ?? [])
            )
            if let categoryItems {
                categories = categoryItems
            }
            if let subscribed {
                subscriptions = subscribed
            }
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            let (personalized, categoryItems, subscribed) = await (
                loadedPersonalized,
                loadedCategories,
                loadedSubscriptions
            )
            guard !Task.isCancelled else { return }
            if let personalized {
                recommended = uniquePodcasts(personalized)
            }
            if let categoryItems {
                categories = categoryItems
            }
            if let subscribed {
                subscriptions = subscribed
            }
            phase = hasLoadedContent
                ? .loaded
                : .failed(error.localizedDescription)
        }
    }

    private func loadSubscriptionsIfNeeded() async -> [Podcast]? {
        guard library.isLoggedIn else { return [] }
        guard let page = try? await api.subscribedPodcasts(limit: 50)
        else {
            return nil
        }
        return page.podcasts.map { podcast in
            var subscribedPodcast = podcast
            subscribedPodcast.isSubscribed = true
            return subscribedPodcast
        }
    }

    private func uniquePodcasts(
        _ podcasts: [Podcast]
    ) -> [Podcast] {
        var seen: Set<Int> = []
        return podcasts.filter {
            $0.id > 0 && seen.insert($0.id).inserted
        }
    }
}

private struct PodcastHomeLoadRequest: Hashable {
    let reloadToken: Int
    let isLoggedIn: Bool
}
