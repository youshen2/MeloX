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
    @State private var ambientFieldIsDrifting = false
    @State private var accentRGB = ArtworkAccentColorProvider.fallback

    private static let ambientSlots: [SkylineLyricSlot] = [
        .init(id: 0, x: -0.01, y: 0.14, scale: 1.24, blur: 1.8, opacity: 0.22, driftX: 12, driftY: -3),
        .init(id: 1, x: 0.08, y: 0.72, scale: 1.52, blur: 8.5, opacity: 0.25, driftX: 18, driftY: 4),
        .init(id: 2, x: 0.17, y: 0.32, scale: 1.08, blur: 1.2, opacity: 0.20, driftX: 10, driftY: -5),
        .init(id: 3, x: 0.27, y: 0.88, scale: 0.68, blur: 2.4, opacity: 0.17, driftX: 8, driftY: 2),
        .init(id: 4, x: 0.34, y: 0.60, scale: 0.58, blur: 0.8, opacity: 0.13, driftX: 6, driftY: -2),
        .init(id: 5, x: 0.43, y: 0.18, scale: 0.38, blur: 5.5, opacity: 0.12, driftX: 4, driftY: 2),
        .init(id: 6, x: 0.57, y: 0.82, scale: 0.42, blur: 4.0, opacity: 0.11, driftX: -4, driftY: -2),
        .init(id: 7, x: 0.66, y: 0.64, scale: 0.56, blur: 0.9, opacity: 0.13, driftX: -6, driftY: 3),
        .init(id: 8, x: 0.75, y: 0.35, scale: 0.78, blur: 1.6, opacity: 0.17, driftX: -8, driftY: -4),
        .init(id: 9, x: 0.83, y: 0.90, scale: 1.02, blur: 2.4, opacity: 0.20, driftX: -10, driftY: 3),
        .init(id: 10, x: 0.92, y: 0.70, scale: 1.46, blur: 8.0, opacity: 0.24, driftX: -16, driftY: -3),
        .init(id: 11, x: 1.02, y: 0.22, scale: 1.30, blur: 1.6, opacity: 0.21, driftX: -12, driftY: 4),
    ]

    var body: some View {
        GeometryReader { proxy in
            let activeIndex = activeLyricIndex
            let ambientTexts = ambientTexts(around: activeIndex)

            ZStack {
                skylineBackground

                if let activeIndex {
                    ambientField(
                        texts: ambientTexts,
                        activeIndex: activeIndex,
                        size: proxy.size
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
            .animation(
                accessibilityReduceMotion ? nil : .smooth(duration: 0.65),
                value: highlightedLyricID
            )
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
            startAmbientMotion()
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
        .onChange(of: accessibilityReduceMotion) { _, reduceMotion in
            guard reduceMotion else {
                startAmbientMotion()
                return
            }
            withAnimation(nil) {
                ambientFieldIsDrifting = false
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

    private func ambientField(
        texts: [String],
        activeIndex: Int,
        size: CGSize
    ) -> some View {
        let preferences = settings.skylineLyrics
        let baseFontSize = CGFloat(preferences.ambientFontSize)
        let blurScale = CGFloat(preferences.ambientBlur)
        let driftScale = CGFloat(preferences.ambientDrift)

        return ZStack {
            ForEach(Self.ambientSlots) { slot in
                let position = randomizedPosition(
                    for: slot,
                    activeIndex: activeIndex
                )

                Text(verbatim: texts[slot.id])
                    .font(
                        .system(
                            size: baseFontSize * slot.scale,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        accentColor.opacity(slot.opacity * preferences.ambientOpacity)
                    )
                    .blur(radius: slot.blur * blurScale)
                    .rotationEffect(
                        randomizedRotation(
                            for: slot,
                            activeIndex: activeIndex
                        )
                    )
                    .position(
                        x: size.width * position.x
                            + driftOffset(slot.driftX, scale: driftScale),
                        y: size.height * position.y
                            + driftOffset(slot.driftY, scale: driftScale)
                    )
                    .id(texts[slot.id])
                    .transition(Self.ambientTextTransition)
                    .animation(
                        accessibilityReduceMotion ? nil : .easeInOut(duration: 1.2),
                        value: texts[slot.id]
                    )
            }
        }
        .accessibilityHidden(true)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.06),
                    .init(color: .black, location: 0.92),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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

        return VStack(spacing: currentLyricsSpacing) {
            SynchronizedLyricText(
                line: line,
                isPlaybackLine: true,
                usesPseudoTiming: usesPseudoTiming,
                alignment: .center,
                fontScale: fontScale,
                primaryColor: accentColor,
                showsTranslation: false
            )

            if let nextLine {
                Text(verbatim: nextLine.text)
                    .font(
                        .system(
                            size: nextLyricFontSize,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white.opacity(preferences.nextLyricOpacity))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(width: size.width * currentLyricsWidth)
        .shadow(color: accentColor.opacity(0.28), radius: 10)
        .position(x: size.width * 0.5, y: size.height * 0.5)
        .id(line.id)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(centralLyricsAccessibilityLabel(line, nextLine: nextLine))
        .accessibilityValue("当前歌词")
    }

    private static var ambientTextTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: SkylineLyricChangeModifier(
                    blurRadius: 14,
                    opacity: 0,
                    scale: 0.92
                ),
                identity: SkylineLyricChangeModifier(
                    blurRadius: 0,
                    opacity: 1,
                    scale: 1
                )
            ),
            removal: .modifier(
                active: SkylineLyricChangeModifier(
                    blurRadius: 18,
                    opacity: 0,
                    scale: 1.08
                ),
                identity: SkylineLyricChangeModifier(
                    blurRadius: 0,
                    opacity: 1,
                    scale: 1
                )
            )
        )
    }

    private func randomizedPosition(
        for slot: SkylineLyricSlot,
        activeIndex: Int
    ) -> CGPoint {
        let seed = ambientSeed(for: slot, activeIndex: activeIndex)
        let randomness = CGFloat(settings.skylineLyrics.ambientPositionRandomness)
        let xJitter = (randomUnit(seed: seed) - 0.5) * 0.16 * randomness
        let yJitter = (randomUnit(seed: seed ^ 0x94D049BB133111EB) - 0.5)
            * 0.24
            * randomness

        return CGPoint(
            x: min(max(slot.x + xJitter, -0.02), 1.02),
            y: min(max(slot.y + yJitter, 0.08), 0.92)
        )
    }

    private func randomizedRotation(
        for slot: SkylineLyricSlot,
        activeIndex: Int
    ) -> Angle {
        let seed = ambientSeed(for: slot, activeIndex: activeIndex)
            ^ 0xD6E8FEB86659FD93
        let signedUnit = Double(randomUnit(seed: seed)) * 2 - 1
        return .degrees(
            signedUnit * settings.skylineLyrics.ambientMaximumTilt
        )
    }

    private func ambientSeed(
        for slot: SkylineLyricSlot,
        activeIndex: Int
    ) -> UInt64 {
        let lineSeed = UInt64(activeIndex + 1) &* 0x9E3779B97F4A7C15
        let slotSeed = UInt64(slot.id + 1) &* 0xBF58476D1CE4E5B9
        return lineSeed &+ slotSeed
    }

    private func randomUnit(seed: UInt64) -> CGFloat {
        var value = seed
        value ^= value >> 30
        value &*= 0xBF58476D1CE4E5B9
        value ^= value >> 27
        value &*= 0x94D049BB133111EB
        value ^= value >> 31
        return CGFloat(value % 10_000) / 10_000
    }

    private func driftOffset(
        _ offset: CGFloat,
        scale: CGFloat
    ) -> CGFloat {
        let direction: CGFloat = ambientFieldIsDrifting ? 1 : -1
        return offset * direction * scale
    }

    private var accentColor: Color {
        Color(
            red: accentRGB.x,
            green: accentRGB.y,
            blue: accentRGB.z
        )
    }

    private func centralLyricsAccessibilityLabel(
        _ line: LyricLine,
        nextLine: LyricLine?
    ) -> String {
        guard let nextLine else { return line.text }
        return "\(line.text)，下一句：\(nextLine.text)"
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

    private func ambientTexts(around activeIndex: Int?) -> [String] {
        guard let activeIndex else {
            return Array(repeating: "", count: Self.ambientSlots.count)
        }

        let neighborOffsets = [-3, 3, -2, 2, -1, 1]
        var fragments = neighborOffsets.flatMap { offset -> [String] in
            let index = activeIndex + offset
            guard lyrics.indices.contains(index) else { return [] }
            return lyricFragments(from: lyrics[index].text)
        }

        if fragments.isEmpty {
            fragments = lyricFragments(from: lyrics[activeIndex].text)
        }
        guard !fragments.isEmpty else {
            return Array(repeating: "", count: Self.ambientSlots.count)
        }

        return Self.ambientSlots.map { slot in
            fragments[(slot.id * 5 + activeIndex * 3) % fragments.count]
        }
    }

    private func lyricFragments(from text: String) -> [String] {
        let maximumCharacters = settings.skylineLyrics.ambientMaximumCharacters
        let groups = text.split { character in
            character.isWhitespace || character.isPunctuation
        }

        return groups.flatMap { group in
            let characters = Array(group)
            return stride(
                from: characters.startIndex,
                to: characters.endIndex,
                by: maximumCharacters
            ).map { startIndex in
                let endIndex = min(
                    startIndex + maximumCharacters,
                    characters.endIndex
                )
                return String(characters[startIndex..<endIndex])
            }
        }
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

    private func startAmbientMotion() {
        guard !accessibilityReduceMotion else { return }
        withAnimation(
            .easeInOut(duration: 9)
                .repeatForever(autoreverses: true)
        ) {
            ambientFieldIsDrifting = true
        }
    }
}

private struct SkylineLyricSlot: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat
    let blur: CGFloat
    let opacity: Double
    let driftX: CGFloat
    let driftY: CGFloat
}

private struct SkylineLyricChangeModifier: ViewModifier {
    let blurRadius: CGFloat
    let opacity: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: blurRadius)
            .opacity(opacity)
            .scaleEffect(scale)
    }
}
