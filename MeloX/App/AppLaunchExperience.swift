import SwiftUI

extension View {
    func appLaunchExperience() -> some View {
        modifier(AppLaunchExperienceModifier())
    }
}

private struct AppLaunchExperienceModifier: ViewModifier {
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings
    @Environment(AppReleaseNotesStore.self) private var releaseNotes

    @State private var didHandleLaunch = false
    @State private var didContinueLaunchExperience = false
    @State private var didRunAutomaticUpdateCheck = false
    @State private var showsRecommendationDialog = false
    @State private var presentedReleaseNotes: AppReleaseNotes?
    @State private var automaticUpdateAlert: AutomaticUpdateAlert?

    func body(content: Content) -> some View {
        content
            .task {
                await handleLaunch()
            }
            .sheet(
                item: $presentedReleaseNotes,
                onDismiss: finishReleaseNotesPresentation
            ) { notes in
                ReleaseNotesSheet(releaseNotes: notes)
            }
            .confirmationDialog(
                "ui.launch.recommend.title",
                isPresented: $showsRecommendationDialog,
                titleVisibility: .visible
            ) {
                ShareLink(
                    item: AppUpdateService.repositoryURL,
                    subject: Text("ui.launch.recommend.share_subject"),
                    message: Text("ui.launch.recommend.share_message")
                ) {
                    Label("ui.launch.recommend.share", systemImage: "square.and.arrow.up")
                }

                Button("ui.launch.recommend.not_now", role: .cancel) {}
            } message: {
                Text("ui.launch.recommend.message")
            }
            .onChange(of: showsRecommendationDialog) { _, isPresented in
                guard !isPresented else { return }

                Task {
                    await checkForUpdatesOnLaunch()
                }
            }
            .alert(item: $automaticUpdateAlert) { alert in
                Alert(
                    title: Text("ui.update.available.title"),
                    message: Text(alert.message),
                    primaryButton: .default(Text("ui.update.open_release_page")) {
                        openURL(alert.releaseURL)
                    },
                    secondaryButton: .cancel(Text("ui.common.later"))
                )
            }
    }

    @MainActor
    private func handleLaunch() async {
        #if DEBUG && targetEnvironment(simulator)
        if MeloXDesignPreview.isEnabled { return }
        #endif
        guard !didHandleLaunch else { return }
        didHandleLaunch = true

        if settings.hasCompletedOnboarding,
           let pendingReleaseNotes = releaseNotes.releaseNotesToPresent {
            presentedReleaseNotes = pendingReleaseNotes
            return
        }

        await continueLaunchExperience()
    }

    @MainActor
    private func finishReleaseNotesPresentation() {
        releaseNotes.markCurrentVersionPresented()

        Task {
            await continueLaunchExperience()
        }
    }

    @MainActor
    private func continueLaunchExperience() async {
        guard !didContinueLaunchExperience else { return }
        didContinueLaunchExperience = true

        if AppRecommendationPrompt.recordLaunch() {
            showsRecommendationDialog = true
        } else {
            await checkForUpdatesOnLaunch()
        }
    }

    @MainActor
    private func checkForUpdatesOnLaunch() async {
        guard settings.checksUpdatesOnLaunch,
              !didRunAutomaticUpdateCheck else {
            return
        }

        didRunAutomaticUpdateCheck = true

        do {
            let result = try await AppUpdateService.checkLatestRelease(
                currentVersion: Bundle.main.appReleaseVersion
            )
            guard result.hasUpdate else { return }

            automaticUpdateAlert = AutomaticUpdateAlert(
                message: L10n.format(
                    "ui.update.available.message",
                    result.currentVersion,
                    result.latestVersion
                ),
                releaseURL: result.releaseURL
            )
        } catch {
            // 自动检查更新不打断启动流程。
        }
    }
}

private struct AutomaticUpdateAlert: Identifiable {
    let id = UUID()
    let message: String
    let releaseURL: URL
}
