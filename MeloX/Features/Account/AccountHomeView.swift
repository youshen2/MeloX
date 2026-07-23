import SwiftUI

struct AccountHomeView: View {
    let initialProfile: AccountProfile

    @Environment(NeteaseAPI.self) private var api
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var detail: AccountDetail?
    @State private var playlists: [Playlist]
    @State private var phase: LoadingPhase
    @State private var errorMessage: String?
    @State private var artworkPalette: ArtworkDetailPalette?
    @State private var blurredBackdropImage: CGImage?

    init(
        initialProfile: AccountProfile,
        initialDetail: AccountDetail?,
        initialPlaylists: [Playlist]
    ) {
        let cachedAssets = ArtworkAccentColorProvider.cachedDetailAssets(
            for: initialProfile.artworkURL
        )
        self.initialProfile = initialProfile
        _detail = State(initialValue: initialDetail)
        _playlists = State(initialValue: initialPlaylists)
        _phase = State(initialValue: .loaded)
        _artworkPalette = State(initialValue: cachedAssets?.palette)
        _blurredBackdropImage = State(
            initialValue: cachedAssets?.blurredBackdropImage
        )
    }

    var body: some View {
        AccountHomeContent(
            profile: displayedProfile,
            detail: detail,
            playlists: playlists,
            palette: resolvedPalette,
            blurredBackdropImage: blurredBackdropImage,
            isLoading: phase == .loading,
            failureMessage: errorMessage,
            onRetry: {
                Task { await load() }
            },
            onRefresh: load
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(interfaceColorScheme, for: .navigationBar, .tabBar)
        .toolbar {
            accountToolbar
        }
        .environment(\.colorScheme, interfaceColorScheme)
        .task {
            await load()
        }
        .task(id: displayedProfile.artworkURL) {
            await loadArtworkAssets()
        }
    }

    private var displayedProfile: AccountProfile {
        detail?.profile ?? initialProfile
    }

    private var resolvedPalette: ArtworkDetailPalette {
        artworkPalette
            ?? .fallback(prefersDarkAppearance: systemColorScheme == .dark)
    }

    private var interfaceColorScheme: ColorScheme {
        resolvedPalette.colorScheme
    }

    private var homepageURL: URL {
        URL(string: "https://music.163.com/#/user/home?id=\(displayedProfile.id)")!
    }

    @ToolbarContentBuilder
    private var accountToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            ShareLink(item: homepageURL) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享个人主页")

            Menu {
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

    private func loadArtworkAssets() async {
        let loadedAssets = await ArtworkAccentColorProvider.shared.detailAssets(
            for: displayedProfile.artworkURL,
            fallbackPrefersDarkAppearance: systemColorScheme == .dark
        )
        guard !Task.isCancelled else { return }

        let backdropAlreadyResolved = blurredBackdropImage != nil
            || loadedAssets.blurredBackdropImage == nil
        guard artworkPalette != loadedAssets.palette
                || !backdropAlreadyResolved else {
            return
        }

        withAnimation(artworkTransitionAnimation) {
            artworkPalette = loadedAssets.palette
            blurredBackdropImage = loadedAssets.blurredBackdropImage
        }
    }

    private var artworkTransitionAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private func load() async {
        guard phase != .loading else { return }

        phase = .loading
        errorMessage = nil
        do {
            async let loadedDetail = api.userDetail(userID: initialProfile.id)
            async let loadedPlaylists = api.userPlaylists(userID: initialProfile.id)
            let (newDetail, newPlaylists) = try await (
                loadedDetail,
                loadedPlaylists
            )
            detail = newDetail
            playlists = newPlaylists
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .loaded
            errorMessage = error.localizedDescription
        }
    }
}
