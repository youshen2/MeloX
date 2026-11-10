import SwiftUI

struct DesktopNowPlayingBackdrop: View {
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion

    let artworkURL: URL?
    let player: PlayerStore
    let settings: AppSettings
    let isActive: Bool

    @State private var flowingLightPalette:
        ArtworkFlowingLightPalette

    init(
        artworkURL: URL?,
        player: PlayerStore,
        settings: AppSettings,
        isActive: Bool
    ) {
        self.artworkURL = artworkURL
        self.player = player
        self.settings = settings
        self.isActive = isActive
        _flowingLightPalette = State(
            initialValue:
                ArtworkAccentColorProvider
                    .cachedDetailAssets(
                        for: artworkURL
                    )?
                    .flowingLightPalette
                    ?? .fallback
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                backgroundContent(in: proxy.size)
                    .transition(.opacity)

                Color.black.opacity(backgroundVeilOpacity)

                LinearGradient(
                    stops: settings.playerBackgroundStyle == .blurredArtwork
                        ? [.init(color: .black.opacity(0.04), location: 0),
                           .init(color: .black.opacity(0.10), location: 0.52),
                           .init(color: .black.opacity(0.48), location: 1)]
                        : legibilityGradientColors.enumerated().map { index, color in
                            .init(color: color, location: Double(index) / Double(legibilityGradientColors.count - 1))
                        },
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
            .brightness(settings.playerBackgroundBrightness)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .animation(
            accessibilityReduceMotion
                ? nil
                : .easeInOut(duration: 0.55),
            value: settings.playerBackgroundStyle
        )
        .task(id: paletteTaskID) {
            await loadFlowingLightPalette()
        }
        .task(id: beatAnalysisTaskID) {
            await loadBeatTimeline()
        }
    }

    @ViewBuilder
    private func backgroundContent(
        in size: CGSize
    ) -> some View {
        switch settings.playerBackgroundStyle {
        case .appleMusicBackdrop:
            DesktopAppleMusicBackdropView(
                artworkURL: artworkURL,
                motionIntensity:
                    settings.playerBackgroundMotionIntensity,
                renderQuality:
                    settings.playerBackgroundRenderQuality,
                isActive: isActive,
                isPlaying: player.isPlaying
            )
            .frame(width: size.width, height: size.height)

        case .flowingLight:
            DesktopNowPlayingFlowingLightBackground(
                player: player,
                palette: flowingLightPalette,
                beatTimeline: player.currentBeatTimeline,
                motionIntensity:
                    settings.playerBackgroundMotionIntensity,
                saturation:
                    settings.playerBackgroundSaturation,
                beatEffectsEnabled:
                    settings
                        .playerBackgroundBeatEffectsEnabled,
                isActive: isActive
            )
            .frame(
                width: size.width,
                height: size.height
            )

        case .blurredArtwork:
            DesktopBlurredArtworkBackground(
                artworkURL: artworkURL,
                size: size,
                blurRadius: settings.playerBackgroundBlur,
                saturation: settings.playerBackgroundSaturation,
                motionIntensity: settings.playerBackgroundMotionIntensity,
                isActive: isActive,
                isPlaying: player.isPlaying
            )
        }
    }

    private var backgroundVeilOpacity: Double {
        switch settings.playerBackgroundStyle {
        case .appleMusicBackdrop:
            0
        case .flowingLight:
            0.02
        case .blurredArtwork:
            0
        }
    }

    private var legibilityGradientColors: [Color] {
        switch settings.playerBackgroundStyle {
        case .appleMusicBackdrop:
            [.clear, .clear]
        case .flowingLight:
            [
                .black.opacity(0.015),
                .black.opacity(0.05),
                .black.opacity(0.36),
            ]
        case .blurredArtwork:
            [
                .black.opacity(0.04),
                .black.opacity(0.12),
                .black.opacity(0.48),
            ]
        }
    }

    private var paletteTaskID:
        DesktopNowPlayingBackgroundPaletteTaskID {
        DesktopNowPlayingBackgroundPaletteTaskID(
            artworkURL: artworkURL,
            usesFlowingLight:
                settings.playerBackgroundStyle
                    == .flowingLight
        )
    }

    private var beatAnalysisTaskID:
        DesktopNowPlayingBeatAnalysisTaskID {
        DesktopNowPlayingBeatAnalysisTaskID(
            songID: player.currentSong?.id,
            isPlaybackReady: !player.isLoading,
            isEnabled:
                settings.playerBackgroundStyle == .flowingLight
                    && settings.playerBackgroundBeatEffectsEnabled
                    && player.currentSong?.isPodcastProgram != true
        )
    }

    private func loadBeatTimeline() async {
        let taskID = beatAnalysisTaskID
        guard taskID.isEnabled else {
            player.clearCurrentSongBeatAnalysis()
            return
        }
        guard taskID.isPlaybackReady,
              taskID.songID != nil else {
            return
        }
        await player.analyzeCurrentSongBeats()
    }

    private func loadFlowingLightPalette() async {
        guard settings.playerBackgroundStyle
            == .flowingLight else {
            return
        }
        let assets =
            await ArtworkAccentColorProvider
                .shared
                .detailAssets(
                    for: artworkURL,
                    fallbackPrefersDarkAppearance: true
                )
        guard !Task.isCancelled,
              assets.flowingLightPalette
                != flowingLightPalette else {
            return
        }
        withAnimation(
            accessibilityReduceMotion
                ? nil
                : .easeInOut(duration: 0.8)
        ) {
            flowingLightPalette =
                assets.flowingLightPalette
        }
    }
}

private struct DesktopNowPlayingBackgroundPaletteTaskID:
    Equatable {
    let artworkURL: URL?
    let usesFlowingLight: Bool
}

private struct DesktopNowPlayingBeatAnalysisTaskID: Equatable {
    let songID: Int?
    let isPlaybackReady: Bool
    let isEnabled: Bool
}

/// Android original nine-color flowing field, evaluated directly on the GPU.
private struct DesktopBlurredArtworkBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var clock = DesktopBlurredArtworkClock()
    @State private var previousPalette = DesktopAndroidFlowPalette.fallback
    @State private var targetPalette = DesktopAndroidFlowPalette.fallback
    @State private var paletteChangedAt = Date.distantPast
    @State private var isPaletteSettling = false
    private let motion = DesktopBlurredArtworkMotion()

    let artworkURL: URL?
    let size: CGSize
    let blurRadius: Double
    let saturation: Double
    let motionIntensity: Double
    let isActive: Bool
    let isPlaying: Bool

    private var strength: Double { reduceMotion ? 0 : min(max(motionIntensity, 0), 1.4) }
    private var isClockRunning: Bool {
        isActive && isPlaying && scenePhase == .active && strength > 0
    }
    private func palette(at date: Date) -> DesktopAndroidFlowPalette {
        previousPalette.blended(to: targetPalette,
            amount: 1 - exp(-max(date.timeIntervalSince(paletteChangedAt), 0) / 0.28))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: !isClockRunning && !isPaletteSettling)) { context in
            let phase = clock.elapsed(at: context.date).truncatingRemainder(dividingBy: 8 * .pi)
            let uniforms = palette(at: context.date).values + motion.centers(at: phase)
            Color.white.colorEffect(ShaderLibrary.desktopBlurredArtworkFlow(
                .float2(size), .float(Float(phase)), .floatArray(uniforms),
                .float(Float(saturation / AppSettings.defaultPlayerBackgroundSaturation)),
                .float(Float(max(blurRadius / 90 * 0.45, 0.01)))
            ))
        }
        .frame(width: size.width, height: size.height)
        .task(id: artworkURL) {
            let loaded = await DesktopAndroidFlowPaletteStore.shared.palette(for: artworkURL)
            guard !Task.isCancelled else { return }
            let now = Date()
            previousPalette = palette(at: now)
            targetPalette = loaded
            paletteChangedAt = now
            isPaletteSettling = true
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            isPaletteSettling = false
        }
        .onChange(of: isClockRunning, initial: true) { _, running in
            clock.setRate(running ? motion.speed(for: strength) : 0, at: Date())
        }
        .onChange(of: strength) { _, value in
            clock.setRate(isClockRunning ? motion.speed(for: value) : 0, at: Date())
        }
    }
}
