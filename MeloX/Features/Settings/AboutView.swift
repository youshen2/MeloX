import SwiftUI

struct AboutView: View {
    var body: some View {
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

            Section("关于 MeloX") {
                Text("MeloX 使用原生 SwiftUI 构建，专注于提供简洁、流畅的网易云音乐播放与歌词体验。")
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
    }

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "—"
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

private struct AcknowledgedProject: Identifiable {
    let name: String
    let contribution: String
    let url: URL

    var id: String { name }
}
