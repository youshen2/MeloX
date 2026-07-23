import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    "启动时继续上次页面",
                    isOn: $settings.restoresLastSelectedTab
                )

                Picker("默认启动页面", selection: $settings.defaultLaunchTab) {
                    ForEach(AppTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                .disabled(settings.restoresLastSelectedTab)
            } header: {
                Text("启动与导航")
            } footer: {
                if settings.restoresLastSelectedTab {
                    Text("下次启动时会回到最后使用的主页面。关闭后，将打开所选的默认启动页面。")
                } else {
                    Text("默认启动页面会在下次启动 MeloX 时生效。")
                }
            }

            Section {
                Toggle(
                    "记住上次音乐库页面",
                    isOn: $settings.restoresLastLibraryPage
                )

                Picker(
                    "默认打开页面",
                    selection: $settings.defaultLibraryPage
                ) {
                    ForEach(LibraryPage.allCases) { page in
                        Label(page.title, systemImage: page.systemImage)
                            .tag(page)
                    }
                }
                .disabled(settings.restoresLastLibraryPage)
            } header: {
                Text("音乐库")
            } footer: {
                if settings.restoresLastLibraryPage {
                    Text("重新启动后，音乐库会恢复到最后浏览的歌曲、歌单、下载、云盘或历史页面。")
                } else {
                    Text("每次启动 MeloX 后首次打开音乐库时，会显示所选页面。")
                }
            }
        }
        .navigationTitle("通用")
    }
}
