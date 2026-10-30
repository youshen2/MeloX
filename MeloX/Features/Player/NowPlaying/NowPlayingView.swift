import SwiftUI
import UIKit

struct NowPlayingView: View {
    private static let portraitHorizontalPadding: CGFloat = 32

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled)
    private var accessibilityVoiceOverEnabled
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings
    @Environment(LyricsStore.self) private var lyricsStore

    @State private var pageTransition: NowPlayingTransitionCoordinator
    @State private var showsLyricsControls = true
    @State private var appleMusicControlsActivityGeneration = 0
    @State private var highlightedLyricID: LyricLine.ID?
    @State private var showsTextPVLandscapeSuggestion = false
    @State private var isQueueSongHeaderHidden = false
    @State private var queueSongHeaderOffset: CGFloat = 0
    @State private var artworkPageFrame = CGRect.zero
    @State private var preparedLyricsSongID: Song.ID?
    @State private var hasDisplayDivision = false
    @State private var showsFullScreenLyrics = false
    @Namespace private var pageArtworkNamespace

    private var page: NowPlayingPage {
        pageTransition.page
    }

    init(initialPage: NowPlayingPage = .artwork) {
        _pageTransition = State(
            initialValue: NowPlayingTransitionCoordinator(
                initialPage: initialPage
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if usesMonochromeLyricsBackground {
                    Color.black
                        .ignoresSafeArea()
                } else {
                    NowPlayingBackground(
                        artworkURL:
                            player.currentSong?
                                .album?
                                .artworkURL,
                        beatTimeline:
                            player.currentBeatTimeline,
                        isBehindLyrics:
                            page == .lyrics
                    )
                }

                if let song = player.currentSong {
                    if showsFullScreenLyrics, page == .lyrics {
                        fullScreenLyrics(for: song)
                    } else if usesExpandedLayout {
                        NowPlayingTabletView(
                            page: pageSelection,
                            pageTransition: pageTransition,
                            song: song,
                            lyrics: lyrics,
                            lyricError: lyricError,
                            highlightedLyricID: highlightedLyricID,
                            artworkNamespace: pageArtworkNamespace,
                            onDismiss: { dismiss() },
                            onExpandLyrics: {
                                showsLyricsControls = true
                                showsFullScreenLyrics = true
                            },
                            onLyricsContentPrepared: {
                                markLyricsContentPrepared(for: song.id)
                            }
                        )
                    } else if usesFullScreenTextPV {
                        TextPVFullScreenPlayerView(
                            page: pageSelection,
                            showsControls: $showsLyricsControls,
                            song: song,
                            lyrics: lyrics,
                            errorMessage: lyricError,
                            highlightedLyricID: highlightedLyricID,
                            onDismiss: { dismiss() },
                            onToggleInterface:
                                toggleLyricsControls
                        )
                        .transition(.opacity)
                    } else if proxy.size.width > proxy.size.height {
                        NowPlayingLandscapeView(
                            page: pageSelection,
                            pageTransition: pageTransition,
                            showsLyricsControls: showsLyricsControls,
                            song: song,
                            lyrics: lyrics,
                            lyricError: lyricError,
                            highlightedLyricID: highlightedLyricID,
                            artworkNamespace: pageArtworkNamespace,
                            onDismiss: { dismiss() },
                            onInterfaceInteraction:
                                handleLyricsInterfaceInteraction,
                            onInterfaceVisibilityChange:
                                setAppleMusicLyricsControlsVisible,
                            onLyricsContentPrepared: {
                                markLyricsContentPrepared(
                                    for: song.id
                                )
                            }
                        )
                    } else {
                        portraitContent(for: song)
                    }
                } else {
                    ContentUnavailableView("ui.player.no_current_song", systemImage: "music.note")
                        .foregroundStyle(.white)
                }

                if usesFullScreenTextPV,
                   showsTextPVLandscapeSuggestion,
                   proxy.size.width <= proxy.size.height {
                    Label("ui.text_pv.landscape_recommended", systemImage: "rectangle.landscape.rotate")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.regularMaterial, in: .capsule)
                        .shadow(color: .black.opacity(0.24), radius: 12, y: 5)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .safeAreaPadding(.top, 58)
                        .accessibilityLabel("ui.text_pv.landscape_recommended")
                }
            }
        }
        .onGeometryChange(for: Bool.self) { proxy in
            if #available(iOS 27.1, *) {
                // Keep the inner-display layout stable while the fold flattens.
                !proxy.reservedRegions(kind: .division, options: .includeInactive).isEmpty
            } else {
                false
            }
        } action: { hasDivision in
            hasDisplayDivision = hasDivision
        }
        .background {
            NowPlayingLyricSynchronizer(
                lyrics: lyrics,
                highlightedLyricID: $highlightedLyricID
            )
        }
        .keepsScreenAwake(keepsPlayerScreenAwake)
        .preferredColorScheme(.dark)
        .task(id: beatAnalysisTaskID) {
            await loadBeatTimeline()
        }
        .task(id: usesFullScreenTextPV) {
            guard usesFullScreenTextPV else {
                showsTextPVLandscapeSuggestion = false
                return
            }

            withAnimation(accessibilityReduceMotion ? nil : .smooth(duration: 0.25)) {
                showsTextPVLandscapeSuggestion = true
            }
            do {
                try await Task.sleep(for: .seconds(3.2))
            } catch {
                return
            }
            withAnimation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.2)) {
                showsTextPVLandscapeSuggestion = false
            }
        }
        .task(id: appleMusicControlsActivityGeneration) {
            guard usesAutoHidingAppleMusicInterface,
                  showsLyricsControls,
                  !accessibilityVoiceOverEnabled else {
                return
            }

            do {
                try await Task.sleep(
                    for: .seconds(
                        settings
                            .appleMusicLyricsInterfaceAutoHideDelay
                    )
                )
            } catch {
                return
            }
            guard !Task.isCancelled,
                  usesAutoHidingAppleMusicInterface else {
                return
            }

            withAnimation(
                NowPlayingInterfaceTransition.interfaceAnimation(
                    isVisible: false,
                    reducesMotion: accessibilityReduceMotion
                )
            ) {
                showsLyricsControls = false
            }
        }
        .task(id: transitionSettlementTaskID) {
            await settlePageTransition()
        }
        .task(id: lyricsEntranceTaskID) {
            await presentLyricsEntrance()
        }
        .onChange(of: page) { _, newPage in
            showsFullScreenLyrics = false
            if newPage == .lyrics,
               settings.lyricsStyle == .appleMusic {
                registerAppleMusicControlsActivity()
            } else {
                cancelAppleMusicControlsAutoHide()
                showsLyricsControls = true
            }

            guard settings.rememberNowPlayingPage else { return }
            settings.rememberedNowPlayingPage = newPage.rawValue
        }
        .onChange(of: accessibilityVoiceOverEnabled) {
            _, voiceOverEnabled in
            guard usesAutoHidingAppleMusicInterface else { return }

            if voiceOverEnabled {
                cancelAppleMusicControlsAutoHide()
                showsLyricsControls = true
            } else {
                registerAppleMusicControlsActivity()
            }
        }
        .onChange(of: settings.lyricsStyle) { _, newStyle in
            cancelAppleMusicControlsAutoHide()
            showsLyricsControls = true

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                pageTransition.synchronizeLyricsVisibility(
                    isVisible:
                        page == .lyrics
                        && newStyle == .appleMusic
                )
            }

            if page == .lyrics, newStyle == .appleMusic {
                registerAppleMusicControlsActivity()
            }
        }
        .onChange(of: usesExpandedLayout) {
            cancelAppleMusicControlsAutoHide()
            showsLyricsControls = true
            registerAppleMusicControlsActivity()
        }
        .onChange(
            of: settings.appleMusicLyricsInterfaceAutoHideDelay
        ) {
            registerAppleMusicControlsActivity()
        }
        .onAppear {
            resetPodcastPageIfNeeded()
        }
        .onChange(of: player.currentSong?.id) {
            resetPodcastPageIfNeeded()
        }
    }

    private var beatAnalysisTaskID:
        NowPlayingBeatAnalysisTaskID {
        NowPlayingBeatAnalysisTaskID(
            songID: player.currentSong?.id,
            isPlaybackReady: !player.isLoading,
            isEnabled:
                settings.playerBackgroundStyle
                    == .flowingLight
                    && settings
                        .playerBackgroundBeatEffectsEnabled
                    && player.currentSong?.isPodcastProgram != true
        )
    }

    private func loadBeatTimeline() async {
        let taskID = beatAnalysisTaskID
        guard taskID.isEnabled else {
            player.clearCurrentSongBeatAnalysis()
            return
        }
        guard
              taskID.isPlaybackReady,
              taskID.songID != nil else {
            return
        }

        await player.analyzeCurrentSongBeats()
    }

    private func resetPodcastPageIfNeeded() {
        guard player.currentSong?.isPodcastProgram == true,
              page == .lyrics else {
            return
        }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pageTransition.reset(to: .artwork)
        }
    }

    private func portraitContent(for song: Song) -> some View {
        VStack(spacing: 0) {
            dismissalHandle

            pageContent(for: song)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    portraitPlayerControlsLayer(for: song)
                }
        }
        .padding(.horizontal, Self.portraitHorizontalPadding)
        .safeAreaPadding(.bottom, 3)
    }

    @ViewBuilder
    private func fullScreenLyrics(for song: Song) -> some View {
        if settings.lyricsStyle == .textPV {
            TextPVFullScreenPlayerView(
                page: pageSelection,
                showsControls: $showsLyricsControls,
                song: song,
                lyrics: lyrics,
                errorMessage: lyricError,
                highlightedLyricID: highlightedLyricID,
                onDismiss: { showsFullScreenLyrics = false },
                onToggleInterface: toggleLyricsControls
            )
        } else {
            SkylineLyricsView(
                artworkURL: song.album?.artworkURL,
                lyrics: lyrics,
                errorMessage: lyricError,
                highlightedLyricID: highlightedLyricID,
                onExit: { showsFullScreenLyrics = false }
            )
        }
    }

    private func portraitPlayerControlsLayer(
        for song: Song
    ) -> some View {
        ZStack(alignment: .bottom) {
            portraitPlayerControls(for: song)
                .allowsHitTesting(!hidesLyricsControls)
                .accessibilityHidden(hidesLyricsControls)

            if hidesLyricsControls,
               settings.lyricsStyle != .appleMusic {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(
                        height: NowPlayingBottomControls.overlayHeight
                    )
                    .contentShape(.rect)
                    .onTapGesture {
                        handleLyricsInterfaceInteraction()
                    }
                    .accessibilityHidden(true)
            }
        }
        .frame(height: NowPlayingBottomControls.overlayHeight)
    }

    private func portraitPlayerControls(for song: Song) -> some View {
        NowPlayingBottomControls(
            song: song,
            page: pageSelection,
            showsLyricsUtilities:
                usesExpandedAppleMusicLyricsLayout,
            hasLyricsTranslations: hasLyricsTranslations,
            hasLyricsRomanizations: hasLyricsRomanizations,
            isInterfaceHidden: hidesLyricsControls
        )
    }

    private var pageSelection: Binding<NowPlayingPage> {
        Binding(
            get: { page },
            set: { newPage in
                pageTransition.select(
                    newPage,
                    usesAppleMusicLyrics:
                        settings.lyricsStyle == .appleMusic,
                    isQueueSongHeaderHidden:
                        isQueueSongHeaderHidden,
                    motion: NowPlayingPageTransition.motion
                )
            }
        )
    }

    private var hidesLyricsControls: Bool {
        page == .lyrics && !showsLyricsControls
    }

    private var usesAutoHidingAppleMusicInterface: Bool {
        !usesExpandedLayout
            && page == .lyrics
            && settings.lyricsStyle == .appleMusic
    }

    private var lyrics: [LyricLine] {
        lyricsStore.lyrics
    }

    private var lyricError: String? {
        lyricsStore.errorMessage
    }

    private var hasLyricsTranslations: Bool {
        lyrics.contains { $0.hasTranslation }
    }

    private var hasLyricsRomanizations: Bool {
        lyrics.contains { $0.hasRomanization }
    }

    private var keepsPlayerScreenAwake: Bool {
        switch settings.playerScreenAwakeMode {
        case .disabled:
            false
        case .player:
            true
        case .lyrics:
            page == .lyrics
        case .hiddenLyricsInterface:
            hidesLyricsControls
        }
    }

    private var usesExpandedAppleMusicLyricsLayout: Bool {
        page == .lyrics && settings.lyricsStyle == .appleMusic
    }

    private var usesFullScreenTextPV: Bool {
        (!usesExpandedLayout || showsFullScreenLyrics)
            && page == .lyrics && settings.lyricsStyle == .textPV
    }

    private var usesExpandedLayout: Bool {
        hasDisplayDivision
            || (horizontalSizeClass == .regular && verticalSizeClass != .compact)
    }

    private var usesMonochromeLyricsBackground: Bool {
        page == .lyrics && settings.lyricsStyle.usesMonochromePlayerBackground
    }

    private var dismissalHandle: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.52))
                .frame(width: 60, height: 5)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .contentShape(.rect)
        .onTapGesture {
            dismiss()
        }
        .accessibilityElement()
        .accessibilityLabel("ui.player.collapse")
        .accessibilityHint("ui.player.collapse_hint")
        .accessibilityAction {
            dismiss()
        }
    }

    private func pageContent(for song: Song) -> some View {
        ZStack(alignment: .top) {
            transientArtworkPageContent(for: song)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .clipped()

            residentQueuePage(for: song)

            if settings.lyricsStyle == .appleMusic {
                residentAppleMusicLyricsPage(for: song)
            } else if page == .lyrics {
                portraitLyricsPage(for: song)
                    .clipped()
                    .transition(
                        pageContentTransition(for: .lyrics)
                    )
            }

            if page != .artwork {
                sharedPortraitSongHeader(for: song)
                    .offset(y: sharedPortraitSongHeaderOffset)
                    .clipped()
                    .transition(
                        NowPlayingPageTransition.songHeader(
                            reducesMotion: accessibilityReduceMotion
                        )
                    )
            }

        }
        .background {
            if keepsStableArtworkFrameMeasurement {
                artworkFrameMeasurement(for: song)
            }
        }
        .overlay {
            GeometryReader { _ in
                if portraitArtworkFrame.width > 0 {
                    NowPlayingPortraitArtwork(
                        song: song,
                        isArtworkPage: page == .artwork
                    )
                    .frame(
                        width: portraitArtworkFrame.width,
                        height: portraitArtworkFrame.height
                    )
                    .position(
                        x:
                            portraitArtworkFrame.midX
                            + Self.portraitHorizontalPadding,
                        y: portraitArtworkFrame.midY
                    )
                    .animation(
                        accessibilityReduceMotion
                            ? nil
                            : NowPlayingPageTransition
                                .motion
                                .artworkResize
                                .animation,
                        value: isPortraitArtworkExpanded
                    )
                    .allowsHitTesting(false)
                }
            }
            // Keep page-transition clipping vertically while allowing the
            // expanded artwork to use the portrait layout's side margins.
            .clipped()
            .padding(
                .horizontal,
                -Self.portraitHorizontalPadding
            )
        }
        .coordinateSpace(
            name: NowPlayingPortraitCoordinateSpace.name
        )
    }

    @ViewBuilder
    private func transientArtworkPageContent(
        for song: Song
    ) -> some View {
        if page == .artwork {
            NowPlayingArtworkPage(
                song: song,
                artworkNamespace: pageArtworkNamespace,
                usesArtworkTransition: false,
                showsArtwork: false,
                onArtworkFrameChange:
                    recordPresentedArtworkPageFrame
            )
            .transition(
                pageContentTransition(for: .artwork)
            )
        }
    }

    private func artworkFrameMeasurement(
        for song: Song
    ) -> some View {
        NowPlayingArtworkPage(
            song: song,
            artworkNamespace: pageArtworkNamespace,
            usesArtworkTransition: false,
            showsArtwork: false,
            onArtworkFrameChange: recordArtworkPageFrame
        )
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var keepsStableArtworkFrameMeasurement: Bool {
        page != .artwork || pageTransition.transition != nil
    }

    private func recordPresentedArtworkPageFrame(
        _ frame: CGRect
    ) {
        // The artwork page enters from below. Its geometry includes that
        // temporary transition offset, so keep using the resident
        // measurement until the page transition has settled.
        guard pageTransition.transition == nil else { return }
        recordArtworkPageFrame(frame)
    }

    private func recordArtworkPageFrame(_ frame: CGRect) {
        guard frame.width.isFinite,
              frame.height.isFinite,
              frame.minX.isFinite,
              frame.minY.isFinite,
              frame.width > 0,
              frame.height > 0 else {
            return
        }
        let tolerance: CGFloat = 0.5
        guard abs(artworkPageFrame.minX - frame.minX) > tolerance
                || abs(artworkPageFrame.minY - frame.minY) > tolerance
                || abs(artworkPageFrame.width - frame.width) > tolerance
                || abs(artworkPageFrame.height - frame.height) > tolerance else {
            return
        }
        artworkPageFrame = frame
    }

    private func residentQueuePage(
        for song: Song
    ) -> some View {
        let visualState = residentQueueVisualState

        return NowPlayingQueuePage(
            song: song,
            presentation: .portrait,
            artworkNamespace: pageArtworkNamespace,
            usesArtworkTransition: false,
            showsSongHeader: false,
            onSongHeaderHiddenChange: {
                isQueueSongHeaderHidden = $0
            },
            onSongHeaderOffsetChange: {
                queueSongHeaderOffset = $0
            }
        )
        .clipped()
        .nowPlayingQueuePagePresentation(
            visualState: visualState,
            opacityTransition: pageTransition.queueOpacityTransition,
            spatialTransition: pageTransition.queueSpatialTransition,
            opacitySpec:
                pageTransition.queueOpacityTransition.targetProgress >= 1
                    ? NowPlayingPageTransition.motion
                        .queueOpacityPresentation
                    : NowPlayingPageTransition.motion
                        .queueOpacityDismissal,
            presentationScale:
                NowPlayingPageTransition.motion.queuePresentationScale,
            reducesMotion: accessibilityReduceMotion
        )
        .allowsHitTesting(page == .queue)
        .accessibilityHidden(page != .queue)
    }

    private func portraitLyricsPage(
        for song: Song,
        onInitialFocusPrepared: (() -> Void)? = nil
    ) -> some View {
        NowPlayingLyricsPage(
            song: song,
            lyrics: lyrics,
            errorMessage: lyricError,
            highlightedLyricID: highlightedLyricID,
            isActive: page == .lyrics,
            isInterfaceHidden: hidesLyricsControls,
            artworkNamespace: pageArtworkNamespace,
            usesArtworkTransition:
                !pageTransition.entersFromHiddenQueue,
            showsSongHeader: false,
            onInterfaceInteraction:
                handleLyricsInterfaceInteraction,
            onInterfaceVisibilityChange:
                setAppleMusicLyricsControlsVisible,
            onInitialFocusPrepared: onInitialFocusPrepared
        )
        .accessibilityAction(
            named: lyricsInterfaceAccessibilityActionName
        ) {
            handleLyricsInterfaceInteraction()
        }
    }

    private func residentAppleMusicLyricsPage(
        for song: Song
    ) -> some View {
        let visualState = residentLyricsVisualState

        return portraitLyricsPage(
            for: song,
            onInitialFocusPrepared: {
                markLyricsContentPrepared(for: song.id)
            }
        )
        .id(song.id)
        .nowPlayingLyricsPagePresentation(
            visualState: visualState,
            opacityTransition:
                pageTransition.lyricsOpacityTransition,
            spatialTransition:
                pageTransition.lyricsSpatialTransition,
            opacitySpec:
                pageTransition.lyricsOpacityTransition
                    .targetProgress >= 1
                    ? NowPlayingPageTransition.motion
                        .lyricsOpacityPresentation
                    : NowPlayingPageTransition.motion
                        .lyricsOpacityDismissal,
            presentationScale:
                NowPlayingPageTransition.motion
                    .lyricsPresentationScale,
            reducesMotion: accessibilityReduceMotion
        )
        .allowsHitTesting(page == .lyrics)
        .accessibilityHidden(page != .lyrics)
    }

    private var residentLyricsVisualState: NowPlayingPageVisualState {
        NowPlayingPageTransition.motion.residentLyricsState(
            selectedPage: page,
            transition: pageTransition.transition,
            isEntrancePresented:
                pageTransition.isLyricsEntrancePresented
        )
    }

    private var residentQueueVisualState: NowPlayingPageVisualState {
        NowPlayingPageTransition.motion.residentQueueState(
            selectedPage: page,
            transition: pageTransition.transition
        )
    }

    private func sharedPortraitSongHeader(
        for song: Song
    ) -> some View {
        NowPlayingSongHeader(
            song: song,
            artworkNamespace: pageArtworkNamespace,
            usesReferenceLayout: true,
            usesArtworkTransition: false,
            showsArtwork: false
        )
    }

    private var portraitArtworkFrame: CGRect {
        if page == .artwork {
            return displayedArtworkPageFrame
        }

        return CGRect(
            x: 0,
            y: sharedPortraitSongHeaderOffset,
            width: NowPlayingSongHeader.referenceHeight,
            height: NowPlayingSongHeader.referenceHeight
        )
    }

    private var displayedArtworkPageFrame: CGRect {
        guard !isPortraitArtworkExpanded else {
            return artworkPageFrame
        }
        let horizontalInset =
            artworkPageFrame.width
            * (1 - NowPlayingArtworkPage.pausedArtworkScale)
            / 2
        let verticalInset =
            artworkPageFrame.height
            * (1 - NowPlayingArtworkPage.pausedArtworkScale)
            / 2
        return artworkPageFrame.insetBy(
            dx: horizontalInset,
            dy: verticalInset
        )
    }

    private var isPortraitArtworkExpanded: Bool {
        player.isPlaying || !settings.shrinksPausedArtwork
    }

    private var sharedPortraitSongHeaderOffset: CGFloat {
        page == .queue ? queueSongHeaderOffset : 0
    }

    private func pageContentTransition(
        for destination: NowPlayingPage
    ) -> AnyTransition {
        if NowPlayingPageTransition.isDirectLyricsQueueTransition(
            from: pageTransition.sourcePage,
            to: pageTransition.destinationPage
        ) {
            return NowPlayingPageTransition.directAlternateContent(
                reducesMotion: accessibilityReduceMotion
            )
        }

        return NowPlayingPageTransition.content(
            for: destination,
            entersFromHiddenQueue:
                pageTransition.entersFromHiddenQueue,
            reducesMotion: accessibilityReduceMotion
        )
    }

    private var transitionSettlementTaskID:
        NowPlayingTransitionSettlementTaskID {
        NowPlayingTransitionSettlementTaskID(
            requestID: pageTransition.transition?.id,
            isLyricsEntrancePresented:
                pageTransition.isLyricsEntrancePresented
        )
    }

    private var lyricsEntranceTaskID:
        NowPlayingLyricsEntranceTaskID {
        NowPlayingLyricsEntranceTaskID(
            requestID: pageTransition.pendingLyricsEntrance?
                .requestID,
            songID: player.currentSong?.id,
            preparedSongID: preparedLyricsSongID,
            isContentPrepared: isLyricsContentPrepared
        )
    }

    private func settlePageTransition() async {
        guard let transition = pageTransition.transition,
              pageTransition.isLyricsEntrancePresented else {
            return
        }

        let now = ContinuousClock.now
        let settlementDuration = accessibilityReduceMotion
            ? 0
            : max(
                NowPlayingPageTransition.motion.settlementDuration(
                    for: transition
                ),
                pageTransition.activeMotionRemainingDuration(at: now)
            )
        if settlementDuration > 0 {
            do {
                try await Task.sleep(
                    for: .seconds(settlementDuration)
                )
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
            pageTransition.settleTransition(
                requestID: transition.id
            )
        }
    }

    private func presentLyricsEntrance() async {
        guard let pendingEntrance =
            pageTransition.pendingLyricsEntrance else {
            return
        }
        let requestID = pendingEntrance.requestID

        await Task.yield()
        guard !Task.isCancelled,
              pageTransition.pendingLyricsEntrance?.requestID
                == requestID else {
            return
        }

        if accessibilityReduceMotion {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                pageTransition.presentLyricsEntrance(
                    requestID: requestID,
                    motion: NowPlayingPageTransition.motion
                )
            }
            return
        }

        guard page == .lyrics,
              pageTransition.usesStagedLyricsEntrance else {
            return
        }

        let presentationDeadline = isLyricsContentPrepared
            ? pendingEntrance.notBefore
            : pendingEntrance.fallbackAt
        let remainingDelay = ContinuousClock.now.duration(
            to: presentationDeadline
        )
        if remainingDelay > .zero {
            do {
                try await Task.sleep(for: remainingDelay)
            } catch {
                return
            }
        }

        guard !Task.isCancelled,
              page == .lyrics,
              pageTransition.pendingLyricsEntrance?.requestID
                == requestID else {
            return
        }

        pageTransition.presentLyricsEntrance(
            requestID: requestID,
            motion: NowPlayingPageTransition.motion
        )
    }

    private var isLyricsContentPrepared: Bool {
        lyrics.isEmpty
            || preparedLyricsSongID == player.currentSong?.id
    }

    private func markLyricsContentPrepared(for songID: Song.ID) {
        guard player.currentSong?.id == songID else { return }
        preparedLyricsSongID = songID
    }

    private var lyricsInterfaceAccessibilityActionName: String {
        if settings.lyricsStyle == .appleMusic {
            return L10n.string("ui.player.show_controls")
        }
        return showsLyricsControls
            ? L10n.string("ui.player.hide_controls")
            : L10n.string("ui.player.show_controls")
    }

    private func handleLyricsInterfaceInteraction() {
        if settings.lyricsStyle == .appleMusic {
            registerAppleMusicControlsActivity()
        } else {
            toggleLyricsControls()
        }
    }

    private func registerAppleMusicControlsActivity() {
        guard usesAutoHidingAppleMusicInterface else { return }

        appleMusicControlsActivityGeneration &+= 1
        guard !showsLyricsControls else { return }

        withAnimation(
            NowPlayingInterfaceTransition.interfaceAnimation(
                isVisible: true,
                reducesMotion: accessibilityReduceMotion
            )
        ) {
            showsLyricsControls = true
        }
    }

    private func setAppleMusicLyricsControlsVisible(_ isVisible: Bool) {
        guard usesAutoHidingAppleMusicInterface else { return }
        if isVisible {
            registerAppleMusicControlsActivity()
            return
        }

        guard showsLyricsControls,
              !accessibilityVoiceOverEnabled else {
            return
        }
        cancelAppleMusicControlsAutoHide()
        withAnimation(
            NowPlayingInterfaceTransition.interfaceAnimation(
                isVisible: false,
                reducesMotion: accessibilityReduceMotion
            )
        ) {
            showsLyricsControls = false
        }
    }

    private func toggleLyricsControls() {
        withAnimation(
            accessibilityReduceMotion
                ? nil
                : .smooth(duration: 0.3)
        ) {
            showsLyricsControls.toggle()
        }
    }

    private func cancelAppleMusicControlsAutoHide() {
        appleMusicControlsActivityGeneration &+= 1
    }

}

private struct NowPlayingBeatAnalysisTaskID: Equatable {
    let songID: Int?
    let isPlaybackReady: Bool
    let isEnabled: Bool
}

private struct NowPlayingTransitionSettlementTaskID: Equatable {
    let requestID: UUID?
    let isLyricsEntrancePresented: Bool
}

private struct NowPlayingLyricsEntranceTaskID: Equatable {
    let requestID: UUID?
    let songID: Song.ID?
    let preparedSongID: Song.ID?
    let isContentPrepared: Bool
}
