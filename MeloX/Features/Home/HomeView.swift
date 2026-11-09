import SwiftUI

struct HomeView: View {
    @Environment(AppSettings.self) private var settings

    @State private var section = AppTab.recommended

    private var availableSections: [AppTab] {
        settings.homeTabs
    }

    private var activeSection: AppTab {
        availableSections.contains(section)
            ? section
            : availableSections.first ?? .recommended
    }

    var body: some View {
        VStack(spacing: 0) {
            if availableSections.count > 1 {
                sectionPicker
            }

            sectionContent(for: activeSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("ui.navigation.home")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: availableSections) { _, sections in
            guard !sections.contains(section) else { return }
            section = sections.first ?? .recommended
        }
    }

    private var sectionPicker: some View {
        let usesMenu = availableSections.count > 4

        return FilterPicker(
            title: "ui.home.section_picker",
            selection: $section,
            maximumWidth: CGFloat(availableSections.count) * 112,
            usesMenu: usesMenu
        ) {
            ForEach(availableSections) { section in
                Group {
                    if usesMenu {
                        Label(section.settingsTitle, systemImage: section.systemImage)
                    } else {
                        Text(section.settingsTitle)
                    }
                }
                .tag(section)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.background)
    }

    @ViewBuilder
    private func sectionContent(
        for section: AppTab
    ) -> some View {
        switch section {
        case .recommended:
            HomeRecommendedView()
        case .music:
            ExploreView(showsNavigationTitle: false)
        case .podcasts:
            PodcastHomeView(showsNavigationTitle: false)
        case .explore:
            ExploreView(showsNavigationTitle: false)
        case .library:
            LibraryView(showsNavigationTitle: false)
        case .librarySongs,
             .libraryPlaylists,
             .libraryAlbums,
             .libraryArtists,
             .libraryPodcasts,
             .libraryDownloads,
             .libraryCloud,
             .libraryHistory:
            if let page = section.libraryPage {
                LibraryView(
                    fixedPage: page,
                    showsNavigationTitle: false
                )
            }
        case .home,
             .search:
            EmptyView()
        }
    }
}
