import SwiftUI

struct ContentSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("发现内容") {
                Picker("新碟地区", selection: $settings.musicArea) {
                    Text("全部").tag("ALL")
                    Text("华语").tag("ZH")
                    Text("欧美").tag("EA")
                    Text("韩国").tag("KR")
                    Text("日本").tag("JP")
                }

                Toggle("显示歌单播放量", isOn: $settings.showPlayCount)
            }
        }
        .navigationTitle("内容")
    }
}
