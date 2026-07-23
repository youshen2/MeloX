import SwiftUI

enum SettingsRoute: Hashable {
    case accountHome
    case privateMessages
}

struct SettingsView: View {
    @Environment(DownloadStore.self) private var downloads
    @Environment(LibraryStore.self) private var library

    var body: some View {
        Form {
            SettingsAccountSection()

            Section {
                NavigationLink {
                    GeneralSettingsView()
                } label: {
                    Label("通用", systemImage: "slider.horizontal.3")
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
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .accountHome:
                if let profile = library.profile {
                    AccountHomeView(
                        initialProfile: profile,
                        initialDetail: library.accountDetail,
                        initialPlaylists: library.favoritePlaylists
                    )
                } else {
                    ContentUnavailableView(
                        "账号信息不可用",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                }
            case .privateMessages:
                NeteasePrivateMessagesView()
            }
        }
    }
}
