import SwiftUI

struct EqualizerSettingsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    @State private var selectedBand: AudioEqualizerBand = .khz1

    var body: some View {
        Form {
            Section {
                Toggle("图形均衡器", isOn: enabledBinding)
            } footer: {
                Text("实时作用于网络播放与已下载歌曲；关闭后将绕过全部均衡处理。")
            }

            Section {
                Picker("预设", selection: presetBinding) {
                    if settings.equalizer.selectedPreset == .custom {
                        Text(AudioEqualizerPreset.custom.title)
                            .tag(AudioEqualizerPreset.custom)
                    }

                    ForEach(
                        AudioEqualizerPreset.allCases.filter {
                            $0 != .custom
                        }
                    ) { preset in
                        Text(preset.title).tag(preset)
                    }
                }

                valueSlider(
                    title: "前置放大",
                    value: preampBinding,
                    range: AudioEqualizerPreferences.preampRange,
                    valueText: decibelText(settings.equalizer.preamp)
                )
            } header: {
                Text("预设与增益")
            } footer: {
                Text("提升多个频段时可降低前置放大，为瞬态峰值保留余量并减少削波失真。")
            }
            .disabled(!settings.equalizer.isEnabled)

            Section {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibleBandSliders
                } else {
                    graphicEqualizer
                        .frame(height: 330)
                        .listRowInsets(
                            EdgeInsets(
                                top: 14,
                                leading: 12,
                                bottom: 14,
                                trailing: 12
                            )
                        )
                }
            } header: {
                Text("10 段图形均衡器")
            } footer: {
                Text("中心频率按倍频程排列，每段可调 ±12 dB；手动修改后会自动保存为自定义预设。")
            }
            .disabled(!settings.equalizer.isEnabled)
        }
        .navigationTitle("均衡器")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("恢复默认") {
                    settings.equalizer.resetCurve()
                }
            }
        }
        .onChange(
            of: settings.equalizer.configuration,
            initial: true
        ) {
            player.applyEqualizerSettings()
        }
    }

    private var graphicEqualizer: some View {
        GeometryReader { proxy in
            let scaleWidth = 38.0
            let valueRowHeight = 24.0
            let frequencyRowHeight = 24.0
            let plotHeight = max(
                proxy.size.height
                    - valueRowHeight
                    - frequencyRowHeight
                    - 14,
                180
            )
            let plotWidth = max(proxy.size.width - scaleWidth, 1)
            let columnWidth = plotWidth
                / Double(AudioEqualizerBand.count)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(selectedBand.title)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(
                        decibelText(
                            settings.equalizer.gain(for: selectedBand)
                        )
                    )
                    .fontWeight(.semibold)
                    .monospacedDigit()
                }
                .font(.caption)
                .frame(height: valueRowHeight)

                HStack(alignment: .top, spacing: 0) {
                    decibelScale
                        .frame(width: scaleWidth, height: plotHeight)

                    ZStack(alignment: .top) {
                        equalizerGrid
                            .frame(height: plotHeight)

                        HStack(alignment: .top, spacing: 0) {
                            ForEach(AudioEqualizerBand.allCases) { band in
                                VStack(spacing: 4) {
                                    verticalSlider(
                                        for: band,
                                        height: plotHeight,
                                        width: columnWidth
                                    )

                                    Text(band.shortTitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .minimumScaleFactor(0.72)
                                        .lineLimit(1)
                                        .frame(
                                            width: columnWidth,
                                            height: frequencyRowHeight
                                        )
                                }
                            }
                        }
                        .frame(width: plotWidth)
                    }
                    .frame(width: plotWidth)
                }
            }
        }
    }

    private var decibelScale: some View {
        VStack {
            Text("+12")
            Spacer()
            Text("0")
            Spacer()
            Text("−12")
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.tertiary)
        .padding(.vertical, 13)
        .accessibilityHidden(true)
    }

    private var equalizerGrid: some View {
        VStack {
            Divider()
            Spacer()
            Divider()
            Spacer()
            Divider()
        }
        .padding(.vertical, 16)
        .opacity(0.7)
        .accessibilityHidden(true)
    }

    private var accessibleBandSliders: some View {
        ForEach(AudioEqualizerBand.allCases) { band in
            valueSlider(
                title: band.title,
                value: gainBinding(for: band),
                range: AudioEqualizerPreferences.bandGainRange,
                valueText: decibelText(
                    settings.equalizer.gain(for: band)
                )
            )
        }
    }

    private func verticalSlider(
        for band: AudioEqualizerBand,
        height: Double,
        width: Double
    ) -> some View {
        Slider(
            value: gainBinding(for: band),
            in: AudioEqualizerPreferences.bandGainRange,
            step: 0.5
        ) { isEditing in
            if isEditing {
                selectedBand = band
            }
        }
        .frame(width: max(height - 24, 1))
        .rotationEffect(.degrees(-90))
        .frame(width: width, height: height)
        .controlSize(.small)
        .contentShape(.rect)
        .accessibilityLabel("\(band.title) 频段")
        .accessibilityValue(
            decibelText(settings.equalizer.gain(for: band))
        )
        .accessibilityHint("上下调整频段增益")
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { settings.equalizer.isEnabled },
            set: { settings.equalizer.isEnabled = $0 }
        )
    }

    private var presetBinding: Binding<AudioEqualizerPreset> {
        Binding(
            get: { settings.equalizer.selectedPreset },
            set: { settings.equalizer.apply($0) }
        )
    }

    private var preampBinding: Binding<Double> {
        Binding(
            get: { settings.equalizer.preamp },
            set: { settings.equalizer.setPreamp($0) }
        )
    }

    private func gainBinding(
        for band: AudioEqualizerBand
    ) -> Binding<Double> {
        Binding(
            get: { settings.equalizer.gain(for: band) },
            set: { settings.equalizer.setGain($0, for: band) }
        )
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title, value: valueText)
                .monospacedDigit()

            Slider(value: value, in: range, step: 0.5)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }

    private func decibelText(_ value: Double) -> String {
        let normalizedValue = abs(value) < 0.05 ? 0 : value
        guard normalizedValue != 0 else { return "0.0 dB" }
        return normalizedValue.formatted(
            .number
                .sign(strategy: .always())
                .precision(.fractionLength(1))
        ) + " dB"
    }
}

private extension AudioEqualizerBand {
    var shortTitle: String {
        switch self {
        case .hz31: "31"
        case .hz62: "62"
        case .hz125: "125"
        case .hz250: "250"
        case .hz500: "500"
        case .khz1: "1K"
        case .khz2: "2K"
        case .khz4: "4K"
        case .khz8: "8K"
        case .khz16: "16K"
        }
    }
}
