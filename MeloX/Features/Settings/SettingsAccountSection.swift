import SwiftUI

private enum SettingsAccountSheet: String, Identifiable {
    case neteaseLogin

    var id: String { rawValue }
}

struct SettingsAccountSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    @State private var presentedSheet: SettingsAccountSheet?
    @State private var showsLogoutConfirmation = false

    var body: some View {
        Section {
            if library.isLoggedIn {
                loggedInContent
            } else {
                Button {
                    presentedSheet = .neteaseLogin
                } label: {
                    Label(
                        "登录网易云音乐",
                        systemImage: "person.crop.circle.badge.plus"
                    )
                }
            }
        } header: {
            Text("网易云账号")
        } footer: {
            if !library.isLoggedIn {
                Text("登录 Cookie 仅保存在本机，用于同步音乐库和账号相关内容。")
            }
        }
        .task(id: settings.cookie) {
            await library.refresh()
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .neteaseLogin:
                NavigationStack {
                    NeteaseLoginView()
                }
            }
        }
        .confirmationDialog(
            "退出当前网易云账号？",
            isPresented: $showsLogoutConfirmation
        ) {
            Button("退出登录", role: .destructive) {
                logout()
            }
        } message: {
            Text("本机保存的网易云登录 Cookie 和已加载的账号数据将被清除，已下载歌曲不会被删除。")
        }
    }

    @ViewBuilder
    private var loggedInContent: some View {
        if let profile = library.profile {
            NavigationLink(value: SettingsRoute.accountHome) {
                HStack(spacing: 12) {
                    accountAvatar(profile)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.nickname)
                            .font(.headline)
                            .lineLimit(1)

                        Text(accountSubtitle(profile))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityHint("打开个人主页")
        } else {
            HStack(spacing: 12) {
                ProgressView()
                Text("正在读取账号信息")
                    .foregroundStyle(.secondary)
            }
        }

        NavigationLink(value: SettingsRoute.privateMessages) {
            Label(
                "私信",
                systemImage: "bubble.left.and.bubble.right"
            )
        }

        Button("退出登录", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
            showsLogoutConfirmation = true
        }
    }

    private func accountAvatar(_ profile: AccountProfile) -> some View {
        AsyncImage(url: profile.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 52, height: 52)
        .background(.quaternary, in: .circle)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private func accountSubtitle(_ profile: AccountProfile) -> String {
        if let detail = library.accountDetail, detail.level > 0 {
            return "Lv.\(detail.level) · 用户 ID \(profile.id)"
        }
        return "用户 ID \(profile.id) · 查看个人主页"
    }

    private func logout() {
        settings.clearAccount()
        library.clearAccountData()
        Task {
            await NeteaseWebCookieStore.clear()
        }
    }
}
