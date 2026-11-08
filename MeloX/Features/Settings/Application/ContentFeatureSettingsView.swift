import SwiftUI

struct ContentFeatureSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerStore.self) private var player

    var body: some View {
        Form {
            Section {
                ForEach(ContentFeature.availableCases) { feature in
                    Toggle(isOn: binding(for: feature)) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(feature.title)
                                Text(feature.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: feature.systemImage)
                        }
                    }
                }
            } header: {
                Text("ui.settings.content_features.section")
            } footer: {
                Text("ui.settings.content_features.footer")
            }

            Section {
                Toggle(isOn: alwaysMixBinding) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ui.settings.background_mix.always.title")
                            Text("ui.settings.background_mix.always.subtitle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "speaker.wave.2")
                    }
                }
            } header: {
                Text("ui.settings.background_mix.title")
            }
        }
        .navigationTitle("ui.settings.catalog.features.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var alwaysMixBinding: Binding<Bool> {
        Binding(
            get: { settings.alwaysMixesWithOtherApps },
            set: { isEnabled in
                settings.alwaysMixesWithOtherApps = isEnabled
                player.applyBackgroundAudioMixPolicy()
            }
        )
    }

    private func binding(
        for feature: ContentFeature
    ) -> Binding<Bool> {
        Binding(
            get: { settings.isContentFeatureEnabled(feature) },
            set: { isEnabled in
                settings.setContentFeature(
                    feature,
                    isEnabled: isEnabled
                )
                guard isEnabled,
                      feature == .podcasts
                        || feature == .listeningHistory else {
                    return
                }
                Task { await library.refresh(force: true) }
            }
        )
    }
}
