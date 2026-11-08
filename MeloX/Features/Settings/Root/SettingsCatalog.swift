import Foundation

enum SettingsRoute: Hashable {
    case accountHome
    case playback
    case playerAppearance
    case lyrics
    case systemPlayback
    case general
    case tabLayout
    case contentFeatures
    case backgroundMix
    case content
    case storage
    case skylineLyrics
    case floatingLyrics
    case developer
    case about
}

struct SettingsCatalogSection: Identifiable {
    let title: String
    let items: [SettingsCatalogItem]

    var id: String { title }
}

struct SettingsCatalogItem {
    let route: SettingsRoute
    let title: String
    let subtitle: String
    let systemImage: String
    let keywords: [String]

    func matches(_ query: String) -> Bool {
        SettingsCatalog.matches(
            query,
            values: [title, subtitle] + keywords
        )
    }
}

enum SettingsCatalog {
    static var sections: [SettingsCatalogSection] { [
        SettingsCatalogSection(
            title: L10n.string("ui.settings.catalog.player.section"),
            items: [
                SettingsCatalogItem(
                    route: .playback,
                    title: L10n.string("ui.settings.catalog.playback.title"),
                    subtitle: L10n.string("ui.settings.catalog.playback.subtitle"),
                    systemImage: "waveform",
                    keywords: L10n.keywords("ui.settings.catalog.playback.keywords")
                ),
                SettingsCatalogItem(
                    route: .playerAppearance,
                    title: L10n.string("ui.settings.catalog.player_appearance.title"),
                    subtitle: L10n.string("ui.settings.catalog.player_appearance.subtitle"),
                    systemImage: "paintbrush",
                    keywords: L10n.keywords("ui.settings.catalog.player_appearance.keywords")
                ),
                SettingsCatalogItem(
                    route: .lyrics,
                    title: L10n.string("ui.settings.catalog.lyrics.title"),
                    subtitle: L10n.string("ui.settings.catalog.lyrics.subtitle"),
                    systemImage: "quote.bubble",
                    keywords: L10n.keywords("ui.settings.catalog.lyrics.keywords")
                ),
            ]
        ),
        SettingsCatalogSection(
            title: L10n.string("ui.settings.catalog.system_lyrics.section"),
            items: [
                SettingsCatalogItem(
                    route: .systemPlayback,
                    title: L10n.string("ui.settings.catalog.system_lyrics.title"),
                    subtitle: L10n.string("ui.settings.catalog.system_lyrics.subtitle"),
                    systemImage: "lock.display",
                    keywords: L10n.keywords("ui.settings.catalog.system_lyrics.keywords")
                ),
                SettingsCatalogItem(
                    route: .skylineLyrics,
                    title: L10n.string("ui.settings.catalog.skyline.title"),
                    subtitle: L10n.string("ui.settings.catalog.skyline.subtitle"),
                    systemImage: "rectangle.landscape.rotate",
                    keywords: L10n.keywords("ui.settings.catalog.skyline.keywords")
                ),
                SettingsCatalogItem(
                    route: .floatingLyrics,
                    title: L10n.string("ui.settings.catalog.floating.title"),
                    subtitle: L10n.string("ui.settings.catalog.floating.subtitle"),
                    systemImage: "pip",
                    keywords: L10n.keywords("ui.settings.catalog.floating.keywords")
                ),
            ]
        ),
        SettingsCatalogSection(
            title: L10n.string("ui.settings.catalog.content_storage.section"),
            items: [
                SettingsCatalogItem(
                    route: .contentFeatures,
                    title: L10n.string("ui.settings.catalog.features.title"),
                    subtitle: L10n.string("ui.settings.catalog.features.subtitle"),
                    systemImage: "switch.2",
                    keywords: L10n.keywords("ui.settings.catalog.features.keywords")
                ),
                SettingsCatalogItem(
                    route: .backgroundMix,
                    title: L10n.string("ui.settings.background_mix.title"),
                    subtitle: L10n.string("ui.settings.background_mix.subtitle"),
                    systemImage: "waveform.badge.mic",
                    keywords: L10n.keywords("ui.settings.background_mix.keywords")
                ),
                SettingsCatalogItem(
                    route: .content,
                    title: L10n.string("ui.settings.catalog.content.title"),
                    subtitle: L10n.string("ui.settings.catalog.content.subtitle"),
                    systemImage: "rectangle.stack",
                    keywords: L10n.keywords("ui.settings.catalog.content.keywords")
                ),
                SettingsCatalogItem(
                    route: .storage,
                    title: L10n.string("ui.settings.catalog.storage.title"),
                    subtitle:
                        AppFeatureAvailability.downloads
                            ? L10n.string("ui.settings.catalog.storage.subtitle.downloads")
                            : L10n.string("ui.settings.catalog.storage.subtitle"),
                    systemImage: "internaldrive",
                    keywords:
                        AppFeatureAvailability.downloads
                            ? L10n.keywords("ui.settings.catalog.storage.keywords.downloads")
                            : L10n.keywords("ui.settings.catalog.storage.keywords")
                ),
            ]
        ),
        SettingsCatalogSection(
            title: L10n.string("ui.settings.catalog.interface.section"),
            items: [
                SettingsCatalogItem(
                    route: .tabLayout,
                    title: L10n.string("ui.settings.catalog.tab_layout.title"),
                    subtitle: L10n.string("ui.settings.catalog.tab_layout.subtitle"),
                    systemImage: "rectangle.3.group",
                    keywords: L10n.keywords("ui.settings.catalog.tab_layout.keywords")
                        + (AppFeatureAvailability.downloads
                            ? L10n.keywords("ui.settings.catalog.download.keyword")
                            : [])
                ),
                SettingsCatalogItem(
                    route: .general,
                    title: L10n.string("ui.settings.catalog.general.title"),
                    subtitle: L10n.string("ui.settings.catalog.general.subtitle"),
                    systemImage: "gearshape",
                    keywords: L10n.keywords("ui.settings.catalog.general.keywords")
                ),
            ]
        ),
        SettingsCatalogSection(
            title: L10n.string("ui.settings.catalog.about.section"),
            items: [
                SettingsCatalogItem(
                    route: .about,
                    title: L10n.string("ui.settings.catalog.about.title"),
                    subtitle: L10n.string("ui.settings.catalog.about.subtitle"),
                    systemImage: "info.circle",
                    keywords: L10n.keywords("ui.settings.catalog.about.keywords")
                ),
                SettingsCatalogItem(
                    route: .developer,
                    title: L10n.string("ui.settings.catalog.developer.title"),
                    subtitle: L10n.string("ui.settings.catalog.developer.subtitle"),
                    systemImage: "hammer",
                    keywords: L10n.keywords("ui.settings.catalog.developer.keywords")
                ),
            ]
        ),
    ] }

    static func filteredSections(
        matching query: String
    ) -> [SettingsCatalogSection] {
        let normalizedQuery = normalized(query)
        guard !normalizedQuery.isEmpty else { return sections }

        return sections.compactMap { section in
            let items = section.items.filter {
                $0.matches(normalizedQuery)
            }
            guard !items.isEmpty else { return nil }
            return SettingsCatalogSection(
                title: section.title,
                items: items
            )
        }
    }

    static func matchesAccount(_ query: String) -> Bool {
        matches(
            query,
            values: L10n.keywords("ui.settings.catalog.account.keywords")
        )
    }

    static func matchesReset(_ query: String) -> Bool {
        matches(
            query,
            values: L10n.keywords("ui.settings.catalog.reset.keywords")
        )
    }

    static func matches(
        _ query: String,
        values: [String]
    ) -> Bool {
        let normalizedQuery = normalized(query)
        guard !normalizedQuery.isEmpty else { return true }

        let searchableText = values
            .joined(separator: " ")
            .lowercased()

        return normalizedQuery
            .split(whereSeparator: \.isWhitespace)
            .allSatisfy { searchableText.contains($0) }
    }

    private static func normalized(_ query: String) -> String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
