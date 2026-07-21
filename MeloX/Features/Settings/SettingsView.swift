import SwiftUI

struct SettingsView: View {
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
