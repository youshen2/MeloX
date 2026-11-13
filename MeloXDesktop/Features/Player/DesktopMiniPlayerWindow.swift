import AppKit
import SwiftUI

private extension Color {
    init(playerForegroundFrom backgroundRGB: SIMD3<Double>) {
        let rgb = SIMD3<Double>(repeating: 1) * 0.88
            + backgroundRGB * 0.12
        self.init(red: rgb.x, green: rgb.y, blue: rgb.z)
    }
}

struct DesktopMiniPlayerWindow: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("desktop.miniPlayer.showsLargeArtwork")
    private var showsLargeArtwork = false
    @State private var isHovered = false
    @State private var expandedPanel: DesktopInspector?
    @State private var isVolumePresented = false
    @State private var isVolumeSliderHovered = false
    @State private var artworkPalette = ArtworkDetailPalette.fallback(
        prefersDarkAppearance: true
    )

    private var artworkURL: URL? {
        model.player.currentSong?.album?.artworkURL
    }

    private var artworkInfluencedForeground: Color {
        Color(playerForegroundFrom: artworkPalette.backgroundRGB)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsLargeArtwork {
                largeArtworkPlayer
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                compactPlayer
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }

            if let expandedPanel {
                Group {
                    switch expandedPanel {
                    case .lyrics:
                        DesktopPlaybackPositionedLyricsView(compact: true)
                    case .queue:
                        DesktopQueueView(presentation: .miniPlayer)
                    }
                }
                .frame(width: 320, height: 600)
                .environment(
                    \.colorScheme,
                    expandedPanelColorScheme
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 320)
        .background {
            if showsLargeArtwork, expandedPanel != nil {
                ZStack {
                    Color(
                        red: artworkPalette.backgroundRGB.x,
                        green: artworkPalette.backgroundRGB.y,
                        blue: artworkPalette.backgroundRGB.z
                    )
                    LinearGradient(
                        colors: [
                            .white.opacity(0.09),
                            .clear,
                            .black.opacity(0.025),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .clipShape(.rect(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.primary.opacity(0.13), lineWidth: 0.55)
                .allowsHitTesting(false)
        }
        .background {
            DesktopMiniPlayerWindowConfiguration()
                .allowsHitTesting(false)
        }
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.32),
            value: expandedPanel
        )
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.36),
            value: showsLargeArtwork
        )
        .task(id: artworkURL) {
            artworkPalette = await ArtworkAccentColorProvider.shared
                .detailPalette(
                    for: artworkURL,
                    fallbackPrefersDarkAppearance: true
                )
        }
        .onChange(of: model.settings.playerVolumeControlMode) { _, mode in
            if mode == .hidden {
                isVolumePresented = false
            }
        }
    }

    private var compactPlayer: some View {
        VStack(spacing: 0) {
            miniTopRegion
                .frame(height: 64)

            DesktopMiniPlayerProgress()
                .padding(.horizontal, 15)
                .frame(height: 30)
                .offset(y: 2)

            DesktopPlaybackControls(
                prominent: true,
                prominentEdgeInset: 20
            )
            .frame(width: 320, height: 51)
            .offset(y: -5)
        }
    }

    private var expandedPanelColorScheme: ColorScheme {
        guard showsLargeArtwork else { return colorScheme }
        return artworkPalette.prefersDarkAppearance ? .dark : .light
    }

    private var largeArtworkPlayer: some View {
        ZStack {
            largeArtworkBackground

            VStack(spacing: 0) {
                Group {
                    if isHovered {
                        largeArtworkToolbar
                            .transition(.opacity)
                    } else {
                        Color.clear
                            .contentShape(.rect)
                            .gesture(WindowDragGesture())
                    }
                }
                .frame(height: 64)

                Color.clear
                    .contentShape(.rect)
                    .gesture(WindowDragGesture())

                largeArtworkMetadata
                    .frame(height: 64)

                DesktopMiniPlayerProgress(
                    tint: artworkInfluencedForeground,
                    timeOpacity: 0.82
                )
                    .padding(.horizontal, 16)
                    .frame(height: 45)
                    .offset(y: -8)

                DesktopPlaybackControls(
                    prominent: true,
                    tint: .white,
                    prominentEdgeInset: 20,
                    secondaryTintOpacity: 0.76
                )
                .frame(width: 320, height: 51)
                .offset(y: -7)
            }
        }
        .frame(width: 320, height: 320)
    }

    @ViewBuilder
    private var largeArtworkBackground: some View {
        if model.player.currentSong != nil {
            DesktopArtworkView(
                url: model.player.currentSong?.album?.artworkURL,
                cornerRadius: 0
            )
            .frame(width: 320, height: 320)

            DesktopArtworkView(
                url: model.player.currentSong?.album?.artworkURL,
                cornerRadius: 0
            )
            .frame(width: 320, height: 320)
            .scaleEffect(1.14)
            .blur(radius: 18)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.12),
                        .init(color: .black.opacity(0.24), location: 0.24),
                        .init(color: .black, location: 0.42),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.22),
                    .init(color: .black.opacity(0.08), location: 0.48),
                    .init(color: .black.opacity(0.42), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Rectangle()
                .fill(.regularMaterial)
            Image(systemName: "apple.logo")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var miniTopRegion: some View {
        ZStack {
            if isHovered {
                miniToolbar
                    .transition(.opacity)
            } else {
                miniMetadata
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var miniMetadata: some View {
        if model.player.currentSong != nil {
            HStack(spacing: 11) {
                DesktopArtworkView(
                    url: model.player.currentSong?.album?.artworkURL,
                    cornerRadius: 6
                )
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.player.currentSong?.name ?? L10n.string("ui.desktop.player.not_playing"))
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text(
                        [
                            model.player.currentSong?.artistText,
                            model.player.currentSong?.album?.name,
                        ]
                        .compactMap { $0 }
                        .joined(
                            separator: L10n.string(
                                "ui.common.title_detail_separator"
                            )
                        )
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15)
            .padding(.top, 8)
            .gesture(WindowDragGesture())
            .accessibilityHint("ui.desktop.mini_player.drag_hint")
        } else {
            Image(systemName: "apple.logo")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(WindowDragGesture())
                .accessibilityLabel("ui.desktop.player.not_playing")
                .accessibilityHint("ui.desktop.mini_player.drag_hint")
        }
    }

    private var miniToolbar: some View {
        HStack(spacing: 0) {
            miniWindowButtons

            if isVolumePresented, model.playbackVolume.isControlVisible {
                miniFlexibleDragRegion

                miniExpandedVolumeControl
                    .transition(.move(edge: .trailing).combined(with: .opacity))

                Spacer().frame(width: 8)
            } else {
                if model.playbackVolume.isControlVisible {
                    miniFixedDragRegion(width: 44)
                } else {
                    miniFlexibleDragRegion
                }

                miniMoreMenu

                Spacer().frame(width: 18)

                miniInspectorButtons

                if model.playbackVolume.isControlVisible {
                    Spacer().frame(width: 9)

                    miniVolumeButton
                }
                Spacer().frame(width: 8)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .frame(width: 320, height: 64, alignment: .top)
    }

    private var largeArtworkToolbar: some View {
        HStack(spacing: 0) {
            miniWindowButtons

            if isVolumePresented, model.playbackVolume.isControlVisible {
                miniFlexibleDragRegion

                miniExpandedVolumeControl
                    .transition(.move(edge: .trailing).combined(with: .opacity))

                Spacer().frame(width: 8)
            } else {
                miniFlexibleDragRegion

                miniInspectorButtons

                if model.playbackVolume.isControlVisible {
                    Spacer().frame(width: 9)

                    miniVolumeButton
                }
                Spacer().frame(width: 8)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .frame(width: 320, height: 64, alignment: .top)
    }

    @ViewBuilder
    private var miniInspectorButtons: some View {
        if #available(macOS 26.0, *) {
            miniInspectorButtonsContent
                .glassEffect(.regular.interactive(), in: .capsule)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        } else {
            miniInspectorButtonsContent
                .background(.ultraThinMaterial, in: .capsule)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        }
    }

    private var miniInspectorButtonsContent: some View {
        HStack(spacing: 0) {
            toolbarButton(.lyrics, systemImage: "quote.bubble")
            toolbarButton(.queue, systemImage: "list.bullet")
        }
        .frame(width: 74, height: 36)
    }

    @ViewBuilder
    private var miniVolumeButton: some View {
        if #available(macOS 26.0, *) {
            miniVolumeButtonContent
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        } else {
            miniVolumeButtonContent
                .background(
                    .ultraThinMaterial,
                    in: .rect(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        }
    }

    private var miniVolumeButtonContent: some View {
        Button {
            isVolumePresented = true
        } label: {
            Image(systemName: miniVolumeSymbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 36)
                .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var miniExpandedVolumeControl: some View {
        if #available(macOS 26.0, *) {
            miniExpandedVolumeControlContent
                .glassEffect(.regular.interactive(), in: .capsule)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        } else {
            miniExpandedVolumeControlContent
                .background(.ultraThinMaterial, in: .capsule)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        }
    }

    private var miniExpandedVolumeControlContent: some View {
        HStack(spacing: 10) {
            Group {
                if #available(macOS 26.0, *) {
                    miniVolumeSlider
                        .sliderThumbVisibility(
                            isVolumeSliderHovered ? .visible : .hidden
                        )
                } else {
                    miniVolumeSlider
                }
            }
            .onHover { isVolumeSliderHovered = $0 }

            Button {
                withAnimation(
                    reduceMotion
                        ? nil
                        : .snappy(duration: 0.26, extraBounce: 0.035)
                ) {
                    isVolumePresented = false
                }
            } label: {
                Image(systemName: miniVolumeSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help(L10n.string("ui.desktop.player.collapse_volume"))
        }
        .padding(.horizontal, 14)
        .frame(width: 154, height: 36)
        .contentShape(.capsule)
    }

    private var miniVolumeSlider: some View {
        Slider(
            value: Binding(
                get: { model.playbackVolume.volume },
                set: { model.playbackVolume.setVolume($0) }
            ),
            in: 0...1
        )
        .tint(.primary)
        .controlSize(.large)
        .frame(width: 96)
        .accessibilityLabel("ui.player.volume")
    }

    private var largeArtworkMetadata: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.player.currentSong?.name ?? L10n.string("ui.desktop.player.not_playing"))
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                Text(
                    [
                        model.player.currentSong?.artistText,
                        model.player.currentSong?.album?.name,
                    ]
                    .compactMap { $0 }
                    .joined(
                        separator: L10n.string(
                            "ui.common.title_detail_separator"
                        )
                    )
                )
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .gesture(WindowDragGesture())

            HStack(spacing: 8) {
                largeArtworkFavoriteButton

                largeArtworkMoreMenu
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
    }

    private var largeArtworkFavoriteButton: some View {
        largeArtworkFavoriteButtonContent
            .background(.white.opacity(0.20), in: .circle)
    }

    private var largeArtworkFavoriteButtonContent: some View {
        Button {
            guard let song = model.player.currentSong else { return }
            model.library.toggle(song: song)
        } label: {
            Image(
                systemName: model.player.currentSong.map {
                    model.library.contains(song: $0)
                } == true ? "star.fill" : "star"
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(
            model.player.currentSong.map {
                model.library.contains(song: $0)
            } == true
                ? L10n.string("ui.song.unlike")
                : L10n.string("ui.song.like")
        )
    }

    private var largeArtworkMoreMenu: some View {
        largeArtworkMoreMenuContent
            .background(.white.opacity(0.20), in: .circle)
    }

    private var largeArtworkMoreMenuContent: some View {
        Menu {
            miniPlayerMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .symbolRenderingMode(.palette)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white, Color.white)
                .frame(width: 26, height: 26)
                .contentShape(.circle)
        }
        .menuStyle(.borderlessButton)
        .tint(.white)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 26, height: 26)
    }

    private var miniMoreMenu: some View {
        Group {
            if #available(macOS 26.0, *) {
                miniMoreMenuContent
                    .glassEffect(.regular.interactive(), in: .circle)
            } else {
                miniMoreMenuContent
                    .background(.ultraThinMaterial, in: .circle)
            }
        }
        .frame(width: 36, height: 36)
        .contentShape(.circle)
        .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
    }

    private var miniMoreMenuContent: some View {
        Menu {
            miniPlayerMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .contentShape(.circle)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 36, height: 36)
        .help(L10n.string("ui.common.more"))
        .accessibilityLabel("ui.common.more")
    }

    @ViewBuilder
    private var miniPlayerMenuItems: some View {
        Picker(
            "ui.settings.lyrics.content.default_source",
            selection: Binding(
                get: { model.settings.lyricsSourcePreference },
                set: { model.settings.lyricsSourcePreference = $0 }
            )
        ) {
            ForEach(LyricSourcePreference.allCases) { preference in
                Text(preference.title).tag(preference)
            }
        }

        Divider()

        DesktopPlaybackQualityMenu(model: model)

        Button(
            showsLargeArtwork
                ? L10n.string("ui.desktop.mini_player.hide_large_artwork")
                : L10n.string("ui.desktop.mini_player.show_large_artwork"),
            systemImage: showsLargeArtwork ? "photo.fill" : "photo"
        ) {
            expandedPanel = nil
            showsLargeArtwork.toggle()
        }

        Divider()

        Button("ui.desktop.mini_player.open_full_player", systemImage: "arrow.up.left.and.arrow.down.right") {
            dismissWindow(id: "mini-player")
            Task { @MainActor in
                await Task.yield()
                model.ui.isNowPlayingPresented = true
                NSApp.activate(ignoringOtherApps: true)
                let mainWindow = NSApp.windows.first {
                    $0.frame.width >= 980
                }
                mainWindow?.makeKeyAndOrderFront(nil)
            }
        }
        Button("ui.floating_lyrics.title", systemImage: "text.quote") {
            DesktopFloatingLyricsPanelController.shared.show(model: model) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
        }
    }

    private var miniWindowButtons: some View {
        HStack(spacing: 9) {
            miniWindowButton(
                color: Color(red: 1, green: 0.37, blue: 0.34),
                help: L10n.string("ui.desktop.mini_player.close")
            ) {
                dismissWindow(id: "mini-player")
            }
            miniWindowButton(
                color: Color(red: 1, green: 0.74, blue: 0.18),
                help: L10n.string("ui.desktop.window.minimize")
            ) {
                NSApp.keyWindow?.miniaturize(nil)
            }
            miniWindowButton(
                color: Color(red: 0.15, green: 0.78, blue: 0.33),
                help: L10n.string("ui.desktop.window.zoom")
            ) {
                NSApp.keyWindow?.zoom(nil)
            }
        }
        .padding(.leading, 19)
        .frame(width: 87, height: 36, alignment: .leading)
    }

    private func miniWindowButton(
        color: Color,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .overlay {
                    Circle().stroke(.black.opacity(0.18), lineWidth: 0.5)
                }
                .frame(width: 14, height: 14)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var miniFlexibleDragRegion: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: 36)
            .contentShape(.rect)
            .gesture(WindowDragGesture())
            .accessibilityHidden(true)
    }

    private func miniFixedDragRegion(width: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: 36)
            .contentShape(.rect)
            .gesture(WindowDragGesture())
            .accessibilityHidden(true)
    }

    private func toolbarButton(
        _ destination: DesktopInspector,
        systemImage: String
    ) -> some View {
        let isSelected = expandedPanel == destination

        return Button {
            expandedPanel = isSelected ? nil : destination
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 37, height: 36)
                .background(
                    isSelected ? Color.red : Color.clear,
                    in: .circle
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            isSelected
                ? L10n.string("ui.common.selected")
                : L10n.string("ui.common.not_selected")
        )
    }

    private var miniVolumeSymbol: String {
        switch model.playbackVolume.volume {
        case ...0.001: "speaker.slash.fill"
        case ..<0.35: "speaker.wave.1.fill"
        case ..<0.7: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }
}

private struct DesktopMiniPlayerProgress: View {
    @Environment(DesktopAppModel.self) private var model
    @State private var isSliderHovered = false
    var tint: Color = .primary
    var timeOpacity = 0.68

    var body: some View {
        VStack(spacing: 0) {
            hoverAwareProgressSlider

            HStack {
                Text(format(model.player.progress))
                Spacer()
                Text("−\(format(max(model.player.duration - model.player.progress, 0)))")
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(tint.opacity(timeOpacity))
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var hoverAwareProgressSlider: some View {
        if #available(macOS 26.0, *) {
            progressSlider
                .sliderThumbVisibility(
                    isSliderHovered ? .visible : .hidden
                )
                .onHover { isSliderHovered = $0 }
        } else {
            progressSlider
        }
    }

    private var progressSlider: some View {
        Slider(
            value: Binding(
                get: {
                    min(
                        model.player.progress,
                        max(model.player.duration, 0)
                    )
                },
                set: { model.player.seek(to: $0) }
            ),
            in: 0...max(model.player.duration, 1)
        )
        .tint(tint)
        .controlSize(.small)
        .accessibilityLabel("ui.desktop.player.playback_progress")
        .frame(height: 14)
    }

    private func format(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }
        let seconds = max(Int(time), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
