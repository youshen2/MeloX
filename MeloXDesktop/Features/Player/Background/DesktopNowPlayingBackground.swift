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
                    colors: legibilityGradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
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
                isActive: isBackgroundAnimationActive,
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
                isActive: isBackgroundAnimationActive
            )
            .frame(
                width: size.width,
                height: size.height
            )

        case .blurredArtwork:
            blurredArtworkBackground(in: size)
        }
    }

    private var isBackgroundAnimationActive: Bool {
        isActive && player.isPlaybackUIActive
    }

    @ViewBuilder
    private func blurredArtworkBackground(
        in size: CGSize
    ) -> some View {
        AsyncImage(url: artworkURL) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: size.width,
                        height: size.height
                    )
                    .clipped()
                    .scaleEffect(1.35)
                    .blur(
                        radius:
                            CGFloat(
                                settings
                                    .playerBackgroundBlur
                            )
                    )
                    .saturation(
                        settings.playerBackgroundSaturation
                    )
            }
        }
    }

    private var backgroundVeilOpacity: Double {
        switch settings.playerBackgroundStyle {
        case .appleMusicBackdrop:
            0
        case .flowingLight:
            0.02
        case .blurredArtwork:
            0.10
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
