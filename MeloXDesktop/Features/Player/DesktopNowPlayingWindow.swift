import SwiftUI

private extension Color {
    init(rgb: SIMD3<Double>) {
        self.init(red: rgb.x, green: rgb.y, blue: rgb.z)
    }
}

struct DesktopNowPlayingWindow: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pageTransition =
        DesktopNowPlayingTransitionCoordinator(initialPage: .lyrics)
    @State private var playerColumnPage: DesktopNowPlayingPage = .lyrics
    @State private var didRestorePage = false
    @State private var pageTransitionGeneration: UInt = 0
    @State private var directPanelSwap: DirectPanelSwap?
    @State private var directPanelSwapProgress: CGFloat = 1
    @State private var palette = ArtworkDetailPalette.fallback(
        prefersDarkAppearance: true
    )
    let isActive: Bool
    let isRenderingActive: Bool

    private struct DirectPanelSwap: Equatable {
        let id: UUID
        let from: DesktopNowPlayingPage
        let to: DesktopNowPlayingPage
    }

    private struct TransitionSettlementTaskID: Hashable {
        let requestID: UUID?
        let isLyricsEntrancePresented: Bool
    }

    private var page: DesktopNowPlayingPage {
        pageTransition.page
    }

    private var artworkURL: URL? {
        model.player.currentSong?.album?.artworkURL
    }

    private var artworkInfluencedForeground: Color {
        let white = SIMD3<Double>(repeating: 1)
        return Color(rgb: white * 0.88 + palette.backgroundRGB * 0.12)
    }

    private var keepsScreenAwake: Bool {
        guard isActive, model.player.isPlaying else { return false }
        switch model.settings.playerScreenAwakeMode {
        case .disabled:
            return false
        case .player:
            return true
        case .lyrics:
            return page == .lyrics
        case .hiddenLyricsInterface:
            return false
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                nowPlayingContent(in: proxy)

                playerChrome
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .topLeading
                    )
                    .zIndex(100)
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .topLeading
            )
            .clipped()
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 980, minHeight: 540)
        .keepsScreenAwake(keepsScreenAwake)
        .task(id: artworkURL) {
            palette = await ArtworkAccentColorProvider.shared.detailPalette(
                for: artworkURL,
                fallbackPrefersDarkAppearance: true
            )
        }
        .onAppear {
            restorePageIfNeeded()
        }
        .onChange(of: page) { _, page in
            guard model.settings.rememberNowPlayingPage else { return }
            model.settings.rememberedNowPlayingPage = page.rawValue
        }
        .task(id: transitionSettlementTaskID) {
            await settlePageTransition()
        }
        .task(id: pageTransition.pendingLyricsEntrance?.requestID) {
            await presentLyricsEntrance()
        }
    }

    private func nowPlayingContent(
        in proxy: GeometryProxy
    ) -> some View {
        let layout = DesktopNowPlayingLayout(viewport: proxy.size)

        let panelLeading = layout.panelLeading
        let panelWidth = max(
            proxy.size.width - panelLeading - layout.trailing,
            1
        )
        let playerX = playerColumnX(
            layout: layout,
            viewportWidth: proxy.size.width,
            page: playerColumnPage
        )

        return ZStack(alignment: .topLeading) {
            DesktopNowPlayingPlayerColumn(
                layout: layout,
                tint: artworkInfluencedForeground,
                isActive: isActive
            )
                .frame(
                    width: layout.playerWidth,
                    height: layout.contentHeight,
                    alignment: .top
                )
                .offset(x: playerX, y: layout.chromeHeight)

            if isPanelMounted(.lyrics) {
                animatedPanel(.lyrics, layout: layout, panelWidth: panelWidth)
                    .offset(
                        x: panelLeading,
                        y: layout.chromeHeight
                    )
                    .allowsHitTesting(isPanelInteractive(.lyrics))
                    .accessibilityHidden(!isPanelInteractive(.lyrics))
            }

            if isPanelMounted(.queue) {
                animatedPanel(.queue, layout: layout, panelWidth: panelWidth)
                    .offset(
                        x: panelLeading,
                        y: layout.chromeHeight
                    )
                    .allowsHitTesting(isPanelInteractive(.queue))
                    .accessibilityHidden(!isPanelInteractive(.queue))
            }
        }
        .frame(
            width: proxy.size.width,
            height: proxy.size.height,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func nowPlayingPanel(
        _ page: DesktopNowPlayingPage,
        layout: DesktopNowPlayingLayout
    ) -> some View {
        switch page {
        case .artwork:
            EmptyView()
        case .lyrics:
            DesktopPlaybackPositionedLyricsView(
                compact: false,
                foregroundColor: artworkInfluencedForeground,
                isActive: isRenderingActive
                    && self.page == .lyrics
                    && !isPageTransitioning,
                isPresented: isActive,
                // Music's LyricsSpecs builder chooses 24/28/38/50/72 fonts
                // from the real lyrics view width. Continuous visual scaling
                // would break both the recovered font breakpoints and the
                // 95pt row pitch.
                visualScale: 1,
                // MusicPlayerController constrains the lyrics view's
                // `activeBaseline` to primaryArtworkCenterY -
                // hostedContentMinY. The selected lyric center therefore sits
                // on the album-art center line, not on the viewport center.
                focusLift: layout.lyricsFocusLift
            )
            .padding(.top, DesktopNowPlayingLayout.lyricsTopPadding)
        case .queue:
            DesktopQueueView(presentation: .nowPlaying)
        }
    }

    private var playerChrome: some View {
        DesktopNowPlayingPageSwitcher(page: pageSelection)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottomTrailing
            )
        .allowsHitTesting(true)
    }

    private var pageSelection: Binding<DesktopNowPlayingPage> {
        Binding(
            get: { page },
            set: { selectPage($0) }
        )
    }

    private func playerColumnX(
        layout: DesktopNowPlayingLayout,
        viewportWidth: CGFloat,
        page: DesktopNowPlayingPage
    ) -> CGFloat {
        let centeredX = max(
            (viewportWidth - layout.playerWidth) * 0.5,
            0
        )
        let leadingX = layout.leading
        return page == .artwork ? centeredX : leadingX
    }

    private var transitionSettlementTaskID: TransitionSettlementTaskID {
        TransitionSettlementTaskID(
            requestID: pageTransition.transition?.id,
            isLyricsEntrancePresented:
                pageTransition.isLyricsEntrancePresented
        )
    }

    private var isPageTransitioning: Bool {
        pageTransition.transition != nil || directPanelSwap != nil
    }

    private struct DirectPanelVisualState {
        let scale: CGFloat
        let opacity: Double
    }

    private func directPanelVisualState(
        for panel: DesktopNowPlayingPage
    ) -> DirectPanelVisualState? {
        guard let directPanelSwap else { return nil }
        let progress = min(max(directPanelSwapProgress, 0), 1)
        let hiddenScale =
            DesktopNowPlayingMotion.macOS26_6.directAlternateContentScale

        if panel == directPanelSwap.from {
            return DirectPanelVisualState(
                scale: 1 + (hiddenScale - 1) * progress,
                opacity: Double(1 - progress)
            )
        }
        if panel == directPanelSwap.to {
            return DirectPanelVisualState(
                scale: hiddenScale + (1 - hiddenScale) * progress,
                opacity: Double(progress)
            )
        }
        return DirectPanelVisualState(scale: hiddenScale, opacity: 0)
    }

    @ViewBuilder
    private func animatedPanel(
        _ panel: DesktopNowPlayingPage,
        layout: DesktopNowPlayingLayout,
        panelWidth: CGFloat
    ) -> some View {
        let content = nowPlayingPanel(panel, layout: layout)
            .frame(
                width: panelWidth,
                height: layout.contentHeight,
                alignment: .topLeading
            )

        if let state = directPanelVisualState(for: panel) {
            // The direct Lyrics <-> Up Next animator is a single centered
            // shrink/fade (0.92), with no page translation.
            content
                .scaleEffect(state.scale, anchor: .center)
                .opacity(state.opacity)
        } else {
            switch panel {
            case .lyrics:
                content.desktopNowPlayingPanelPresentation(
                    opacityTransition:
                        pageTransition.lyricsOpacityTransition,
                    spatialTransition:
                        pageTransition.lyricsSpatialTransition,
                    opacitySpec:
                        pageTransition.lyricsOpacityTransition
                            .targetProgress >= 1
                            ? DesktopNowPlayingMotion.macOS26_6
                                .lyricsOpacityPresentation
                            : DesktopNowPlayingMotion.macOS26_6
                                .lyricsOpacityDismissal,
                    presentationScale:
                        DesktopNowPlayingMotion.macOS26_6
                            .lyricsPresentationScale,
                    reducesMotion: reduceMotion
                )
            case .queue:
                content.desktopNowPlayingPanelPresentation(
                    opacityTransition:
                        pageTransition.queueOpacityTransition,
                    spatialTransition:
                        pageTransition.queueSpatialTransition,
                    opacitySpec:
                        pageTransition.queueOpacityTransition
                            .targetProgress >= 1
                            ? DesktopNowPlayingMotion.macOS26_6
                                .queueOpacityPresentation
                            : DesktopNowPlayingMotion.macOS26_6
                                .queueOpacityDismissal,
                    presentationScale:
                        DesktopNowPlayingMotion.macOS26_6
                            .queuePresentationScale,
                    reducesMotion: reduceMotion
                )
            case .artwork:
                EmptyView()
            }
        }
    }

    private func isPanelInteractive(
        _ panel: DesktopNowPlayingPage
    ) -> Bool {
        page == panel && !isPageTransitioning
    }

    private func isPanelMounted(
        _ panel: DesktopNowPlayingPage
    ) -> Bool {
        if let directPanelSwap {
            return panel == directPanelSwap.from
                || panel == directPanelSwap.to
        }
        if let transition = pageTransition.transition {
            return panel == transition.source
                || panel == transition.destination
        }
        return panel == page
    }

    private func selectPage(_ destination: DesktopNowPlayingPage) {
        guard destination != page else { return }

        let source = page
        let usesDirectPanelSwap =
            source == .lyrics && destination == .queue
            || source == .queue && destination == .lyrics
        pageTransitionGeneration &+= 1
        let generation = pageTransitionGeneration

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pageTransition.select(
                destination,
                usesAppleMusicLyrics:
                    model.settings.appleMusicLyrics.usesAppleMusic26Motion,
                motion: .macOS26_6
            )
            directPanelSwap = usesDirectPanelSwap
                ? DirectPanelSwap(
                    id: pageTransition.transition?.id ?? UUID(),
                    from: source,
                    to: destination
                )
                : nil
            directPanelSwapProgress = reduceMotion ? 1 : 0
            if reduceMotion {
                playerColumnPage = destination
            }
        }

        guard !reduceMotion else {
            finishPageTransition(generation: generation)
            return
        }

        // `pageTransition` is intentionally committed without animation so
        // its interruptible panel springs retain their exact presentation
        // state. Keep Music's artwork resize in a separate transaction;
        // otherwise the column receives the final page value and teleports.
        withAnimation(DesktopNowPlayingMotion.macOS26_6.artworkResize.animation) {
            playerColumnPage = destination
        }

        guard usesDirectPanelSwap else { return }

        Task { @MainActor in
            await Task.yield()
            guard generation == pageTransitionGeneration,
                  directPanelSwap?.from == source,
                  directPanelSwap?.to == destination else { return }
            withAnimation(DesktopNowPlayingMotion.macOS26_6.directAlternate.animation) {
                directPanelSwapProgress = 1
            }
            do {
                try await Task.sleep(
                    for: .seconds(
                        DesktopNowPlayingMotion.macOS26_6
                            .directAlternateSettlementDuration
                    )
                )
            } catch {
                return
            }
            guard !Task.isCancelled,
                  generation == pageTransitionGeneration else { return }
            finishPageTransition(generation: generation)
        }
    }

    private func finishPageTransition(generation: UInt) {
        guard generation == pageTransitionGeneration else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let transition = pageTransition.transition {
                pageTransition.settleTransition(requestID: transition.id)
            }
            directPanelSwap = nil
            directPanelSwapProgress = 1
        }
    }

    private func settlePageTransition() async {
        guard let transition = pageTransition.transition,
              pageTransition.isLyricsEntrancePresented else {
            return
        }
        let now = ContinuousClock.now
        let settlementDuration = reduceMotion
            ? 0
            : max(
                DesktopNowPlayingMotion.macOS26_6.settlementDuration(
                    for: transition
                ),
                pageTransition.activeMotionRemainingDuration(at: now)
            )
        if settlementDuration > 0 {
            do {
                try await Task.sleep(for: .seconds(settlementDuration))
            } catch {
                return
            }
        }
        guard !Task.isCancelled,
              page == transition.destination,
              pageTransition.transition?.id == transition.id else {
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pageTransition.settleTransition(requestID: transition.id)
        }
    }

    private func presentLyricsEntrance() async {
        guard let pendingEntrance = pageTransition.pendingLyricsEntrance else {
            return
        }
        let requestID = pendingEntrance.requestID
        await Task.yield()
        guard !Task.isCancelled,
              pageTransition.pendingLyricsEntrance?.requestID == requestID else {
            return
        }

        if reduceMotion {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                pageTransition.presentLyricsEntrance(
                    requestID: requestID,
                    motion: .macOS26_6
                )
            }
            return
        }

        guard page == .lyrics else { return }
        let delay = ContinuousClock.now.duration(
            to: pendingEntrance.notBefore
        )
        if delay > .zero {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
        }
        guard !Task.isCancelled,
              page == .lyrics,
              pageTransition.pendingLyricsEntrance?.requestID == requestID else {
            return
        }
        pageTransition.presentLyricsEntrance(
            requestID: requestID,
            motion: .macOS26_6
        )
    }

    private func restorePageIfNeeded() {
        guard !didRestorePage else { return }
        didRestorePage = true
        let restoredPage = model.settings.rememberNowPlayingPage
            ? DesktopNowPlayingPage(
                storedValue: model.settings.rememberedNowPlayingPage
            )
            : .lyrics
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pageTransition.reset(to: restoredPage)
            playerColumnPage = restoredPage
            directPanelSwap = nil
            directPanelSwapProgress = 1
        }
    }

}
