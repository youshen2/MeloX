import SwiftUI

private enum AccountSettingsSheet: String, Identifiable {
    case neteaseLogin

    var id: String { rawValue }
}

struct AccountSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    @State private var showsClearAccountConfirmation = false
    @State private var presentedSheet: AccountSettingsSheet?

    var body: some View {
        Form {
            Section {
                if settings.cookie.isEmpty {
                    Button {
                        presentedSheet = .neteaseLogin
                    } label: {
                        Label("登录网易云音乐", systemImage: "person.crop.circle.badge.plus")
                    }
                } else {
                    LabeledContent {
                        Text("已登录")
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("网易云音乐", systemImage: "person.crop.circle.badge.checkmark")
                    }

                    Button("重新登录") {
                        Task {
                            settings.clearAccount()
                            library.clearAccountData()
                            await NeteaseWebCookieStore.clear()
                            presentedSheet = .neteaseLogin
                        }
                    }

                    Button("清除登录信息", role: .destructive) {
                        showsClearAccountConfirmation = true
                    }
                }
            } header: {
                Text("网易云账号")
            } footer: {
                Text("登录将在网易云音乐网页中完成。MeloX 会自动读取登录 Cookie 并仅保存在本机，用于每日推荐和账号相关内容。")
            }
        }
        .navigationTitle("账号")
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .neteaseLogin:
                NavigationStack {
                    NeteaseLoginView()
                }
            }
        }
        .confirmationDialog("清除本机保存的登录 Cookie？", isPresented: $showsClearAccountConfirmation) {
            Button("清除", role: .destructive) {
                settings.clearAccount()
                library.clearAccountData()
                Task {
                    await NeteaseWebCookieStore.clear()
                }
            }
        }
    }
}
