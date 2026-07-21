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
                    Image(systemName: "music.note")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.tint)
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

                        Text("@malo_x_official")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach(acknowledgements) { project in
                    Link(destination: project.url) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(project.name)
                                    .foregroundStyle(.primary)

                                Text(project.contribution)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(.rect)
                    }
                    .accessibilityHint("在浏览器中打开 GitHub 项目")
                }
            } header: {
                Text("特别鸣谢")
            } footer: {
                Text("感谢以上开源项目为 MeloX 的歌词解析、逐字渲染和网易云播放器实现提供方法参考。")
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

    private let telegramURL = URL(string: "https://t.me/malo_x_official")!

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

    private let acknowledgements = [
        AcknowledgedProject(
            name: "jayfunc/BetterLyrics",
            contribution: "逐字歌词渲染、光效与动效参考",
            url: URL(string: "https://github.com/jayfunc/BetterLyrics")!
        ),
        AcknowledgedProject(
            name: "WXRIW/Lyricify-Lyrics-Helper",
            contribution: "网易云 YRC 逐字歌词解析参考",
            url: URL(string: "https://github.com/WXRIW/Lyricify-Lyrics-Helper")!
        ),
        AcknowledgedProject(
            name: "qier222/YesPlayMusic",
            contribution: "网易云接口与播放器实现参考",
            url: URL(string: "https://github.com/qier222/YesPlayMusic")!
        ),
    ]
}

private struct AppUpdateAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let releaseURL: URL?
}

private struct AcknowledgedProject: Identifiable {
    let name: String
    let contribution: String
    let url: URL

    var id: String { name }
}
