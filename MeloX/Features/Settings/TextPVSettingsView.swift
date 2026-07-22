import SwiftUI

struct TextPVSettingsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var showsResetConfirmation = false

    var body: some View {
        @Bindable var preferences = settings.textPV

        Form {
            Section {
                Picker("风格", selection: $preferences.style) {
                    ForEach(TextPVStyle.allCases) { style in
                        Label(style.title, systemImage: style.systemImage)
                            .tag(style)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("模板")
            } footer: {
                Text(preferences.style.description)
            }

            Section {
                valueSlider(
                    title: "动效强度",
                    value: $preferences.motionIntensity,
                    range: TextPVPreferences.motionIntensityRange
                )

                valueSlider(
                    title: "动画速度",
                    value: $preferences.animationSpeed,
                    range: TextPVPreferences.animationSpeedRange
                )
            } header: {
                Text("播放参数")
            } footer: {
                Text("参数范围与 pv-tool 保持一致。切换模板时会恢复该模板在参考项目中的动画速度；系统开启“减少动态效果”后动画会停在稳定画面。")
            }

            Section {
                Button("恢复文字PV默认设置", role: .destructive) {
                    showsResetConfirmation = true
                }
            }
        }
        .navigationTitle("文字PV")
        .confirmationDialog("恢复文字PV默认设置？", isPresented: $showsResetConfirmation) {
            Button("恢复默认设置", role: .destructive) {
                settings.textPV.reset()
            }
        }
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        let valueText = "\(Int((value.wrappedValue * 100).rounded()))%"

        return VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title, value: valueText)
            Slider(value: value, in: range, step: 0.1)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }
}
