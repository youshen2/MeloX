import SwiftUI

struct SearchView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(AppSettings.self) private var settings

    @State private var query = ""
    @State private var suggestions: [String] = []
    @State private var resultCache = SearchResultCache()
    @State private var scope: SearchKind = .songs
    @State private var phase: LoadingPhase = .loaded
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var playlists: [Playlist] = []
    @State private var podcasts: [Podcast] = []
    @State private var completedRequest: SearchRequest?
    @State private var recognizedLink: NeteaseMusicLink?
    @State private var linkedSong: Song?
    @State private var presentedListenTogetherLink:
        NeteaseListenTogetherLink?

    var body: some View {
        Group {
            if trimmedQuery.isEmpty {
                SearchDiscoveryView()
            } else if let recognizedLink {
                linkResult(for: recognizedLink)
            } else {
                searchResults
            }
        }
        .navigationTitle("ui.navigation.search")
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "ui.search.prompt"
        )
        .searchSuggestions {
            if settings.searchSuggestionsEnabled {
                ForEach(suggestions, id: \.self) { suggestion in
                    Label {
                        Text(verbatim: suggestion)
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                    .searchCompletion(suggestion)
                }
            }
        }
        .task(id: "\(settings.searchSuggestionsEnabled):\(query)") {
            await loadSuggestions()
        }
        .searchScopes($scope) {
            ForEach(availableSearchKinds) { kind in
                Text(kind.title).tag(kind)
            }
        }
        .overlay {
            if !trimmedQuery.isEmpty, case .failed(let message) = phase {
                ContentUnavailableView(
                    recognizedLink == nil
                        ? L10n.string("ui.search.failed")
                        : L10n.string("ui.search.link_failed"),
                    systemImage: recognizedLink == nil
                        ? "exclamationmark.magnifyingglass"
                        : "link.badge.plus",
                    description: Text(message)
                )
            } else if recognizedLink == nil,
                      !trimmedQuery.isEmpty,
                      phase == .loaded,
                      resultIsEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .sheet(item: $presentedListenTogetherLink) { invitation in
            ListenTogetherView(
                invitationText: invitation.invitationText
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "ui.error.favorite_failed",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { if !$0 { library.clearError() } }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? L10n.string("ui.common.unknown_error"))
        }
        .task(id: SearchRequest(query: query, kind: scope)) {
            let request = SearchRequest(query: query, kind: scope)
            guard completedRequest != request else { return }
            await search(request)
        }
        .onChange(
            of: settings.isContentFeatureEnabled(.podcasts)
        ) { _, podcastsEnabled in
            if !podcastsEnabled, scope == .podcasts {
                scope = .songs
            }
        }
    }

    private func loadSuggestions() async {
        suggestions = []
        let keywords = trimmedQuery
        guard settings.searchSuggestionsEnabled, !keywords.isEmpty,
              NeteaseMusicLinkParser.parse(keywords) == nil else { return }
        do {
            try await Task.sleep(for: .milliseconds(300))
            let loaded = try await api.searchSuggestions(keywords)
            try Task.checkCancellation()
            suggestions = loaded
        } catch {
            return
        }
    }

    private var availableSearchKinds: [SearchKind] {
        SearchKind.allCases.filter {
            $0 != .podcasts
                || settings.isContentFeatureEnabled(.podcasts)
        }
    }

    private var searchResults: some View {
        List {
            if phase == .loading {
                HStack {
                    Spacer()
                    ProgressView("ui.search.searching")
                    Spacer()
                }
            }

            switch scope {
            case .songs:
                ForEach(songs) { song in
                    Button {
                        Task { await player.play(song, in: songs) }
                    } label: {
                        TrackRowView(song: song, showsArtwork: true)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button {
                            library.toggle(song: song)
                        } label: {
                            Label(
                                library.contains(song: song)
                                    ? L10n.string("ui.common.unfavorite")
                                    : L10n.string("ui.common.favorite"),
                                systemImage: library.contains(song: song) ? "heart.slash" : "heart"
                            )
                        }
                        .tint(.pink)
                    }
                }
            case .albums:
                ForEach(albums) { album in
                    NavigationLink(value: MusicRoute.album(album)) {
                        SearchMediaRow(
                            title: album.name,
                            subtitle: album.artistText,
                            artworkURL: album.artworkURL,
                            circular: false
                        )
                    }
                    .musicMatchedTransitionSource(for: MusicRoute.album(album))
                }
            case .artists:
                ForEach(artists) { artist in
                    NavigationLink(value: MusicRoute.artist(artist.id)) {
                        SearchMediaRow(
                            title: artist.name,
                            subtitle: artist.aliases.first,
                            artworkURL: artist.artworkURL,
                            circular: true
                        )
                    }
                    .musicMatchedTransitionSource(for: MusicRoute.artist(artist.id))
                }
            case .playlists:
                ForEach(playlists) { playlist in
                    NavigationLink(value: MusicRoute.playlist(playlist)) {
                        SearchMediaRow(
                            title: playlist.name,
                            subtitle: L10n.format("ui.common.song_count", playlist.trackCount),
                            artworkURL: playlist.artworkURL,
                            circular: false
                        )
                    }
                    .musicMatchedTransitionSource(for: MusicRoute.playlist(playlist))
                }
            case .podcasts:
                ForEach(podcasts) { podcast in
                    NavigationLink(
                        value: MusicRoute.podcast(podcast)
                    ) {
                        PodcastListRow(podcast: podcast)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func linkResult(for link: NeteaseMusicLink) -> some View {
        switch link {
        case .song:
            List {
                if phase == .loading {
                    HStack {
                        Spacer()
                        ProgressView("ui.search.reading_song_link")
                        Spacer()
                    }
                } else if let linkedSong {
                    Section("ui.search.section.linked_song") {
                        NavigationLink(
                            value: MusicRoute.song(linkedSong)
                        ) {
                            TrackRowView(
                                song: linkedSong,
                                showsArtwork: true
                            )
                        }
                        .musicMatchedTransitionSource(
                            for: MusicRoute.song(linkedSong)
                        )
                    }
                }
            }
            .listStyle(.plain)

        case .listenTogether(let invitation):
            ContentUnavailableView {
                Label("ui.listen_together.invitation", systemImage: "person.2.wave.2")
            } description: {
                Text("ui.search.listen_together_link_recognized")
            } actions: {
                Button("ui.clipboard.view_invitation") {
                    presentedListenTogetherLink = invitation
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resultIsEmpty: Bool {
        switch scope {
        case .songs: songs.isEmpty
        case .albums: albums.isEmpty
        case .artists: artists.isEmpty
        case .playlists: playlists.isEmpty
        case .podcasts: podcasts.isEmpty
        }
    }

    private func search(_ request: SearchRequest) async {
        let keywords = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keywords.isEmpty else {
            clearResults()
            resultCache.clear()
            recognizedLink = nil
            linkedSong = nil
            phase = .loaded
            completedRequest = request
            return
        }

        if let link = NeteaseMusicLinkParser.parse(keywords) {
            await resolve(link, for: request)
            return
        }

        recognizedLink = nil
        linkedSong = nil
        if let cached = resultCache.value(for: keywords, kind: request.kind) {
            apply(cached)
            phase = .loaded
            completedRequest = request
            return
        }
        phase = .loading
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        do {
            let result = try await api.search(keywords, kind: request.kind)
            guard !Task.isCancelled else { return }
            apply(result)

            if request.kind == .songs, !songs.isEmpty {
                let details = try? await api.songDetails(ids: songs.map(\.id))
                guard !Task.isCancelled else { return }
                if let details, !details.isEmpty {
                    songs = details
                }
            }
            resultCache.insert(
                SearchPayload(songs: songs, albums: albums, artists: artists, playlists: playlists, podcasts: podcasts),
                for: keywords,
                kind: request.kind
            )
            phase = .loaded
            completedRequest = request
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func apply(_ result: SearchPayload) {
        songs = result.songs ?? []
        albums = result.albums ?? []
        artists = result.artists ?? []
        playlists = result.playlists ?? []
        podcasts = result.podcasts ?? []
    }

    private func resolve(
        _ link: NeteaseMusicLink,
        for request: SearchRequest
    ) async {
        recognizedLink = link
        linkedSong = nil
        clearResults()

        switch link {
        case .song(let id):
            phase = .loading
            do {
                let details = try await api.songDetails(ids: [id])
                try Task.checkCancellation()
                guard let song = details.first else {
                    phase = .failed(
                        L10n.string("ui.clipboard.error.song_not_found")
                    )
                    return
                }
                linkedSong = song
                phase = .loaded
                completedRequest = request
            } catch is CancellationError {
                return
            } catch {
                phase = .failed(error.localizedDescription)
            }

        case .listenTogether:
            phase = .loaded
            completedRequest = request
        }
    }

    private func clearResults() {
        songs = []
        albums = []
        artists = []
        playlists = []
        podcasts = []
    }
}

private struct SearchRequest: Hashable {
    let query: String
    let kind: SearchKind
}

private struct SearchMediaRow: View {
    let title: String
    let subtitle: String?
    let artworkURL: URL?
    let circular: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: artworkURL, cornerRadius: circular ? 1_000 : 7)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
