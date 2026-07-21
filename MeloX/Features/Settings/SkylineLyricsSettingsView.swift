import SwiftUI

struct SkylineLyricsSettingsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var showsResetConfirmation = false

    var body: some View {
        @Bindable var preferences = settings.skylineLyrics

        Form {
            Section {
                Toggle("屏幕常亮", isOn: $preferences.keepsScreenAwake)
            } footer: {
                Text("仅在全屏天际歌词可见时阻止屏幕自动锁定。")
            }

            Section {
                valueSlider(
                    title: "当前歌词字号",
                    value: $preferences.currentLyricFontSize,
                    range: 36...84,
                    step: 1,
                    valueText: pointValue(preferences.currentLyricFontSize)
                )

                valueSlider(
                    title: "逐字歌词最大缩放",
                    value: $preferences.currentLyricMaximumScale,
                    range: 1...1.2,
                    step: 0.01,
                    valueText: scaleValue(preferences.currentLyricMaximumScale)
                )

                valueSlider(
                    title: "中央显示宽度",
                    value: $preferences.currentLyricsWidth,
                    range: 0.4...0.82,
                    step: 0.02,
                    valueText: percentValue(preferences.currentLyricsWidth)
                )
            } header: {
                Text("当前歌词")
            } footer: {
                Text("逐字歌词会随演唱进度持续放大，并在整句唱完时达到最大缩放。")
            }

            Section {
                valueSlider(
                    title: "下一句字号",
                    value: $preferences.nextLyricFontSize,
                    range: 14...44,
                    step: 1,
                    valueText: pointValue(preferences.nextLyricFontSize)
                )

                valueSlider(
                    title: "下一句亮度",
                    value: $preferences.nextLyricOpacity,
                    range: 0.2...0.8,
                    step: 0.05,
                    valueText: percentValue(preferences.nextLyricOpacity)
                )

                valueSlider(
                    title: "中央歌词间距",
                    value: $preferences.currentLyricsSpacing,
                    range: 4...36,
                    step: 1,
                    valueText: pointValue(preferences.currentLyricsSpacing)
                )
            } header: {
                Text("下一句歌词")
            } footer: {
                Text("歌曲没有下一句时，当前歌词仍会保持屏幕居中。")
            }

            Section {
                valueSlider(
                    title: "背景字号",
                    value: $preferences.ambientFontSize,
                    range: 24...72,
                    step: 1,
                    valueText: pointValue(preferences.ambientFontSize)
                )

                Picker(
                    "单组最大字数",
                    selection: $preferences.ambientMaximumCharacters
                ) {
                    Text("1 个字").tag(1)
                    Text("2 个字").tag(2)
                    Text("3 个字").tag(3)
                    Text("4 个字").tag(4)
                }

                Stepper(
                    value: $preferences.ambientMaximumVisibleTexts,
                    in: 4...24
                ) {
                    LabeledContent(
                        "同屏文字上限",
                        value: "\(preferences.ambientMaximumVisibleTexts) 组"
                    )
                }

                valueSlider(
                    title: "背景字亮度",
                    value: $preferences.ambientOpacity,
                    range: 0.4...1.8,
                    step: 0.1,
                    valueText: scaleValue(preferences.ambientOpacity)
                )

                valueSlider(
                    title: "背景字模糊",
                    value: $preferences.ambientBlur,
                    range: 0...2,
                    step: 0.1,
                    valueText: scaleValue(preferences.ambientBlur)
                )
            } header: {
                Text("背景歌词")
            } footer: {
                Text("长歌词片段会按最大字数自动分组；已有文字会持续放大、变模糊，足够大后消失；超过同屏上限时优先移除最早出现的文字。")
            }

            Section {
                valueSlider(
                    title: "最大倾斜角度",
                    value: $preferences.ambientMaximumTilt,
                    range: 0...20,
                    step: 1,
                    valueText: "\(Int(preferences.ambientMaximumTilt))°"
                )

                valueSlider(
                    title: "漂移幅度",
                    value: $preferences.ambientDrift,
                    range: 0...2,
                    step: 0.1,
                    valueText: scaleValue(preferences.ambientDrift)
                )
            } header: {
                Text("背景动态")
            } footer: {
                Text("每组背景字会出现在完全随机的位置，并在最大角度内随机倾斜；系统开启“减弱动态效果”时，背景漂移会自动停用。")
            }

            Section {
                Button("恢复全屏天际歌词默认设置", role: .destructive) {
                    showsResetConfirmation = true
                }
            }
        }
        .navigationTitle("全屏天际歌词")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("恢复全屏天际歌词默认设置？", isPresented: $showsResetConfirmation) {
            Button("恢复默认设置", role: .destructive) {
                preferences.reset()
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

    private func pointValue(_ value: Double) -> String {
        "\(Int(value)) 磅"
    }

    private func percentValue(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func scaleValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + "×"
    }
}
