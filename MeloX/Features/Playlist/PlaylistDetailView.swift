import SwiftUI

struct PlaylistDetailView: View {
    let id: Int
    private let initialPlaylist: Playlist
    private let prefersToplistLayout: Bool

    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var playlist: Playlist?
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var artworkPalette: ArtworkDetailPalette?
    @State private var searchQuery = ""

    init(playlist context: PlaylistRouteContext) {
        id = context.id
        initialPlaylist = context.playlistSummary
        prefersToplistLayout = false
    }

    init(toplist context: PlaylistRouteContext) {
        id = context.id
        initialPlaylist = context.playlistSummary
        prefersToplistLayout = true
    }

    var body: some View {
        PlaylistDetailContent(
            playlist: displayedPlaylist,
            toplistSummary: prefersToplistLayout ? initialPlaylist : nil,
            palette: resolvedPalette,
            searchQuery: searchQuery,
            isLoading: isInitialLoading,
            failureMessage: initialFailureMessage,
            onRetry: { reloadToken += 1 },
            onRefresh: load
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(prefersToplistLayout ? "在排行榜中搜索" : "在歌单中搜索")
        )
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(interfaceColorScheme, for: .navigationBar, .tabBar)
        .toolbar {
            playlistToolbar(for: displayedPlaylist)
        }
        .environment(\.colorScheme, interfaceColorScheme)
        .task(id: reloadToken) {
            guard playlist == nil else { return }
            await load()
        }
        .task(id: artworkURL) {
            let loadedPalette = await ArtworkAccentColorProvider.shared.detailPalette(
                for: artworkURL,
                fallbackPrefersDarkAppearance: systemColorScheme == .dark
            )
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                artworkPalette = loadedPalette
            }
        }
        .alert(
            "音乐库操作失败",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        library.clearError()
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? "未知错误")
        }
    }

    private var displayedPlaylist: Playlist {
        playlist ?? initialPlaylist
    }

    private var artworkURL: URL? {
        displayedPlaylist.artworkURL ?? initialPlaylist.artworkURL
    }

    private var resolvedPalette: ArtworkDetailPalette {
        artworkPalette
            ?? .fallback(prefersDarkAppearance: systemColorScheme == .dark)
    }

    private var interfaceColorScheme: ColorScheme {
        resolvedPalette.colorScheme
    }

    private var isInitialLoading: Bool {
        guard playlist == nil else { return false }
        if case .loading = phase {
            return true
        }
        return false
    }

    private var initialFailureMessage: String? {
        guard playlist == nil, case .failed(let message) = phase else { return nil }
        return message
    }

    @ToolbarContentBuilder
    private func playlistToolbar(for playlist: Playlist) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            ShareLink(item: "https://music.163.com/playlist?id=\(playlist.id)") {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享歌单")

            Menu {
                Button {
                    library.toggle(playlist: playlist)
                } label: {
                    Label(
                        library.contains(playlist: playlist) ? "取消收藏" : "收藏歌单",
                        systemImage: library.contains(playlist: playlist) ? "checkmark" : "plus"
                    )
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

    private func load() async {
        phase = .loading
        do {
            playlist = try await api.playlist(id: id)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
