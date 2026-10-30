import Observation
import SwiftUI

@MainActor
@Observable
private final class DesktopSearchStore {
    var query = ""
    var kind: SearchKind = .songs
    var source: DesktopSearchSource = .catalog
    private(set) var payload: SearchPayload?
    private(set) var suggestions: [String] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private var activeSearchID: UUID?

    @ObservationIgnored
    private var resultCache = SearchResultCache()

    func search(using model: DesktopAppModel, debounced: Bool = false) async {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            activeSearchID = nil
            resultCache.clear()
            isSearching = false
            payload = nil
            errorMessage = nil
            return
        }

        let requestedKind = kind
        let requestedSource = source
        if requestedSource == .catalog,
           let cached = resultCache.value(for: keyword, kind: requestedKind) {
            activeSearchID = nil
            payload = cached
            errorMessage = nil
            isSearching = false
            return
        }

        let searchID = UUID()
        activeSearchID = searchID
        isSearching = true
        errorMessage = nil
        defer {
            if activeSearchID == searchID {
                isSearching = false
            }
        }

        do {
            if debounced {
                try await Task.sleep(for: .milliseconds(320))
            }
            try Task.checkCancellation()
            guard activeSearchID == searchID else { return }
            let loadedPayload: SearchPayload
            if requestedSource == .catalog {
                loadedPayload = try await model.api.search(
                    keyword,
                    kind: requestedKind,
                    limit: 60
                )
            } else {
                loadedPayload = libraryPayload(
                    matching: keyword,
                    model: model
                )
            }
            try Task.checkCancellation()
            guard activeSearchID == searchID else { return }
            if requestedSource == .catalog {
                resultCache.insert(loadedPayload, for: keyword, kind: requestedKind)
            }
            payload = loadedPayload
        } catch is CancellationError {
            return
        } catch {
            guard activeSearchID == searchID else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadSuggestions(using model: DesktopAppModel) async {
        suggestions = []
        let keywords = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard model.settings.searchSuggestionsEnabled,
              source == .catalog, !keywords.isEmpty else { return }
        do {
            try await Task.sleep(for: .milliseconds(300))
            let loaded = try await model.api.searchSuggestions(keywords)
            try Task.checkCancellation()
            suggestions = loaded
        } catch {
            return
        }
    }

    private func libraryPayload(
        matching keyword: String,
        model: DesktopAppModel
    ) -> SearchPayload {
        let library = model.library
        let songs = unique(
            library.favoriteSongs
                + (model.settings.isContentFeatureEnabled(
                    .listeningHistory
                ) ? library.recentSongs : []),
            by: \.id
        )
        let matchingSongs = songs.filter {
            matches(
                keyword,
                values: [$0.name, $0.artistText, $0.album?.name]
            )
        }
        let albums = unique(
            library.favoriteAlbums + songs.compactMap(\.album),
            by: \.id
        ).filter {
            matches(keyword, values: [$0.name, $0.artistText])
        }
        let artists = unique(
            library.favoriteArtists + songs.flatMap(\.artists),
            by: \.id
        ).filter {
            matches(keyword, values: [$0.name] + $0.aliases)
        }
        let playlists = library.favoritePlaylists.filter {
            matches(keyword, values: [$0.name, $0.creator?.nickname])
        }
        let podcasts = model.settings.isContentFeatureEnabled(.podcasts)
            ? library.subscribedPodcasts.filter {
                matches(keyword, values: [$0.name, $0.subtitle])
            }
            : []

        return SearchPayload(
            songs: matchingSongs,
            albums: albums,
            artists: artists,
            playlists: playlists,
            podcasts: podcasts
        )
    }

    private func matches(
        _ keyword: String,
        values: [String?]
    ) -> Bool {
        values.compactMap { $0 }.contains {
            $0.localizedCaseInsensitiveContains(keyword)
        }
    }

    private func unique<Element, ID: Hashable>(
        _ values: [Element],
        by keyPath: KeyPath<Element, ID>
    ) -> [Element] {
        var seen = Set<ID>()
        return values.filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}

private enum DesktopSearchSource: Hashable {
    case catalog
    case library
}

struct DesktopSearchView: View {
    @Environment(DesktopAppModel.self) private var model
    @State private var store = DesktopSearchStore()

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 210), spacing: 20)
    ]

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            if !store.query.isEmpty {
                Picker("ui.desktop.search.type", selection: $store.kind) {
                    ForEach(availableSearchKinds) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 520)
                .padding(.horizontal, 34)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()

            ScrollView {
                Group {
                    if let error = store.errorMessage {
                        ContentUnavailableView(
                            "ui.desktop.search.failed",
                            systemImage: "exclamationmark.magnifyingglass",
                            description: Text(error)
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    } else if let payload = store.payload {
                        results(payload)
                    } else if store.isSearching {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                        ContentUnavailableView(
                            "ui.desktop.search.empty.title",
                            systemImage: "magnifyingglass",
                            description: Text("ui.desktop.search.empty.message")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 24)
            }
        }
        .desktopLoadingStatus(
            L10n.string("ui.desktop.search.searching"),
            isPresented: store.isSearching
        )
        .animation(.smooth(duration: 0.22), value: store.query.isEmpty)
        .toolbar {
            if !model.ui.isNowPlayingPresented {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("ui.search.prompt", text: $store.query)
                            .textFieldStyle(.plain)
                            .textInputSuggestions(store.suggestions, id: \.self) { suggestion in
                                Label {
                                    Text(verbatim: suggestion)
                                } icon: {
                                    Image(systemName: "magnifyingglass")
                                }
                                .textInputCompletion(suggestion)
                            }
                            .onSubmit {
                                Task { await store.search(using: model) }
                            }
                    }
                    .padding(.horizontal, 13)
                    .frame(width: 332, height: 36)
                    .background(.regularMaterial, in: .capsule)
                    .accessibilityElement(children: .contain)
                }

                ToolbarItem(placement: .primaryAction) {
                    Picker("ui.desktop.search.scope", selection: $store.source) {
                        Text("ui.common.netease_cloud_music").tag(DesktopSearchSource.catalog)
                        Text("ui.navigation.library").tag(DesktopSearchSource.library)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
        .task(id: "\(model.settings.searchSuggestionsEnabled):\(store.source):\(store.query)") {
            await store.loadSuggestions(using: model)
        }
        .task(id: searchRequestID) {
            await store.search(using: model, debounced: true)
        }
        .onChange(
            of: model.settings.isContentFeatureEnabled(.podcasts)
        ) { _, podcastsEnabled in
            if !podcastsEnabled, store.kind == .podcasts {
                store.kind = .songs
            }
        }
    }

    private var availableSearchKinds: [SearchKind] {
        SearchKind.allCases.filter {
            $0 != .podcasts
                || model.settings.isContentFeatureEnabled(.podcasts)
        }
    }

    private var searchRequestID: String {
        "\(store.source)-\(store.kind.rawValue)-\(store.query)"
    }

    @ViewBuilder
    private func results(_ payload: SearchPayload) -> some View {
        switch store.kind {
        case .songs:
            let songs = payload.songs ?? []
            if songs.isEmpty {
                emptyResults
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        DesktopTrackRow(
                            song: song,
                            index: index,
                            songs: songs,
                            showsArtwork: true
                        )
                    }
                }
            }
        case .albums:
            mediaGrid(payload.albums ?? [])
        case .artists:
            artistGrid(payload.artists ?? [])
        case .playlists:
            playlistGrid(payload.playlists ?? [])
        case .podcasts:
            podcastGrid(payload.podcasts ?? [])
        }
    }

    private var emptyResults: some View {
        ContentUnavailableView.search(text: store.query)
            .frame(maxWidth: .infinity, minHeight: 300)
    }

    @ViewBuilder
    private func mediaGrid(_ albums: [Album]) -> some View {
        if albums.isEmpty {
            emptyResults
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(albums) { album in
                    DesktopMediaCard(
                        title: album.name,
                        subtitle: album.artistText,
                        artworkURL: album.artworkURL,
                        action: { model.ui.navigate(to: .album(album.id)) },
                        playAction: { play(album) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func artistGrid(_ artists: [Artist]) -> some View {
        if artists.isEmpty {
            emptyResults
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(artists) { artist in
                    DesktopMediaCard(
                        title: artist.name,
                        subtitle: artist.aliases.first,
                        artworkURL: artist.artworkURL,
                        isCircular: true,
                        action: { model.ui.navigate(to: .artist(artist.id)) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func playlistGrid(_ playlists: [Playlist]) -> some View {
        if playlists.isEmpty {
            emptyResults
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(playlists) { playlist in
                    DesktopMediaCard(
                        title: playlist.name,
                        subtitle: playlist.creator?.nickname,
                        artworkURL: playlist.artworkURL,
                        playCount: playlist.playCount,
                        showsPlayCount: model.settings.showPlayCount,
                        action: { model.ui.navigate(to: .playlist(playlist.id)) },
                        playAction: { play(playlist) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func podcastGrid(_ podcasts: [Podcast]) -> some View {
        if podcasts.isEmpty {
            emptyResults
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(podcasts) { podcast in
                    DesktopMediaCard(
                        title: podcast.name,
                        subtitle: podcast.subtitle,
                        artworkURL: podcast.artworkURL,
                        action: { model.ui.navigate(to: .podcast(podcast.id)) }
                    )
                }
            }
        }
    }

    private func play(_ album: Album) {
        Task {
            guard let detail = try? await model.api.album(id: album.id) else { return }
            await model.player.playAll(detail.1, sourceID: album.id)
        }
    }

    private func play(_ playlist: Playlist) {
        Task {
            guard let detail = try? await model.api.playlist(
                id: playlist.id,
                trackLimit: nil
            ) else { return }
            await model.player.playAll(detail.tracks, sourceID: playlist.id)
        }
    }
}
