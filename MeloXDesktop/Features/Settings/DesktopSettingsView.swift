import AppKit
import SwiftUI

struct DesktopSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(DesktopAppModel.self) private var model
    @State private var selection: DesktopSettingsTab = .general
    @State private var showsResetConfirmation = false
    @State private var isResettingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                DesktopGeneralSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .tabItem { Label("ui.desktop.settings.tab.general", systemImage: "gearshape") }
                    .tag(DesktopSettingsTab.general)
                DesktopContentFeatureSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .tabItem { Label("ui.desktop.settings.tab.features", systemImage: "switch.2") }
                    .tag(DesktopSettingsTab.features)
                DesktopPlaybackAndLyricsSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .tabItem { Label("ui.settings.playback.section.playback", systemImage: "play.circle") }
                    .tag(DesktopSettingsTab.playback)
                DesktopFileSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .tabItem { Label("ui.desktop.settings.tab.files", systemImage: "folder") }
                    .tag(DesktopSettingsTab.files)
                DesktopAdvancedSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .tabItem { Label("ui.desktop.settings.tab.advanced", systemImage: "gearshape.2") }
                    .tag(DesktopSettingsTab.advanced)
            }
            .tabViewStyle(.automatic)
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 12) {
                Button {
                    openWindow(id: "about")
                } label: {
                    Image(systemName: "questionmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .clipShape(.circle)
                .help(L10n.string("ui.desktop.commands.about_melox"))

                Button("ui.desktop.settings.restore_defaults_ellipsis", role: .destructive) {
                    showsResetConfirmation = true
                }
                .disabled(isResettingSettings)

                Spacer()

                Button("ui.common.cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("ui.common.ok") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .tint(.red)
            }
            .controlSize(.large)
            .padding(.horizontal, 20)
            .frame(height: 58)
        }
        .frame(width: 650, height: selection.contentHeight)
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.24),
            value: selection
        )
        .alert(
            L10n.string("ui.desktop.settings.restore_defaults.confirmation"),
            isPresented: $showsResetConfirmation
        ) {
            Button("ui.desktop.settings.restore_defaults", role: .destructive) {
                resetPlayerSettings()
            }
            Button("ui.common.cancel", role: .cancel) {}
        } message: {
            Text("ui.desktop.settings.restore_defaults.message")
        }
    }

    private func resetPlayerSettings() {
        guard !isResettingSettings else { return }
        isResettingSettings = true

        Task { @MainActor in
            await DesktopPlayerSettingsResetter.reset(model: model)
            isResettingSettings = false
        }
    }
}

private enum DesktopSettingsTab: Hashable {
    case general
    case features
    case playback
    case files
    case advanced

    var contentHeight: CGFloat {
        switch self {
        case .general: 570
        case .features: 480
        case .playback: 620
        case .files: 620
        case .advanced: 600
        }
    }
}

private struct DesktopPlaybackAndLyricsSettingsView: View {
    @State private var page: Page = .playback

    var body: some View {
        VStack(spacing: 0) {
            Picker("ui.settings.playback.title", selection: $page) {
                Text("ui.settings.playback.section.playback").tag(Page.playback)
                Text("ui.common.lyrics").tag(Page.lyrics)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 180)
            .padding(.top, 12)

            Group {
                switch page {
                case .playback:
                    DesktopPlaybackSettingsView()
                case .lyrics:
                    DesktopLyricsSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private enum Page: Hashable {
        case playback
        case lyrics
    }
}

private struct DesktopGeneralSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        @Bindable var recognition = model.settings.songRecognition

        Form {
            Section("ui.settings.language.section") {
                Picker(
                    "ui.settings.language.picker",
                    selection: Binding(
                        get: { settings.appLanguage },
                        set: settings.setAppLanguage
                    )
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title)
                            .tag(language)
                    }
                }
                Text("ui.settings.language.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("ui.desktop.settings.appearance") {
                Picker("ui.desktop.settings.appearance", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(appearance.title, systemImage: appearance.systemImage)
                            .tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("ui.settings.content.show_play_count", isOn: $settings.showPlayCount)
            }

            Section("ui.desktop.settings.content") {
                Picker("ui.settings.content.album_region", selection: $settings.musicArea) {
                    Text("ui.category.all").tag("ALL")
                    Text("ui.category.chinese").tag("ZH")
                    Text("ui.category.europe_america").tag("EA")
                    Text("ui.category.korean").tag("KR")
                    Text("ui.category.japanese").tag("JP")
                }
            }

            Section("ui.recognition.title") {
                Picker("ui.desktop.recognition.source", selection: $recognition.audioSource) {
                    ForEach(SongRecognitionAudioSource.allCases) { source in
                        Label(source.title, systemImage: source.systemImage).tag(source)
                    }
                }
                Text(recognition.audioSource.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("ui.settings.content.recognition_duration", selection: $recognition.duration) {
                    ForEach(SongRecognitionDuration.allCases) { duration in
                        Text(
                            L10n.joined(
                                [duration.title, duration.detail],
                                separatorKey:
                                    "ui.common.metadata_separator"
                            )
                        )
                        .tag(duration)
                    }
                }
            }

            Section("ui.desktop.settings.account") {
                HStack(spacing: 12) {
                    DesktopArtworkView(
                        url: model.library.profile?.artworkURL,
                        cornerRadius: 999
                    )
                    .frame(width: 42, height: 42)
                    .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.library.profile?.nickname ?? L10n.string("ui.account.not_signed_in"))
                            .font(.headline)
                        Text(
                            model.library.isLoggedIn
                                ? L10n.string("ui.desktop.settings.account.synced")
                                : L10n.string("ui.desktop.settings.account.sign_in_message")
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(
                        model.library.isLoggedIn
                            ? L10n.string("ui.desktop.settings.account.details")
                            : L10n.string("ui.common.login")
                    ) {
                        model.ui.sheet = model.library.isLoggedIn ? .account : .login
                    }
                }
            }

            Section("ui.desktop.settings.launch") {
                Toggle("ui.about.check_updates_on_launch", isOn: $settings.checksUpdatesOnLaunch)
                Toggle("ui.desktop.settings.launch.clipboard", isOn: $settings.recognizesClipboardLinksOnLaunch)
                Toggle("ui.settings.general.search_suggestions", isOn: $settings.searchSuggestionsEnabled)
                Toggle("ui.settings.playback.start_heart_mode", isOn: $settings.startsHeartModeOnLaunch)
            }
        }
        .formStyle(.columns)
        .padding()
        .onChange(of: settings.musicArea) { _, _ in
            Task {
                await model.home.load(force: true)
            }
        }
    }
}

private struct DesktopPlaybackSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        @Bindable var equalizer = model.settings.equalizer
        @Bindable var autoMix = model.settings.autoMix

        ScrollView {
            Form {
            Section("ui.desktop.settings.quality_controls") {
                Picker("ui.player.playback_quality", selection: qualityBinding) {
                    ForEach(MusicQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
                Picker("ui.settings.playback.volume_control", selection: $settings.playerVolumeControlMode) {
                    ForEach(PlayerVolumeControlMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Toggle("ui.settings.playback.previous_restarts", isOn: $settings.previousRestartsCurrentSong)
            }

            Section("ui.desktop.settings.spatial_audio") {
                Picker("ui.desktop.settings.mode", selection: $settings.spatialAudioMode) {
                    ForEach(SpatialAudioMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text(settings.spatialAudioMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("ui.desktop.settings.spatial_audio.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("ui.player.now_playing") {
                Picker("ui.settings.player_appearance.background_style", selection: $settings.playerBackgroundStyle) {
                    ForEach(PlayerBackgroundStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                Slider(
                    value: $settings.playerBackgroundMotionIntensity,
                    in: AppSettings.playerBackgroundMotionIntensityRange,
                    step: 0.1,
                    label: { Text("ui.desktop.settings.background_motion") },
                    minimumValueLabel: { Text("ui.desktop.settings.motion.still") },
                    maximumValueLabel: { Text("ui.desktop.settings.motion.strong") }
                )
                if settings.playerBackgroundStyle == .flowingLight {
                    Toggle(
                        "ui.settings.player_appearance.beat_vignette",
                        isOn: $settings.playerBackgroundBeatEffectsEnabled
                    )
                }
                if settings.playerBackgroundStyle == .appleMusicBackdrop {
                    Picker(
                        "ui.desktop.settings.background_quality",
                        selection: $settings.playerBackgroundRenderQuality
                    ) {
                        ForEach(PlayerBackgroundRenderQuality.allCases) { quality in
                            Text(quality.title).tag(quality)
                        }
                    }
                    Text(settings.playerBackgroundRenderQuality.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(
                        "ui.desktop.settings.apple_music_backdrop.footer"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Toggle("ui.settings.player_appearance.shrink_paused_artwork", isOn: $settings.shrinksPausedArtwork)
                Toggle("ui.settings.playback.remember_page", isOn: $settings.rememberNowPlayingPage)
                Text(
                    settings.rememberNowPlayingPage
                        ? L10n.string("ui.desktop.settings.remember_page.enabled")
                        : L10n.string("ui.desktop.settings.remember_page.disabled")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Picker("ui.settings.player_appearance.screen_awake", selection: $settings.playerScreenAwakeMode) {
                    ForEach(
                        PlayerScreenAwakeMode.allCases.filter {
                            $0 != .hiddenLyricsInterface
                        }
                    ) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("ui.settings.equalizer.title") {
                Toggle("ui.settings.equalizer.enabled", isOn: $equalizer.isEnabled)
                Picker(
                    "ui.settings.equalizer.preset",
                    selection: Binding(
                        get: { equalizer.selectedPreset },
                        set: { equalizer.apply($0) }
                    )
                ) {
                    ForEach(AudioEqualizerPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                HStack {
                    Text("ui.settings.equalizer.preamp")
                    Slider(
                        value: Binding(
                            get: { equalizer.preamp },
                            set: { equalizer.setPreamp($0) }
                        ),
                        in: AudioEqualizerPreferences.preampRange
                    )
                    Text(
                        equalizer.preamp.formatted(
                            .number
                                .precision(.fractionLength(1))
                                .locale(L10n.locale)
                        ) + " dB"
                    )
                        .monospacedDigit()
                        .frame(width: 66, alignment: .trailing)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(AudioEqualizerBand.allCases) { band in
                            VStack(spacing: 6) {
                                Slider(
                                    value: Binding(
                                        get: { equalizer.gain(for: band) },
                                        set: { equalizer.setGain($0, for: band) }
                                    ),
                                    in: AudioEqualizerPreferences.bandGainRange
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 78, height: 90)
                                Text(band.title)
                                    .font(.caption2)
                            }
                            .frame(width: 58)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Section("ui.settings.automix.title") {
                Picker("ui.settings.automix.transition_mode", selection: $autoMix.mode) {
                    ForEach(AutoMixMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker("ui.settings.automix.transition_length", selection: $autoMix.transitionBars) {
                    ForEach(AutoMixTransitionBars.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                Picker("ui.settings.automix.previous_end_position", selection: $autoMix.tailCutBars) {
                    ForEach(AutoMixTailCutBars.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                Toggle("ui.settings.automix.match_tempo", isOn: $autoMix.tempoMatchingEnabled)
                Toggle("ui.settings.automix.skip_quiet_opening", isOn: $autoMix.skipsQuietOpening)
                Toggle("ui.settings.automix.analyze_streaming", isOn: $autoMix.analyzesStreamingTracks)
                Picker("ui.settings.automix.analysis_unavailable", selection: $autoMix.fallbackBehavior) {
                    ForEach(AutoMixFallbackBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
            }
            }
            .formStyle(.columns)
            .padding()
        }
        .scrollIndicators(.automatic)
        .onChange(of: settings.playerVolumeControlMode) { _, _ in
            model.playbackVolume.applyControlMode()
        }
        .onChange(of: settings.spatialAudioMode) { _, _ in
            model.player.applySpatialAudioSettings()
        }
        .onChange(
            of: equalizer.configuration,
            initial: true
        ) { _, _ in
            model.player.applyEqualizerSettings()
        }
        .onChange(of: autoMix.configuration) { _, _ in
            model.player.applyAutoMixSettings()
        }
    }

    private var qualityBinding: Binding<MusicQuality> {
        Binding(
            get: { model.settings.quality },
            set: { model.player.selectPlaybackQuality($0) }
        )
    }
}

private struct DesktopFileSettingsView: View {
    @Environment(DesktopAppModel.self) private var model
    @State private var usage = ManagedStorageUsage.empty
    @State private var isWorking = false
    @State private var statusMessage: String?

    var body: some View {
        @Bindable var settings = model.settings

        Form {
            Section("ui.settings.storage.title") {
                LabeledContent("ui.settings.storage.downloads_cache") { Text(bytes(usage.downloadsBytes)) }
                LabeledContent("ui.settings.storage.network_cache") { Text(bytes(usage.networkCacheBytes)) }
                LabeledContent("ui.settings.storage.temporary_files") { Text(bytes(usage.temporaryFilesBytes)) }
                LabeledContent("ui.settings.storage.database") { Text(bytes(usage.databaseBytes)) }
                LabeledContent("ui.settings.storage.managed_content") {
                    Text(bytes(usage.totalManagedBytes)).fontWeight(.semibold)
                }
            }

            Section("ui.common.download") {
                LabeledContent("ui.desktop.settings.downloaded_songs") {
                    Text(model.downloads.downloads.count.formatted(.number.locale(L10n.locale)))
                }
                LabeledContent("ui.desktop.settings.download_directory") {
                    Text(AppStorageLocations.downloadsDirectory().path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Button("ui.desktop.settings.show_in_finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([
                        AppStorageLocations.downloadsDirectory()
                    ])
                }
                Button("ui.settings.storage.repair_downloads") {
                    _ = model.downloads.repairStorage()
                    Task { await refreshUsage() }
                }
            }

            Section("ui.desktop.settings.automatic_cache") {
                Toggle("ui.desktop.settings.automatic_cache.enabled", isOn: $settings.automaticallyCachesFrequentlyPlayedSongs)
                Picker(
                    "ui.desktop.settings.automatic_cache.threshold",
                    selection: $settings.automaticCachePlaybackThreshold
                ) {
                    ForEach(
                        AppSettings.automaticCachePlaybackThresholdOptions,
                        id: \.self
                    ) { count in
                        Text(L10n.format("ui.desktop.settings.automatic_cache.after_plays", count)).tag(count)
                    }
                }
                Picker("ui.desktop.settings.automatic_cache.quality", selection: $settings.automaticCacheQuality) {
                    ForEach(MusicQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
            }

            Section("ui.desktop.settings.cleanup") {
                Button("ui.settings.storage.clear_network_cache") {
                    StorageMaintenance.clearNetworkAndArtworkCaches()
                    Task { await refreshUsage() }
                }
                Button("ui.settings.storage.clear_temporary_files") {
                    Task { await clearTemporaryFiles() }
                }
                .disabled(isWorking)
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.columns)
        .padding()
        .task { await refreshUsage() }
    }

    private func refreshUsage() async {
        usage = await StorageMaintenance.usage()
    }

    private func clearTemporaryFiles() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let reclaimed = try await StorageMaintenance.clearTemporaryFiles(
                preservingDownloadTransfers: !model.downloads.activeDownloads.isEmpty
            )
            statusMessage = L10n.format("ui.settings.storage.operation.cleared_approximately", bytes(reclaimed))
            await refreshUsage()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func bytes(_ value: Int64) -> String {
        L10n.byteCount(value)
    }
}

private struct DesktopAdvancedSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        Form {
            Section("ui.settings.system_lyrics.now_playing.section") {
                Toggle("ui.settings.system_lyrics.enabled", isOn: $settings.systemNowPlayingLyricsEnabled)
                TextField("ui.settings.system_lyrics.title_format", text: $settings.systemNowPlayingLyricsTitleFormat)
                TextField("ui.settings.system_lyrics.subtitle_format", text: $settings.systemNowPlayingLyricsSubtitleFormat)
            }

            Section("ui.desktop.settings.player_debug") {
                Toggle("ui.settings.developer.beatnet_panel", isOn: $settings.beatNetDebugEnabled)
                Slider(
                    value: $settings.playerBackgroundBlur,
                    in: AppSettings.playerBackgroundBlurRange,
                    step: 5,
                    label: { Text("ui.settings.player_appearance.blur") }
                )
                Slider(
                    value: $settings.playerBackgroundSaturation,
                    in: AppSettings.playerBackgroundSaturationRange,
                    step: 0.05,
                    label: { Text("ui.settings.player_appearance.saturation") }
                )
            }

            Section("ui.desktop.settings.maintenance") {
                Button("ui.desktop.settings.show_onboarding_again") {
                    settings.hasCompletedOnboarding = false
                    model.ui.sheet = .onboarding
                }
                Button("ui.settings.storage.optimize_database") {
                    model.downloads.optimizeStorageDatabase()
                }
                Button("ui.settings.storage.reset_cache_history") {
                    model.downloads.resetAutomaticCacheHistory()
                }
                Button("ui.desktop.settings.refresh_all_content") {
                    Task { await model.refreshAll() }
                }
            }

            Section("ui.desktop.settings.privacy") {
                Text("ui.desktop.settings.privacy.message")
                    .foregroundStyle(.secondary)
                if model.library.isLoggedIn {
                    Button("ui.settings.account.logout", role: .destructive) {
                        model.logOut()
                        Task { await DesktopNeteaseCookieStore.clear() }
                    }
                }
            }
        }
        .formStyle(.columns)
        .padding()
        .onChange(of: settings.systemNowPlayingLyricsEnabled) { _, _ in
            model.player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.systemNowPlayingLyricsTitleFormat) { _, _ in
            model.player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.systemNowPlayingLyricsSubtitleFormat) { _, _ in
            model.player.applySystemNowPlayingLyricsPreference()
        }
    }
}
