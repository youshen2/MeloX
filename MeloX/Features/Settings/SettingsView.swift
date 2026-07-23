import SwiftUI

struct SettingsView: View {
    @Environment(DownloadStore.self) private var downloads

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    AccountSettingsView()
                } label: {
                    Label("账号", systemImage: "person.crop.circle")
                }

                NavigationLink {
                    PlayerSettingsView()
                } label: {
                    Label("播放器", systemImage: "play.circle")
                }

                NavigationLink {
                    ContentSettingsView()
                } label: {
                    Label("内容", systemImage: "rectangle.stack")
                }

                NavigationLink {
                    DownloadsView()
                } label: {
                    HStack {
                        Label("下载管理", systemImage: "arrow.down.circle")
                        Spacer()
                        Text(downloads.totalByteCount.formatted(.byteCount(style: .file)))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("关于", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("设置")
    }
}
