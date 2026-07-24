import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings

    @State private var isCheckingUpdate = false
    @State private var updateAlert: AppUpdateAlert?

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                VStack(spacing: 10) {
                    Image("MeloXLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)

                    Text("MeloX")
                        .font(.title2.bold())

                    Text("第三方网易云音乐播放器")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("应用信息") {
                LabeledContent("版本", value: appVersion)
                LabeledContent("构建版本", value: buildNumber)
            }

            Section {
                Toggle("启动时自动检查更新", isOn: $settings.checksUpdatesOnLaunch)

                Button {
                    Task {
                        await checkForUpdates()
                    }
                } label: {
                    HStack {
                        Label(
                            isCheckingUpdate ? "正在检查更新" : "检查更新",
                            systemImage: "arrow.triangle.2.circlepath"
                        )

                        Spacer()

                        if isCheckingUpdate {
                            ProgressView()
                        }
                    }
                }
                .disabled(isCheckingUpdate)
            } header: {
                Text("更新")
            } footer: {
                Text("自动检查只会在发现新版本时提示，检查失败不会打断应用启动。")
            }

            Section("关于 MeloX") {
                Text("MeloX 使用原生 SwiftUI 构建，专注于提供简洁、流畅的网易云音乐播放与歌词体验。")
            }

            Section("项目与社区") {
                Link(destination: AppUpdateService.repositoryURL) {
                    Label("GitHub 仓库", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Link(destination: telegramURL) {
                    HStack(spacing: 12) {
                        Label("Telegram 群组", systemImage: "paperplane")

                        Spacer(minLength: 8)

                        Text("@melox_official")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                NavigationLink {
                    ProjectLicensesView()
                } label: {
                    Label("项目与许可", systemImage: "doc.text")
                }
            } header: {
                Text("开源与许可")
            } footer: {
                Text("查看 MeloX、参考项目、内置资源和 PV Tool 的许可与归属说明。")
            }

            Section("声明") {
                Text("MeloX 是非官方第三方客户端，与网易云音乐及其关联公司不存在隶属或授权关系。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于")
        .alert(item: $updateAlert) { alert in
            if let releaseURL = alert.releaseURL {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("打开发布页")) {
                        openURL(releaseURL)
                    },
                    secondaryButton: .cancel(Text("好"))
                )
            } else {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("好"))
                )
            }
        }
    }

    private var appVersion: String {
        Bundle.main.appVersion
    }

    private var buildNumber: String {
        Bundle.main.appBuildNumber
    }

    private let telegramURL = URL(string: "https://t.me/melox_official")!

    @MainActor
    private func checkForUpdates() async {
        guard !isCheckingUpdate else { return }

        isCheckingUpdate = true
        defer {
            isCheckingUpdate = false
        }

        do {
            let result = try await AppUpdateService.checkLatestRelease(currentVersion: appVersion)

            if result.hasUpdate {
                updateAlert = AppUpdateAlert(
                    title: "发现新版本",
                    message: "当前版本 \(result.currentVersion)，最新版本 \(result.latestVersion)。可以前往发布页查看更新内容。",
                    releaseURL: result.releaseURL
                )
            } else {
                updateAlert = AppUpdateAlert(
                    title: "已是最新版本",
                    message: "当前版本 \(result.currentVersion) 已是最新版本。",
                    releaseURL: nil
                )
            }
        } catch {
            updateAlert = AppUpdateAlert(
                title: "检查更新失败",
                message: error.localizedDescription,
                releaseURL: nil
            )
        }
    }

}

private struct AppUpdateAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let releaseURL: URL?
}
