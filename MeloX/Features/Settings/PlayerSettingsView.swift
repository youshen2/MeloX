import SwiftUI

struct PlayerSettingsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var showsResetConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("音频") {
                Picker("音质", selection: $settings.quality) {
                    ForEach(MusicQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
            }

            Section {
                valueSlider(
                    title: "背景模糊",
                    value: $settings.playerBackgroundBlur,
                    range: 0...140,
                    step: 5,
                    valueText: "\(Int(settings.playerBackgroundBlur))"
                )

                valueSlider(
                    title: "背景色彩",
                    value: $settings.playerBackgroundSaturation,
                    range: 0.4...1.2,
                    step: 0.05,
                    valueText: "\(Int(settings.playerBackgroundSaturation * 100))%"
                )

                Toggle("暂停时缩小封面", isOn: $settings.shrinksPausedArtwork)
            } header: {
                Text("播放器外观")
            } footer: {
                Text("背景选项会实时作用于展开的播放器。")
            }

            Section {
                Toggle("记住所处页面", isOn: $settings.rememberNowPlayingPage)

                Toggle("上一首优先回到歌曲开头", isOn: $settings.previousRestartsCurrentSong)
            } header: {
                Text("播放器行为")
            } footer: {
                Text("页面记忆会恢复上次关闭时的封面、歌词或队列。关闭上一首回到开头后，按钮会始终直接切换歌曲。")
            }

            Section {
                valueSlider(
                    title: "字体大小",
                    value: $settings.lyricsFontSize,
                    range: 20...36,
                    step: 1,
                    valueText: "\(Int(settings.lyricsFontSize)) 磅"
                )

                valueSlider(
                    title: "歌词行距",
                    value: $settings.lyricsLineSpacing,
                    range: 12...36,
                    step: 1,
                    valueText: "\(Int(settings.lyricsLineSpacing))"
                )

                valueSlider(
                    title: "模糊强度",
                    value: $settings.lyricsBlurIntensity,
                    range: 0...2,
                    step: 0.1,
                    valueText: settings.lyricsBlurIntensity.formatted(.number.precision(.fractionLength(1)))
                )

                valueSlider(
                    title: "非焦点歌词变暗",
                    value: $settings.lyricsDimAmount,
                    range: 0...1,
                    step: 0.1,
                    valueText: "\(Int(settings.lyricsDimAmount * 100))%"
                )

                valueSlider(
                    title: "焦点垂直位置",
                    value: $settings.lyricsFocusPosition,
                    range: 0.2...0.5,
                    step: 0.01,
                    valueText: "距顶部 \(Int(settings.lyricsFocusPosition * 100))%"
                )
            } header: {
                Text("歌词外观")
            } footer: {
                Text("模糊仍从距离焦点的第三行歌词开始，强度为 0 时关闭模糊效果。焦点位置可以在屏幕上方与中间之间调整。")
            }

            Section {
                Toggle("双击歌词跳转", isOn: $settings.lyricsTapToSeek)

                valueSlider(
                    title: "歌词提前量",
                    value: $settings.lyricsAdvanceTime,
                    range: 0...5,
                    step: 0.1,
                    valueText: "\(settings.lyricsAdvanceTime.formatted(.number.precision(.fractionLength(1)))) 秒"
                )

                Toggle("浏览后恢复跟随", isOn: $settings.lyricsAutoFollow)

                if settings.lyricsAutoFollow {
                    valueSlider(
                        title: "恢复跟随等待",
                        value: $settings.lyricsFollowDelay,
                        range: 1...10,
                        step: 1,
                        valueText: "\(Int(settings.lyricsFollowDelay)) 秒"
                    )
                }
            } header: {
                Text("歌词交互")
            } footer: {
                Text("提前量会让歌词比歌曲时间更早进入播放焦点。手动浏览时模糊始终以浏览焦点计算；仅在启用恢复跟随后才会返回播放位置。")
            }

            Section {
                Button("恢复播放器默认设置", role: .destructive) {
                    showsResetConfirmation = true
                }
            }
        }
        .navigationTitle("播放器")
        .confirmationDialog("恢复播放器默认设置？", isPresented: $showsResetConfirmation) {
            Button("恢复默认设置", role: .destructive) {
                settings.resetPlayerSettings()
            }
        }
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title, value: valueText)
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }
}
