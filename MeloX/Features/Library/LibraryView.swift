import SwiftUI

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(AppSettings.self) private var settings

    private let fixedPage: LibraryPage?
    private let showsNavigationTitle: Bool

    @State private var section: LibraryPage
    @State private var hasAppliedInitialPage = false
    @State private var showsLogin = false
    @State private var searchQuery = ""

    init(
        fixedPage: LibraryPage? = nil,
        showsNavigationTitle: Bool = true
    ) {
        let resolvedFixedPage = fixedPage.flatMap { page in
            LibraryPage.availableCases.contains(page) ? page : nil
        }
        self.fixedPage = resolvedFixedPage
        self.showsNavigationTitle = showsNavigationTitle
        _section = State(initialValue: resolvedFixedPage ?? .songs)
    }

    private var availablePages: [LibraryPage] {
        fixedPage.map { [$0] } ?? settings.embeddedLibraryPages
    }

    var body: some View {
        VStack(spacing: 0) {
            if fixedPage == nil, availablePages.count > 1 {
                Picker("ui.library.category_picker", selection: $section) {
                    ForEach(availablePages) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.background)
            }

            if availablePages.isEmpty {
                ContentUnavailableView(
                    "ui.library.pages_separated.title",
                    systemImage: "rectangle.3.group",
                    description: Text("ui.library.pages_separated.message")
                )
            } else if section == .downloads {
                LibraryDownloadsView(searchQuery: searchQuery)
            } else if !library.isLoggedIn {
                loginUnavailableView
            } else if section == .cloud {
                CloudMusicView(searchQuery: searchQuery)
            } else {
                libraryContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .libraryNavigationTitle(
            fixedPage.map { AppTab(libraryPage: $0).title }
                ?? L10n.string("ui.navigation.library"),
            isPresented: showsNavigationTitle
        )
        .librarySearchable(
            text: $searchQuery,
            prompt: searchPrompt,
            isEnabled: canSearchCurrentPage
        )
        .onAppear {
            guard !hasAppliedInitialPage else { return }
            hasAppliedInitialPage = true
            if let fixedPage {
                section = fixedPage
            } else {
                section = availablePages.contains(settings.initialLibraryPage)
                    ? settings.initialLibraryPage
                    : availablePages.first ?? .songs
            }
        }
        .onChange(of: section) { _, page in
            if fixedPage == nil {
                settings.lastLibraryPage = page
            }
        }
        .onChange(of: availablePages) { _, pages in
            guard fixedPage == nil,
                  let firstPage = pages.first,
                  !pages.contains(section) else {
                return
            }
            section = firstPage
        }
        .sheet(isPresented: $showsLogin) {
            NavigationStack {
                NeteaseLoginView()
            }
        }
        .task(id: settings.cookie) {
            await library.refresh()
        }
        .alert(
            "ui.library.error.title",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { presented in
                    if !presented {
                        library.clearError()
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? L10n.string("ui.common.unknown_error"))
        }
    }

    private var loginUnavailableView: some View {
        ContentUnavailableView {
            Label("ui.account.login_required", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text(
                AppFeatureAvailability.downloads
                    ? L10n.string("ui.library.login_message.downloads")
                    : L10n.string("ui.library.login_message")
            )
        } actions: {
            Button("ui.account.login_netease") {
                showsLogin = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        switch library.phase {
        case .loading where library.profile == nil:
            ProgressView("ui.library.loading")
        case .failed(let message) where library.profile == nil:
            ConnectionUnavailableView(message: message) {
                Task { await library.refresh(force: true) }
            }
        default:
            switch section {
            case .songs:
                LibrarySongsView(searchQuery: searchQuery)
            case .playlists:
                LibraryPlaylistsView(searchQuery: searchQuery)
            case .albums:
                LibraryAlbumsView(searchQuery: searchQuery)
            case .podcasts:
                SubscribedPodcastsView(searchQuery: searchQuery)
            case .downloads:
                LibraryDownloadsView(searchQuery: searchQuery)
            case .cloud:
                CloudMusicView(searchQuery: searchQuery)
            case .history:
                LibraryHistoryView(searchQuery: searchQuery)
            }
        }
    }

    private var canSearchCurrentPage: Bool {
        !availablePages.isEmpty
            && (section == .downloads || library.isLoggedIn)
    }

    private var searchPrompt: String {
        switch section {
        case .songs:
            L10n.string("ui.library.search.favorite_songs")
        case .playlists:
            L10n.string("ui.library.search.favorite_playlists")
        case .albums:
            L10n.string("ui.library.search.favorite_albums")
        case .podcasts:
            L10n.string("ui.library.search.subscribed_podcasts")
        case .downloads:
            AppFeatureAvailability.downloads
                ? L10n.string("ui.library.search.downloads")
                : L10n.string("ui.library.search.songs")
        case .cloud:
            L10n.string("ui.library.search.cloud")
        case .history:
            L10n.string("ui.library.search.history")
        }
    }
}

private extension View {
    @ViewBuilder
    func libraryNavigationTitle(
        _ title: String,
        isPresented: Bool
    ) -> some View {
        if isPresented {
            navigationTitle(title)
        } else {
            self
        }
    }

    @ViewBuilder
    func librarySearchable(
        text: Binding<String>,
        prompt: String,
        isEnabled: Bool
    ) -> some View {
        if isEnabled {
            searchable(
                text: text,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(prompt)
            )
        } else {
            self
        }
    }
}
