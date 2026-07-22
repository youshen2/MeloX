import SwiftUI

struct AlbumDetailView: View {
    let id: Int
    private let initialAlbum: Album

    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var album: Album?
    @State private var songs: [Song] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var isSubscribed = false
    @State private var isUpdatingSubscription = false
    @State private var operationError: String?
    @State private var artworkPalette: ArtworkDetailPalette?
    @State private var searchQuery = ""

    init(context: AlbumRouteContext) {
        id = context.id
        initialAlbum = context.albumSummary
    }

    var body: some View {
        AlbumDetailContent(
            album: displayedAlbum,
            songs: songs,
            palette: resolvedPalette,
            searchQuery: searchQuery,
            isLoading: isInitialLoading,
            failureMessage: initialFailureMessage,
            isSubscribed: isSubscribed,
            onToggleSubscription: toggleSubscription,
            onRetry: { reloadToken += 1 },
            onRefresh: load
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("在专辑中搜索")
        )
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(interfaceColorScheme, for: .navigationBar, .tabBar)
        .toolbar {
            albumToolbar
        }
        .environment(\.colorScheme, interfaceColorScheme)
        .task(id: reloadToken) {
            guard album == nil else { return }
            await load()
        }
        .task(id: displayedAlbum.artworkURL) {
            let loadedPalette = await ArtworkAccentColorProvider.shared.detailPalette(
                for: displayedAlbum.artworkURL,
                fallbackPrefersDarkAppearance: systemColorScheme == .dark
            )
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                artworkPalette = loadedPalette
            }
        }
        .alert(
            "专辑操作失败",
            isPresented: Binding(
                get: { operationError != nil },
                set: { isPresented in
                    if !isPresented {
                        operationError = nil
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                operationError = nil
            }
        } message: {
            Text(operationError ?? "未知错误")
        }
    }

    private var displayedAlbum: Album {
        album ?? initialAlbum
    }

    private var resolvedPalette: ArtworkDetailPalette {
        artworkPalette
            ?? .fallback(prefersDarkAppearance: systemColorScheme == .dark)
    }

    private var interfaceColorScheme: ColorScheme {
        resolvedPalette.colorScheme
    }

    private var isInitialLoading: Bool {
        guard album == nil else { return false }
        if case .loading = phase {
            return true
        }
        return false
    }

    private var initialFailureMessage: String? {
        guard album == nil, case .failed(let message) = phase else { return nil }
        return message
    }

    @ToolbarContentBuilder
    private var albumToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            ShareLink(item: "https://music.163.com/album?id=\(id)") {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享专辑")

            Menu {
                if let artist = displayedAlbum.artists.first {
                    NavigationLink(value: MusicRoute.artist(artist.id)) {
                        Label("查看歌手", systemImage: "person")
                    }
                }

                Button {
                    Task { await load() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("更多")
        }
        .sharedBackgroundVisibility(.visible)
    }

    private func toggleSubscription() {
        guard !isUpdatingSubscription else { return }
        guard library.isLoggedIn else {
            operationError = APIError.notLoggedIn.localizedDescription
            return
        }

        let targetState = !isSubscribed
        isSubscribed = targetState
        isUpdatingSubscription = true
        Task {
            defer { isUpdatingSubscription = false }
            do {
                try await api.setAlbumSubscribed(
                    id: id,
                    isSubscribed: targetState
                )
            } catch {
                isSubscribed.toggle()
                operationError = error.localizedDescription
            }
        }
    }

    private func load() async {
        phase = .loading
        do {
            (album, songs) = try await api.album(id: id)
            phase = .loaded

            if library.isLoggedIn,
               let loadedSubscription = try? await api.albumSubscriptionStatus(id: id) {
                isSubscribed = loadedSubscription
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
