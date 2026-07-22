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
                NavigationLink {
                    SkylineLyricsSettingsView()
                } label: {
                    Label("全屏天际歌词", systemImage: "textformat.size")
                }
            } header: {
                Text("全屏歌词")
            } footer: {
                Text("调整播放器横屏状态下全屏天际歌词的文字和背景动态效果。")
            }

            Section {
                Picker("歌词样式", selection: $settings.lyricsStyle) {
                    ForEach(LyricsStyle.allCases) { style in
                        Label(style.title, systemImage: style.systemImage)
                            .tag(style)
                    }
                }

                valueSlider(
                    title: "字体大小",
                    value: $settings.lyricsFontSize,
                    range: 20...36,
                    step: 1,
                    valueText: "\(Int(settings.lyricsFontSize)) 磅"
                )

                if settings.lyricsStyle == .appleMusic {
                    valueSlider(
                        title: "当前歌词大小",
                        value: $settings.lyricsCurrentLineScale,
                        range: AppSettings.lyricsCurrentLineScaleRange,
                        step: 0.01,
                        valueText: "\(Int((settings.lyricsCurrentLineScale * 100).rounded()))%"
                    )

                    valueSlider(
                        title: "歌词行距",
                        value: $settings.lyricsLineSpacing,
                        range: 12...36,
                        step: 1,
                        valueText: "\(Int(settings.lyricsLineSpacing))"
                    )

                    valueSlider(
                        title: "基础模糊强度",
                        value: $settings.lyricsBlurIntensity,
                        range: 0...2,
                        step: 0.1,
                        valueText: settings.lyricsBlurIntensity.formatted(
                            .number.precision(.fractionLength(1))
                        )
                    )

                    valueSlider(
                        title: "默认逐句模糊加强",
                        value: $settings.lyricsDistanceBlurScale,
                        range: AppSettings.lyricsDistanceBlurScaleRange,
                        step: 0.05,
                        valueText: "\(Int((settings.lyricsDistanceBlurScale * 100).rounded()))%"
                    )

                    valueSlider(
                        title: "隐藏 UI 逐句模糊加强",
                        value: $settings.lyricsHiddenInterfaceBlurScale,
                        range: AppSettings.lyricsDistanceBlurScaleRange,
                        step: 0.05,
                        valueText: "\(Int((settings.lyricsHiddenInterfaceBlurScale * 100).rounded()))%"
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
                        range: AppSettings.lyricsFocusPositionRange,
                        step: 0.01,
                        valueText: "距顶部 \(Int(settings.lyricsFocusPosition * 100))%"
                    )
                }

                if settings.lyricsStyle == .textPV1 {
                    valueSlider(
                        title: "PV 动效强度",
                        value: $settings.textPV1MotionIntensity,
                        range: AppSettings.textPV1MotionIntensityRange,
                        step: 0.1,
                        valueText: "\(Int((settings.textPV1MotionIntensity * 100).rounded()))%"
                    )
                }
            } header: {
                Text("歌词外观")
            } footer: {
                Text("\(settings.lyricsStyle.title)：\(settings.lyricsStyle.description)。播放器底部也可以快速切换；所有样式都会沿用字体与翻译设置，逐字动效仅用于 Apple Music 样式。逐句模糊加强只调整随焦点距离递增的模糊，100% 为原始强度；默认状态与隐藏 UI 后可以分别设置。文字PV1 每两句更换一次构图；同构图换词仅做轻量回弹，高潮段使用猛烈旋转重击转场，停留阶段保持静止。系统减少动态效果开启时自动停用强动效。")
            }

            Section {
                Picker("刷新频率", selection: $settings.lyricsRefreshRate) {
                    ForEach(LyricsRefreshRate.allCases) { refreshRate in
                        Text(refreshRate.title).tag(refreshRate)
                    }
                }
            } header: {
                Text("歌词性能")
            } footer: {
                Text("默认使用 60 FPS，并应用到所有歌词页。较高刷新频率会增加耗电；系统低电量模式期间会自动降至 30 FPS，退出后恢复所选频率。")
            }

            Section {
                valueSlider(
                    title: "每行切换延迟",
                    value: $settings.lyricsFocusCascadeDelay,
                    range: AppSettings.lyricsFocusCascadeDelayRange,
                    step: 0.005,
                    valueText: "\(Int((settings.lyricsFocusCascadeDelay * 1_000).rounded())) 毫秒"
                )

                Toggle(
                    "错峰轻微回弹",
                    isOn: $settings.lyricsFocusCascadeBounceEnabled
                )

                valueSlider(
                    title: "焦点颜色提前",
                    value: $settings.lyricsFocusColorLeadTime,
                    range: AppSettings.lyricsFocusColorLeadTimeRange,
                    step: 0.005,
                    valueText: "\(Int((settings.lyricsFocusColorLeadTime * 1_000).rounded())) 毫秒"
                )
            } header: {
                Text("歌词动画")
            } footer: {
                Text("焦点颜色会先开始过渡；等待设置的提前量后，可视顶部第一行与模糊同时开始变化，随后各行依次向上。默认开启较慢的轻微回弹；剩余时间不足时会依次取消回弹并压缩逐行延迟与过渡时长，只有连最短 50 毫秒过渡也无法保留时才直接同步。每行延迟设为 0 可恢复整体滚动。")
            }

            Section {
                Toggle("显示歌词翻译", isOn: $settings.lyricsTranslationEnabled)

                if settings.lyricsTranslationEnabled {
                    valueSlider(
                        title: "翻译歌词大小",
                        value: $settings.lyricsTranslationFontScale,
                        range: 0.5...0.8,
                        step: 0.05,
                        valueText: "\(Int(settings.lyricsTranslationFontScale * 100))%"
                    )

                    valueSlider(
                        title: "翻译歌词亮度",
                        value: $settings.lyricsTranslationOpacity,
                        range: 0.4...0.9,
                        step: 0.05,
                        valueText: "\(Int(settings.lyricsTranslationOpacity * 100))%"
                    )
                }

                Toggle("逐字歌词", isOn: $settings.lyricsWordByWord)

                if settings.lyricsWordByWord || settings.lyricsPseudoWordByWord {
                    Toggle("逐字歌词光效", isOn: $settings.lyricsGlowEnabled)

                    if settings.lyricsGlowEnabled {
                        valueSlider(
                            title: "逐字光效强度",
                            value: $settings.lyricsGlowIntensity,
                            range: 0.4...1.6,
                            step: 0.1,
                            valueText: settings.lyricsGlowIntensity.formatted(
                                .number.precision(.fractionLength(1))
                            )
                        )
                    }
                }
            } header: {
                Text("歌词内容与光效")
            } footer: {
                Text("中英翻译直接使用网易云提供的 ytlrc 或 tlyric。逐字歌词开关仅控制歌曲自带的 YRC 时间轴。")
            }

            Section {
                Toggle("启用伪逐字歌词", isOn: $settings.lyricsPseudoWordByWord)
            } header: {
                Text("伪逐字歌词")
            } footer: {
                Text("默认关闭，仅在整首歌没有 YRC 时间轴时，按照每行字数和持续时间生成逐字进度；该开关可独立于歌曲自带的逐字歌词使用。")
            }

            Section {
                Picker(
                    "屏幕常亮",
                    selection: $settings.playerScreenAwakeMode
                ) {
                    ForEach(PlayerScreenAwakeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("屏幕常亮")
            } footer: {
                Text("用于阻止系统自动锁屏。天际歌词继续使用其独立的屏幕常亮设置。")
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
                Text("提前量会让歌词比歌曲时间更早进入播放焦点；仅在启用恢复跟随后才会在手动浏览后返回播放位置。")
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
