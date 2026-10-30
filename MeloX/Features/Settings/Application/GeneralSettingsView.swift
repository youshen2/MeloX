import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker(
                    "ui.settings.language.picker",
                    selection: Binding(
                        get: { settings.appLanguage },
                        set: settings.setAppLanguage
                    )
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title)
                            .tag(language)
                    }
                }
            } header: {
                Text("ui.settings.language.section")
            } footer: {
                Text("ui.settings.language.footer")
            }

            Section {
                Picker(
                    "ui.settings.general.theme.picker",
                    selection: $settings.appearance
                ) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(
                            appearance.title,
                            systemImage: appearance.systemImage
                        )
                        .tag(appearance)
                    }
                }
            } header: {
                Text("ui.settings.general.appearance.section")
            } footer: {
                Text("ui.settings.general.appearance.footer")
            }

            Section {
                Toggle(
                    "ui.settings.general.restore_last_page",
                    isOn: $settings.restoresLastSelectedTab
                )

                Picker("ui.settings.general.default_launch_page", selection: $settings.defaultLaunchTab) {
                    ForEach(settings.visibleTabs) { tab in
                        Label(
                            tab.settingsTitle,
                            systemImage: tab.systemImage
                        )
                            .tag(tab)
                    }
                }
                .disabled(settings.restoresLastSelectedTab)
            } header: {
                Text("ui.settings.general.launch_navigation.section")
            } footer: {
                if settings.restoresLastSelectedTab {
                    Text("ui.settings.general.launch_navigation.restore.footer")
                } else {
                    Text("ui.settings.general.launch_navigation.default.footer")
                }
            }

            Section {
                Toggle(
                    "ui.settings.general.clipboard_recognition",
                    isOn: $settings.recognizesClipboardLinksOnLaunch
                )
            } header: {
                Text("ui.settings.general.clipboard.section")
            } footer: {
                Text(
                    "ui.settings.general.clipboard.footer"
                )
            }

            Section("ui.navigation.search") {
                Toggle("ui.settings.general.search_suggestions", isOn: $settings.searchSuggestionsEnabled)
            }

            if !settings.embeddedLibraryPages.isEmpty {
                Section {
                    Toggle(
                        "ui.settings.general.library.restore_last_page",
                        isOn: $settings.restoresLastLibraryPage
                    )

                    Picker(
                        "ui.settings.general.library.default_page",
                        selection: $settings.defaultLibraryPage
                    ) {
                        ForEach(settings.embeddedLibraryPages) { page in
                            Label(page.title, systemImage: page.systemImage)
                                .tag(page)
                        }
                    }
                    .disabled(settings.restoresLastLibraryPage)
                } header: {
                    Text("ui.navigation.library")
                } footer: {
                    if settings.restoresLastLibraryPage {
                        Text("ui.settings.general.library.restore.footer")
                    } else {
                        Text("ui.settings.general.library.default.footer")
                    }
                }
            }
        }
        .navigationTitle("ui.settings.catalog.general.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
