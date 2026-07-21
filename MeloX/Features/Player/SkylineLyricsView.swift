import SwiftUI

struct SkylineLyricsView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var accessibilityVoiceOverEnabled
    @Environment(AppSettings.self) private var settings

    let artworkURL: URL?
    let lyrics: [LyricLine]
    let errorMessage: String?
    let highlightedLyricID: LyricLine.ID?
    let onExit: () -> Void

    @State private var controlsAreVisible = true
    @State private var controlsGeneration = 0
    @State private var accentRGB = ArtworkAccentColorProvider.fallback

    var body: some View {
        GeometryReader { proxy in
            let activeIndex = activeLyricIndex

            ZStack {
                skylineBackground

                if let activeIndex {
                    SkylineAmbientLyricsView(
                        line: lyrics[activeIndex],
                        size: proxy.size,
                        accentColor: accentColor,
                        baseFontSize: CGFloat(settings.skylineLyrics.ambientFontSize),
                        maximumCharacters: settings.skylineLyrics.ambientMaximumCharacters,
                        maximumVisibleTexts: settings.skylineLyrics.ambientMaximumVisibleTexts,
                        opacityScale: settings.skylineLyrics.ambientOpacity,
                        blurScale: CGFloat(settings.skylineLyrics.ambientBlur),
                        maximumTilt: settings.skylineLyrics.ambientMaximumTilt,
                        driftScale: CGFloat(settings.skylineLyrics.ambientDrift),
                        transitionDuration: ambientTransitionDuration(
                            at: activeIndex
                        )
                    )

                    currentLyrics(
                        at: activeIndex,
                        in: proxy.size
                    )
                } else {
                    unavailableContent
                }

                exitControl
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(.rect)
            .clipped()
            .onTapGesture {
                toggleControls()
            }
            .accessibilityAction(named: "返回普通歌词") {
                onExit()
            }
        }
        .ignoresSafeArea()
        .keepsScreenAwake(settings.skylineLyrics.keepsScreenAwake)
        .onAppear {
            scheduleControlsToHide()
        }
        .task(id: artworkURL) {
            let sampledColor = await ArtworkAccentColorProvider.shared.accentColor(
                for: artworkURL
            )
            guard !Task.isCancelled else { return }
            withAnimation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.8)) {
                accentRGB = sampledColor
            }
        }
        .onChange(of: accessibilityVoiceOverEnabled) { _, voiceOverEnabled in
            if voiceOverEnabled {
                controlsGeneration += 1
                controlsAreVisible = true
            } else {
                scheduleControlsToHide()
            }
        }
        .task(id: controlsGeneration) {
            guard controlsAreVisible, !accessibilityVoiceOverEnabled else { return }
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            withAnimation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.3)) {
                controlsAreVisible = false
            }
        }
    }

    private var skylineBackground: some View {
        ZStack {
            Color.black.opacity(0.88)

            RadialGradient(
                colors: [
                    accentColor.opacity(0.10),
                    .clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 0,
                endRadius: 420
            )
            .blendMode(.plusLighter)

            LinearGradient(
                colors: [
                    .black.opacity(0.14),
                    .clear,
                    .black.opacity(0.56),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }

    private func currentLyrics(
        at activeIndex: Int,
        in size: CGSize
    ) -> some View {
        let line = lyrics[activeIndex]
        let nextLine = lyrics.indices.contains(activeIndex + 1)
            ? lyrics[activeIndex + 1]
            : nil
        let preferences = settings.skylineLyrics
        let fontScale = CGFloat(
            preferences.currentLyricFontSize / settings.lyricsFontSize
        )
        let currentLyricsSpacing = CGFloat(preferences.currentLyricsSpacing)
        let nextLyricFontSize = CGFloat(preferences.nextLyricFontSize)
        let currentLyricsWidth = CGFloat(preferences.currentLyricsWidth)
        let hasSyllableSyncedLyrics = lyrics.contains { $0.isSyllableSynced }
        let usesPseudoTiming = settings.lyricsPseudoWordByWord
            && !hasSyllableSyncedLyrics

        return SkylineCentralLyricsView(
            line: line,
            nextLine: nextLine,
            usesPseudoTiming: usesPseudoTiming,
            fontScale: fontScale,
            currentLyricFontSize: CGFloat(preferences.currentLyricFontSize),
            nextLyricFontSize: nextLyricFontSize,
            nextLyricOpacity: preferences.nextLyricOpacity,
            spacing: currentLyricsSpacing,
            width: size.width * currentLyricsWidth,
            accentColor: accentColor,
            maximumPlaybackScale: CGFloat(
                preferences.currentLyricMaximumScale
            )
        )
        .shadow(color: accentColor.opacity(0.28), radius: 10)
        .position(x: size.width * 0.5, y: size.height * 0.5)
    }

    private var accentColor: Color {
        Color(
            red: accentRGB.x,
            green: accentRGB.y,
            blue: accentRGB.z
        )
    }

    @ViewBuilder
    private var unavailableContent: some View {
        if let errorMessage {
            ContentUnavailableView(
                "暂无歌词",
                systemImage: "quote.bubble",
                description: Text(errorMessage)
            )
            .foregroundStyle(.white)
        } else {
            ProgressView("正在载入歌词")
                .tint(.white)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var exitControl: some View {
        if controlsAreVisible {
            VStack {
                HStack {
                    Spacer()

                    Button(action: onExit) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: .circle)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("返回普通歌词")
                }

                Spacer()
            }
            .safeAreaPadding(12)
            .transition(.opacity)
        }
    }

    private var activeLyricIndex: Int? {
        if let highlightedLyricID,
           let index = lyrics.firstIndex(where: { $0.id == highlightedLyricID }) {
            return index
        }
        return lyrics.indices.first
    }

    private func ambientTransitionDuration(at activeIndex: Int) -> TimeInterval {
        let followingIndex = activeIndex + 1
        let availableDuration = lyrics.indices.contains(followingIndex)
            ? lyrics[followingIndex].time - lyrics[activeIndex].time
            : lyrics[activeIndex].duration
        guard let availableDuration,
              availableDuration.isFinite,
              availableDuration > 0 else {
            return 0.82
        }
        return min(max(availableDuration * 0.65, 0.08), 0.82)
    }

    private func toggleControls() {
        withAnimation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.25)) {
            controlsAreVisible.toggle()
        }
        if controlsAreVisible {
            scheduleControlsToHide()
        } else {
            controlsGeneration += 1
        }
    }

    private func scheduleControlsToHide() {
        controlsGeneration += 1
    }

}
