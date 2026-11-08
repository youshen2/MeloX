import SwiftUI

struct BackgroundMixSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    "ui.settings.background_mix.always.title",
                    isOn: alwaysMixBinding
                )
            } footer: {
                Text("ui.settings.background_mix.always.footer")
            }

            Section {
                Toggle(
                    "ui.settings.background_mix.resume.title",
                    isOn: resumeInMixBinding
                )
                .disabled(settings.alwaysMixesWithOtherApps)
            } footer: {
                Text(
                    settings.alwaysMixesWithOtherApps
                        ? "ui.settings.background_mix.resume.disabled_footer"
                        : "ui.settings.background_mix.resume.footer"
                )
            }
        }
        .navigationTitle("ui.settings.background_mix.title")
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
}
