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
                            Text("ui.settings.background_mix.always.footer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "waveform.badge.mic")
                    }
                }

                Toggle(isOn: resumeInMixBinding) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ui.settings.background_mix.resume.title")
                            Text(
                                settings.alwaysMixesWithOtherApps
                                    ? "ui.settings.background_mix.resume.disabled_footer"
                                    : "ui.settings.background_mix.resume.footer"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(settings.alwaysMixesWithOtherApps)
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

    private var resumeInMixBinding: Binding<Bool> {
        Binding(
            get: { settings.resumesPlaybackInMixWhenInterrupted },
            set: { isEnabled in
                settings.resumesPlaybackInMixWhenInterrupted = isEnabled
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
