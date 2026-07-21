import SwiftUI

extension View {
    func appLaunchExperience() -> some View {
        modifier(AppLaunchExperienceModifier())
    }
}

private struct AppLaunchExperienceModifier: ViewModifier {
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings

    @State private var didHandleLaunch = false
    @State private var didRunAutomaticUpdateCheck = false
    @State private var showsRecommendationDialog = false
    @State private var automaticUpdateAlert: AutomaticUpdateAlert?

    func body(content: Content) -> some View {
        content
            .task {
                await handleLaunch()
            }
            .confirmationDialog(
                "喜欢 MeloX 吗？",
                isPresented: $showsRecommendationDialog,
                titleVisibility: .visible
            ) {
                ShareLink(
                    item: AppUpdateService.repositoryURL,
                    subject: Text("推荐 MeloX"),
                    message: Text("我正在使用 MeloX，推荐你也试试！")
                ) {
                    Label("分享 MeloX", systemImage: "square.and.arrow.up")
                }

                Button("还是算了", role: .cancel) {}
            } message: {
                Text("如果 MeloX 对你有帮助，欢迎把它推荐给更多人。你的分享会帮助项目被更多用户发现。")
            }
            .onChange(of: showsRecommendationDialog) { _, isPresented in
                guard !isPresented else { return }

                Task {
                    await checkForUpdatesOnLaunch()
                }
            }
            .alert(item: $automaticUpdateAlert) { alert in
                Alert(
                    title: Text("发现新版本"),
                    message: Text(alert.message),
                    primaryButton: .default(Text("打开发布页")) {
                        openURL(alert.releaseURL)
                    },
                    secondaryButton: .cancel(Text("稍后"))
                )
            }
    }

    @MainActor
    private func handleLaunch() async {
        guard !didHandleLaunch else { return }
        didHandleLaunch = true

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
                currentVersion: Bundle.main.appVersion
            )
            guard result.hasUpdate else { return }

            automaticUpdateAlert = AutomaticUpdateAlert(
                message: "当前版本 \(result.currentVersion)，最新版本 \(result.latestVersion)。可以前往发布页查看更新内容。",
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

extension Bundle {
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var appBuildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
