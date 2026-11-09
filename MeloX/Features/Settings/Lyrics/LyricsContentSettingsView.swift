import SwiftUI

struct LyricsContentSettingsView: View {
    @Environment(AppSettings.self) private var settings

    private var usesWordByWordPresentation: Bool {
        settings.lyricsWordByWord || settings.lyricsPseudoWordByWord
    }

    private var usesAppleMusic26Motion: Bool {
        settings.lyricsStyle == .appleMusic
            && settings.appleMusicLyrics.usesAppleMusic26Motion
    }

    private var usesCustomAppleMusicPresentation: Bool {
        settings.lyricsStyle == .appleMusic
            && !settings.appleMusicLyrics.usesAppleMusic26Motion
    }

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    "ui.settings.lyrics.content.show_romanization",
                    isOn: $settings.lyricsRomanizationEnabled
                )

                Toggle(
                    "ui.settings.lyrics.content.show_translation",
                    isOn: $settings.lyricsTranslationEnabled
                )

                if usesCustomAppleMusicPresentation,
                   settings.lyricsRomanizationEnabled {
                    Picker(
                        "ui.settings.lyrics.content.romanization_display_range",
                        selection:
                            $settings
                                .lyricsRomanizationDisplayMode
                    ) {
                        ForEach(
                            LyricsTranslationDisplayMode.allCases
                        ) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                if usesCustomAppleMusicPresentation,
                   settings.lyricsTranslationEnabled {
                    Picker(
                        "ui.settings.lyrics.content.translation_display_range",
                        selection:
                            $settings
                                .lyricsTranslationDisplayMode
                    ) {
                        ForEach(
                            LyricsTranslationDisplayMode.allCases
                        ) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }
            } header: {
                Text("ui.settings.lyrics.content.section.translation_pronunciation")
            } footer: {
                Text("ui.settings.lyrics.content.translation.footer")
            }

            if usesCustomAppleMusicPresentation,
               settings.lyricsRomanizationEnabled {
                Section {
                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.content.romanization_size"),
                        value: $settings.lyricsRomanizationFontScale,
                        range: 0.5...0.8,
                        step: 0.05,
                        valueText:
                            L10n.percent(settings.lyricsRomanizationFontScale)
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.content.romanization_brightness"),
                        value: $settings.lyricsRomanizationOpacity,
                        range: 0.4...0.9,
                        step: 0.05,
                        valueText:
                            L10n.percent(settings.lyricsRomanizationOpacity)
                    )
                } header: {
                    Text("ui.settings.lyrics.content.section.romanization_style")
                }
            }

            if usesCustomAppleMusicPresentation,
               settings.lyricsTranslationEnabled {
                Section {
                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.content.translation_size"),
                        value: $settings.lyricsTranslationFontScale,
                        range: 0.5...0.8,
                        step: 0.05,
                        valueText:
                            L10n.percent(settings.lyricsTranslationFontScale)
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.content.translation_brightness"),
                        value: $settings.lyricsTranslationOpacity,
                        range: 0.4...0.9,
                        step: 0.05,
                        valueText:
                            L10n.percent(settings.lyricsTranslationOpacity)
                    )
                } header: {
                    Text("ui.settings.lyrics.content.section.translation_style")
                }
            }

            Section {
                Picker(
                    "ui.settings.lyrics.content.default_source",
                    selection: $settings.lyricsSourcePreference
                ) {
                    ForEach(LyricSourcePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }

                Toggle(
                    "ui.settings.lyrics.content.amll_source",
                    isOn: $settings.lyricsAMLLSourceEnabled
                )

                Toggle(
                    "ui.settings.lyrics.content.qq_source",
                    isOn: $settings.lyricsQQMusicSourceEnabled
                )
            } header: {
                Text("ui.settings.lyrics.content.section.source")
            } footer: {
                Text("ui.settings.lyrics.content.source.footer")
            }

            Section {
                Toggle(
                    "ui.settings.lyrics.content.duet_layout",
                    isOn: $settings.lyricsDuetLayoutEnabled
                )
            } header: {
                Text("ui.settings.lyrics.content.section.performer_layout")
            } footer: {
                Text("ui.settings.lyrics.content.duet_layout.footer")
            }

            Section {
                Toggle(
                    "ui.settings.lyrics.content.official_word_by_word",
                    isOn: $settings.lyricsWordByWord
                )

                Toggle(
                    "ui.settings.lyrics.content.pseudo_word_by_word",
                    isOn: $settings.lyricsPseudoWordByWord
                )
            } header: {
                Text("ui.settings.lyrics.content.section.word_by_word")
            } footer: {
                Text("ui.settings.lyrics.content.word_by_word.footer")
            }

            if usesWordByWordPresentation {
                if usesAppleMusic26Motion {
                    Section {
                        LabeledContent(L10n.string("ui.settings.lyrics.content.highlight_gradient"), value: L10n.format("ui.common.points", 30))
                        LabeledContent(L10n.string("ui.settings.lyrics.content.syllable_lift"), value: L10n.format("ui.common.points", 2))
                        LabeledContent(L10n.string("ui.settings.lyrics.content.glow_radius"), value: L10n.format("ui.common.points", 5))
                        LabeledContent(L10n.string("ui.settings.lyrics.content.long_tone_maximum_emphasis"), value: "114%")

                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.content.netease_yrc_long_tone_threshold"),
                            value:
                                $settings
                                    .lyricsLongSyllableDurationThreshold,
                            range:
                                AppSettings
                                    .lyricsLongSyllableDurationThresholdRange,
                            step: 0.05,
                            valueText:
                                L10n.format("ui.common.seconds_two_decimals", settings.lyricsLongSyllableDurationThreshold)
                        )
                    } header: {
                        Text("ui.settings.lyrics.content.section.apple_music_word_by_word")
                    } footer: {
                        Text("ui.settings.lyrics.content.long_tone_threshold.footer")
                    }
                }

                if !usesAppleMusic26Motion {
                    Section {
                        FilterPicker(
                            title: "ui.settings.lyrics.content.lift_mode",
                            selection: $settings.lyricsLiftMode
                        ) {
                            ForEach(LyricsLiftMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .padding(.vertical, 4)

                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.content.highlight_gradient_width"),
                            value:
                                $settings.lyricsHighlightGradientWidth,
                            range:
                                AppSettings
                                    .lyricsHighlightGradientWidthRange,
                            step: 0.1,
                            valueText:
                                L10n.format("ui.common.character_widths", settings.lyricsHighlightGradientWidth)
                        )

                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.content.gradient_reduction"),
                            value:
                                $settings
                                    .lyricsHighlightGradientReduction,
                            range:
                                AppSettings
                                    .lyricsHighlightGradientReductionRange,
                            step: 0.05,
                            valueText: settings
                                .lyricsHighlightGradientReduction
                                .formatted(
                                    .percent.precision(
                                        .fractionLength(0)
                                    )
                                    .locale(L10n.locale)
                                )
                        )
                    } header: {
                        Text("ui.settings.lyrics.content.section.highlight")
                    } footer: {
                        Text("ui.settings.lyrics.content.highlight.footer")
                    }

                    Section {
                        FilterPicker(
                            title: "ui.settings.lyrics.content.long_tone_detection",
                            selection:
                                $settings
                                    .lyricsLongSyllableDetectionMode
                        ) {
                            ForEach(
                                LyricsLongSyllableDetectionMode.allCases
                            ) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .padding(.vertical, 4)

                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.content.long_tone_threshold"),
                            value:
                                $settings
                                    .lyricsLongSyllableDurationThreshold,
                            range:
                                AppSettings
                                    .lyricsLongSyllableDurationThresholdRange,
                            step: 0.05,
                            valueText:
                                L10n.format("ui.common.seconds_two_decimals", settings.lyricsLongSyllableDurationThreshold)
                        )

                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.content.long_tone_expansion"),
                            value:
                                $settings
                                    .lyricsLongToneExpansionAmount,
                            range:
                                AppSettings
                                    .lyricsLongToneExpansionAmountRange,
                            step: 0.01,
                            valueText: settings
                                .lyricsLongToneExpansionAmount
                                .formatted(
                                    .percent.precision(
                                        .fractionLength(0)
                                    )
                                    .locale(L10n.locale)
                                )
                        )

                        Toggle(
                            "ui.settings.lyrics.content.glow_effect",
                            isOn: $settings.lyricsGlowEnabled
                        )

                        if settings.lyricsGlowEnabled {
                            Toggle(
                                "ui.settings.lyrics.content.glow_long_tones_only",
                                isOn:
                                    $settings
                                        .lyricsGlowLongSyllablesOnly
                            )

                            valueSlider(
                                title: L10n.string("ui.settings.lyrics.content.glow_intensity"),
                                value: $settings.lyricsGlowIntensity,
                                range: 0.4...1.6,
                                step: 0.1,
                                valueText:
                                    settings.lyricsGlowIntensity
                                        .formatted(
                                            .number.precision(
                                                .fractionLength(1)
                                            )
                                            .locale(L10n.locale)
                                        )
                            )
                        }
                    } header: {
                        Text("ui.settings.lyrics.content.section.long_tone_glow")
                    } footer: {
                        Text("ui.settings.lyrics.content.long_tone_glow.footer")
                    }
                }
            }
        }
        .navigationTitle("ui.settings.lyrics.content.title")
        .navigationBarTitleDisplayMode(.inline)
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
