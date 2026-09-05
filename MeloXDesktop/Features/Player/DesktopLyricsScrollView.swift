import AppKit
import SwiftUI

struct DesktopLyricsScrollView: View {
    private enum PresentationPhase: String {
        case unmanaged
        case hidden
        case opening
        case active
    }

    private enum PositionCascadeLineID: Hashable {
        case lyric(LyricLine.ID)
        case interlude(LyricInterlude.ID)
    }

    private struct ScrollRequest: Equatable {
        let id: String
        let generation: UInt
        let animationDuration: TimeInterval?
        let usesLineChangeSpring: Bool
    }

    private static let focusColorTransitionDuration: TimeInterval = 0.12
    private static let viewportAlignmentDelay: Duration = .milliseconds(120)
    private static let annotationSpacing =
        LyricAnnotationMetrics.verticalSpacing
    private static let viewportMaskTopOpaqueFallbackPercent = 8.0
    private static let viewportMaskTopContentClearance: CGFloat = 2

    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollRequest: ScrollRequest?
    @State private var isInitialFocusPrepared = false
    @State private var isViewportChanging = false
    @State private var isBrowsingLyrics = false
    @State private var browsingGeneration = 0
    @State private var positionedLyricID: LyricLine.ID?
    @State private var positionedInterludeID: LyricInterlude.ID?
    @State private var playbackFocus: AppleMusicLyricsPlaybackFocus?
    @State private var timelineHighlightedLyricID: LyricLine.ID?
    @State private var visibleInterludeID: LyricInterlude.ID?
    @State private var visualHighlightedLyricID: LyricLine.ID?
    @State private var lyricFocusColorTransition:
        LyricFocusColorTransition?
    @State private var visualCascadeFocusLyricID: LyricLine.ID?
    @State private var geometryCache = DesktopLyricsGeometryCache()
    @State private var lyricMovementOffsetByID: [LyricLine.ID: CGFloat] = [:]
    @State private var lyricMovementTransition: LyricMovementTransition?
    var compact = false
    var allowsLyricBlur = true
    var foregroundColor: Color = .primary
    var isActive = true
    var isPresented = true
    var keepsPlaybackFocusSynchronized = false
    var visualScale: CGFloat = 1
    var focusLift: CGFloat = 0

    init(
        compact: Bool = false,
        allowsLyricBlur: Bool = true,
        foregroundColor: Color = .primary,
        initialFocusID: LyricLine.ID? = nil,
        isActive: Bool = true,
        isPresented: Bool = true,
        keepsPlaybackFocusSynchronized: Bool = false,
        visualScale: CGFloat = 1,
        focusLift: CGFloat = 0
    ) {
        self.compact = compact
        self.allowsLyricBlur = allowsLyricBlur
        self.foregroundColor = foregroundColor
        self.isActive = isActive
        self.isPresented = isPresented
        self.keepsPlaybackFocusSynchronized =
            keepsPlaybackFocusSynchronized
        self.visualScale = max(visualScale, 1)
        self.focusLift = max(focusLift, 0)

        _scrollRequest = State(
            initialValue: initialFocusID.map {
                ScrollRequest(
                    id: $0,
                    generation: 0,
                    animationDuration: nil,
                    usesLineChangeSpring: false
                )
            }
        )
        // Keep the visual focus and the first one-way scroll request in sync.
        // This prevents the coordinator's initial update from producing a
        // visible first-row -> current-row double scroll.
        _positionedLyricID = State(initialValue: nil)
        _playbackFocus = State(
            initialValue: initialFocusID.map {
                AppleMusicLyricsPlaybackFocus.lyric($0)
            }
        )
        _timelineHighlightedLyricID = State(initialValue: initialFocusID)
        _visualHighlightedLyricID = State(initialValue: initialFocusID)
        _visualCascadeFocusLyricID = State(initialValue: initialFocusID)
    }

    /// Music's wrapper creates the same LyricsSpecs through two distinct
    /// boolean branches. Full Now Playing uses `prettyMode=true`; compact
    /// inspectors and the MiniPlayer use the standard branch.
    private var resolvedAppleMusicLyricsMotionProfile:
        AppleMusicLyricsMotionProfile? {
        guard model.settings.appleMusicLyricsMotionProfile != nil else {
            return nil
        }
        return compact ? .macOS26_6Standard : .macOS26_6
    }

    private var hasSyllableSyncedLyrics: Bool {
        model.lyrics.lyrics.contains(where: \.isSyllableSynced)
    }

    private func horizontalVisualOverflow(
        viewportWidth: CGFloat
    ) -> CGFloat {
        let usesTimedLyrics =
            (model.settings.lyricsWordByWord && hasSyllableSyncedLyrics)
            || (
                model.settings.lyricsPseudoWordByWord
                    && !hasSyllableSyncedLyrics
            )
        let glowOverflow = Self.lyricGlowOverflow(
            isEnabled: model.settings.lyricsGlowEnabled && usesTimedLyrics,
            fontSize: Double(
                resolvedLyricFontSize(for: viewportWidth)
            ),
            intensity: model.settings.lyricsGlowIntensity
        )
        return max(
            glowOverflow,
            SynchronizedLyricText.interactionBackgroundVisualOverflow
        )
    }

    private func viewportMaskTopOpaqueY(
        for viewportHeight: CGFloat
    ) -> CGFloat {
        guard viewportHeight.isFinite, viewportHeight > 0 else {
            return 0
        }
        let percent = resolvedAppleMusicLyricsMotionProfile?
            .viewportMaskTopOpaquePercent
            ?? Self.viewportMaskTopOpaqueFallbackPercent
        return viewportHeight
            * CGFloat(min(max(percent, 0), 100))
            / 100
    }

    private var effectiveLyricsAdvanceTime: TimeInterval {
        model.settings.effectiveLyricsAdvanceTime(
            hasSyllableSyncedLyrics: hasSyllableSyncedLyrics
        )
    }

    // The coordinator publishes only vocal-boundary changes, keeping the
    // scrolling hierarchy independent of the player's progress ticks.
    @State private var activePlaybackLyricIDs: Set<LyricLine.ID> = []

    private var interludes: [LyricInterlude] {
        guard model.settings.lyricsInterludeCountdownEnabled else {
            return []
        }
        return LyricInterludeTimeline.interludes(in: model.lyrics.lyrics)
    }

    private var interludeByID: [LyricInterlude.ID: LyricInterlude] {
        Dictionary(
            uniqueKeysWithValues: interludes.map { interlude in
                (interlude.id, interlude)
            }
        )
    }

    private var interludeByDisplayLyricID: [LyricLine.ID: LyricInterlude] {
        Dictionary(
            uniqueKeysWithValues: interludes.map { interlude in
                (interlude.displayBeforeLyricID, interlude)
            }
        )
    }

    private var focusedInterlude: LyricInterlude? {
        playbackFocus?.interludeID.flatMap { interludeByID[$0] }
    }

    /// Mirrors the mounted row order used by LyricsX's position animator. An
    /// interlude consumes a stagger slot even though its fixed row itself does
    /// not receive a lyric movement descriptor.
    private var positionCascadeLineIDs: [PositionCascadeLineID] {
        model.lyrics.lyrics.flatMap { line in
            var ids: [PositionCascadeLineID] = []
            if let interlude = interludeByDisplayLyricID[line.id] {
                ids.append(.interlude(interlude.id))
            }
            ids.append(.lyric(line.id))
            return ids
        }
    }

    private var highlightedID: LyricLine.ID? {
        if let playbackFocus {
            return playbackFocus.lyricID
        }
        return timelineHighlightedLyricID
    }

    private var requestedFocusID: String? {
        if let playbackFocus {
            return playbackFocus.interludeID ?? playbackFocus.lyricID
        }
        return highlightedID
    }

    private var visualFocusID: LyricLine.ID? {
        visualCascadeFocusLyricID
            ?? visualHighlightedLyricID
            ?? highlightedID
    }

    private var blurFocusID: LyricLine.ID? {
        visualCascadeFocusLyricID
            ?? timelineHighlightedLyricID
    }

    private var requestedScrollID: LyricLine.ID? {
        scrollRequest?.id
    }

    private var requestedFocusLyricID: LyricLine.ID? {
        playbackFocus?.lyricID
            ?? visualCascadeFocusLyricID
            ?? highlightedID
    }

    private var requestedFocusHeightOverride: CGFloat? {
        guard playbackFocus?.interludeID != nil else { return nil }
        let profile = resolvedAppleMusicLyricsMotionProfile?
            .instrumentalBreak ?? .macOS26_6
        return CGFloat(profile.viewHeight) / max(visualScale, 1)
    }

    private var preferredFocusPosition: CGFloat {
        if let profile = resolvedAppleMusicLyricsMotionProfile {
            switch profile.selectedLinePosition {
            case .center:
                return 0.5
            case .top:
                return 0
            }
        }
        return min(
            max(
                CGFloat(model.settings.lyricsFocusPosition),
                CGFloat(AppSettings.lyricsFocusPositionRange.lowerBound)
            ),
            CGFloat(AppSettings.lyricsFocusPositionRange.upperBound)
        )
    }

    /// Converts LyricsX's selected-line position into SwiftUI's shared source
    /// and destination anchor. Pretty-mode `.center` is lifted into the upper
    /// half by `focusLift`; the outer `.padding(.top:)` around the Now
    /// Playing viewport must not drag the selected line below Music's stable
    /// focus band. For `top(y)`, solve the shared fraction from the measured
    /// row height so the row's top edge lands at the recovered absolute
    /// viewport coordinate.
    private func focusPosition(
        for viewportHeight: CGFloat,
        viewportWidth proposedViewportWidth: CGFloat? = nil,
        lyricID: LyricLine.ID? = nil,
        focusedHeightOverride: CGFloat? = nil
    ) -> CGFloat {
        guard viewportHeight > 0 else {
            return preferredFocusPosition
        }

        guard let profile = resolvedAppleMusicLyricsMotionProfile else {
            return topMaskSafeFocusPosition(
                preferredFocusPosition,
                viewportHeight: viewportHeight,
                focusedHeightOverride: focusedHeightOverride
            )
        }

        guard case let .top(targetTop) = profile.selectedLinePosition else {
            let liftedCenter = 0.5
                - Double(focusLift) / Double(viewportHeight)
            return topMaskSafeFocusPosition(
                CGFloat(min(max(liftedCenter, 0), 1)),
                viewportHeight: viewportHeight,
                focusedHeightOverride: focusedHeightOverride
            )
        }

        let focusedID = lyricID ?? requestedFocusLyricID
        let resolvedFontSize = resolvedLyricFontSize(
            for: proposedViewportWidth
                ?? geometryCache.viewportSize.width
        )
        let font = NSFont.systemFont(
            ofSize: resolvedFontSize,
            weight: model.settings.effectiveAppleMusicLyricsFontWeight
                .appKitWeight
        )
        let fallbackLineHeight = ceil(
            font.ascender - font.descender + font.leading
        )
        let focusedHeight = focusedHeightOverride ?? focusedID.flatMap {
            geometryCache.layoutHeightByID[$0]
                ?? geometryCache.frameByID[$0]?.height
        } ?? fallbackLineHeight
        let availableAnchorTravel = max(
            viewportHeight - max(focusedHeight, 0),
            1
        )
        return topMaskSafeFocusPosition(
            min(
                max(CGFloat(targetTop) / availableAnchorTravel, 0),
                1
            ),
            viewportHeight: viewportHeight,
            focusedHeightOverride: focusedHeightOverride
        )
    }

    /// The resident interlude row is only 40 points tall. When a short
    /// viewport (or a custom top-aligned focus) pushes its anchor close to
    /// the top, lift it to the gradient mask's fully-opaque boundary so the
    /// prelude dots never sit inside the fade.
    private func topMaskSafeFocusPosition(
        _ baseFocusPosition: CGFloat,
        viewportHeight: CGFloat,
        focusedHeightOverride: CGFloat?
    ) -> CGFloat {
        guard !compact,
              let focusedHeight = focusedHeightOverride,
              focusedHeight > 0,
              viewportHeight > focusedHeight else {
            return baseFocusPosition
        }

        let minimumPosition = (
            viewportMaskTopOpaqueY(for: viewportHeight)
                + Self.viewportMaskTopContentClearance
        ) / (viewportHeight - focusedHeight)
        return max(
            baseFocusPosition,
            min(max(minimumPosition, 0), 1)
        )
    }

    private func focusAnchor(
        for viewportHeight: CGFloat,
        viewportWidth: CGFloat? = nil,
        lyricID: LyricLine.ID? = nil,
        focusedHeightOverride: CGFloat? = nil
    ) -> UnitPoint {
        UnitPoint(
            x: 0.5,
            y: focusPosition(
                for: viewportHeight,
                viewportWidth: viewportWidth,
                lyricID: lyricID,
                focusedHeightOverride: focusedHeightOverride
            )
        )
    }

    private var focusRequestID: String {
        "\(model.lyrics.songID.map { String($0) } ?? "none")-"
            + "\(model.lyrics.lyrics.count)-"
            + "\(requestedFocusID ?? "none")-"
            + "\(presentationFocusRequestID)-"
            + "\(isBrowsingLyrics)"
    }

    private var presentationFocusRequestID: String {
        presentationPhase.rawValue
    }

    private var presentationPhase: PresentationPhase {
        guard keepsPlaybackFocusSynchronized else { return .unmanaged }
        guard isPresented else { return .hidden }
        return isActive ? .active : .opening
    }

    private var acceptsGeometryUpdates: Bool {
        !keepsPlaybackFocusSynchronized || isPresented
    }

    private var coordinatesPlaybackFocus: Bool {
        acceptsGeometryUpdates
            && (
                isActive
                    || (keepsPlaybackFocusSynchronized && isPresented)
            )
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                // A published NetEase result is usable while automatic
                // source ranking continues in the background, just like iOS.
                if !model.lyrics.lyrics.isEmpty {
                    lyricsScrollView(viewportSize: geometry.size)
                } else if model.lyrics.isLoading {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "ui.desktop.lyrics.unavailable",
                        systemImage: "quote.bubble",
                        description: Text(
                            model.lyrics.errorMessage
                                ?? L10n.string("ui.desktop.lyrics.current_unavailable")
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onChange(of: geometry.size, initial: true) { _, size in
                let sizeChanged = geometryCache.recordViewportSize(size)
                guard acceptsGeometryUpdates, sizeChanged else { return }
                scheduleViewportAlignment(for: size.height)
            }
        }
        .onChange(of: model.lyrics.songID) { _, _ in
            resetLyricsSession()
        }
        .onChange(of: acceptsGeometryUpdates) { _, acceptsUpdates in
            guard !acceptsUpdates else { return }
            geometryCache.cancelPendingLayoutSynchronization()
            geometryCache.cancelPendingViewportSettlement()
            endViewportChange()
        }
        .onChange(of: preferredFocusPosition) { _, _ in
            guard acceptsGeometryUpdates,
                  model.settings.lyricsAutoFollow,
                  !isBrowsingLyrics,
                  let focusID = requestedFocusID
                    ?? positionedLyricID
                    ?? visualCascadeFocusLyricID else { return }
            requestScroll(to: focusID)
        }
        .onDisappear {
            browsingGeneration &+= 1
            isBrowsingLyrics = false
            geometryCache.cancelPendingLayoutSynchronization()
            geometryCache.cancelPendingViewportSettlement()
        }
        .background {
            AppleMusicLyricsFocusCoordinator(
                lyrics: model.lyrics.lyrics,
                interludes: interludes,
                isActive: coordinatesPlaybackFocus,
                playbackFocus: $playbackFocus,
                timelineHighlightedLyricID: $timelineHighlightedLyricID,
                visibleInterludeID: $visibleInterludeID,
                activePlaybackLyricIDs: $activePlaybackLyricIDs
            )
            .environment(model.player)
            .environment(model.settings)
        }
        .environment(
            \.effectiveLyricsRefreshRate,
            model.settings.lyricsRefreshRate
        )
        .environment(
            \.lyricsRenderingIsActive,
            isActive && acceptsGeometryUpdates && !isViewportChanging
        )
    }

    private func resetLyricsSession() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollRequest = nil
            isInitialFocusPrepared = false
            isViewportChanging = false
            isBrowsingLyrics = false
            browsingGeneration &+= 1
            positionedLyricID = nil
            positionedInterludeID = nil
            playbackFocus = nil
            timelineHighlightedLyricID = nil
            visibleInterludeID = nil
            visualHighlightedLyricID = nil
            lyricFocusColorTransition = nil
            visualCascadeFocusLyricID = nil
            lyricMovementOffsetByID.removeAll()
            lyricMovementTransition = nil
        }
        geometryCache.removeAllMeasurements()
    }

    private func scheduleViewportAlignment(for viewportHeight: CGFloat) {
        guard isInitialFocusPrepared else { return }
        if !isViewportChanging {
            // LyricsX treats a live viewport resize as a layout phase. Freeze
            // any in-flight line motion once, then leave the scroll position
            // alone until AppKit stops changing the viewport.
            settleMovementForViewportChange()
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isViewportChanging = true
            }
        }
        geometryCache.scheduleViewportSettlement(
            after: Self.viewportAlignmentDelay
        ) {
            finishViewportChange(viewportHeight: viewportHeight)
        }
    }

    private func endViewportChange() {
        guard isViewportChanging else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isViewportChanging = false
        }
    }

    private func settleMovementForViewportChange() {
        guard isInitialFocusPrepared,
              let transition = lyricMovementTransition else { return }

        let focusID = transition.focusID
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visualCascadeFocusLyricID = focusID
            lyricMovementOffsetByID = focusedLineFollowingOffsets(
                for: focusID
            )
            lyricMovementTransition = nil
            positionedLyricID = focusID
            positionedInterludeID = nil
        }
        updateVisualColorFocus(to: focusID)
    }

    private func currentViewportHeight(fallback: CGFloat) -> CGFloat {
        let measuredHeight = geometryCache.viewportSize.height
        guard measuredHeight.isFinite, measuredHeight > 0 else {
            return fallback
        }
        return measuredHeight
    }

    private func requestScroll(
        to id: String,
        animationDuration: TimeInterval? = nil,
        usesLineChangeSpring: Bool = false
    ) {
        scrollRequest = ScrollRequest(
            id: id,
            generation: (scrollRequest?.generation ?? 0) &+ 1,
            animationDuration: animationDuration,
            usesLineChangeSpring: usesLineChangeSpring
        )
    }

    private func isCurrentScrollRequestTarget(_ id: String) -> Bool {
        if let requestedFocusID {
            return id == requestedFocusID
        }
        if let highlightedID {
            return id == highlightedID
        }
        return id == positionedLyricID
            || id == positionedInterludeID
            || id == visualCascadeFocusLyricID
    }

    private func performAnchoredScroll(
        to id: String,
        anchor: UnitPoint,
        animationDuration: TimeInterval?,
        with proxy: ScrollViewProxy,
        viewportSize: CGSize
    ) {
        if let animationDuration {
            withAnimation(.smooth(duration: animationDuration)) {
                proxy.scrollTo(id, anchor: anchor)
            }
        } else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                proxy.scrollTo(id, anchor: anchor)
            }
        }
    }

    private func performScroll(
        _ request: ScrollRequest,
        with proxy: ScrollViewProxy,
        viewportSize: CGSize
    ) {
        // Focus tasks can overlap for one runloop turn while SwiftUI cancels
        // the previous `.task(id:)`. Never let a superseded request scroll the
        // view back to the old target.
        guard isCurrentScrollRequestTarget(request.id) else { return }

        let lyricID = model.lyrics.lyrics.first {
            $0.id == request.id
        }?.id
        let focusedHeightOverride: CGFloat? = if interludes.contains(
            where: { $0.id == request.id }
        ) {
            requestedFocusHeightOverride
                ?? CGFloat(
                    (
                        resolvedAppleMusicLyricsMotionProfile?
                            .instrumentalBreak ?? .macOS26_6
                    ).viewHeight
                ) / max(visualScale, 1)
        } else {
            nil
        }
        let anchor = focusAnchor(
            for: viewportSize.height,
            viewportWidth: viewportSize.width,
            lyricID: lyricID,
            focusedHeightOverride: focusedHeightOverride
        )
        if let duration = request.animationDuration {
            let animation = request.usesLineChangeSpring
                ? lyricLineChangeAnimation(
                    fallback: .smooth(duration: duration)
                )
                : .smooth(duration: duration)
            withAnimation(animation) {
                proxy.scrollTo(request.id, anchor: anchor)
            }
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(request.id, anchor: anchor)
        }
    }

    private func lyricsScrollView(viewportSize: CGSize) -> some View {
        // Initial positioning controls animation, not content availability.
        // Keeping loaded lyrics visible also covers clamped scroll targets.
        surfacedScrollView(viewportSize: viewportSize)
            .task(id: lyricFocusColorTransition?.id) {
                guard let lyricFocusColorTransition else { return }
                await finishFocusColorTransition(
                    lyricFocusColorTransition
                )
            }
    }

    private func finishViewportChange(
        viewportHeight: CGFloat
    ) {
        guard isViewportChanging, acceptsGeometryUpdates else {
            endViewportChange()
            return
        }
        synchronizeStationaryFollowingOffsets()
        if isActive,
           model.settings.lyricsAutoFollow,
           !isBrowsingLyrics {
            realignPlaybackFocusAfterViewportChange(
                viewportHeight: viewportHeight
            )
        }
        endViewportChange()
    }

    private func realignPlaybackFocusAfterViewportChange(
        viewportHeight proposedViewportHeight: CGFloat
    ) {
        guard let focusID = requestedFocusID
                ?? positionedLyricID
                ?? visualCascadeFocusLyricID else { return }

        let isLyricFocus = playbackFocus?.interludeID == nil
        let viewportHeight = currentViewportHeight(
            fallback: proposedViewportHeight
        )
        let resolvedFocusPosition = focusPosition(
            for: viewportHeight,
            lyricID: playbackFocus?.lyricID,
            focusedHeightOverride: requestedFocusHeightOverride
        )
        let viewportAnchorY = viewportHeight * resolvedFocusPosition
        if isLyricFocus,
           isFocusAligned(
               id: focusID,
               viewportAnchorY: viewportAnchorY,
               focusPosition: resolvedFocusPosition
           ) {
            return
        }
        requestScroll(to: focusID)
    }

    private func finishInitialFocusPreparation(
        at id: LyricLine.ID?,
        waitsForLyricGeometry: Bool,
        viewportHeight: CGFloat
    ) async {
        await Task.yield()
        guard !Task.isCancelled else { return }

        if waitsForLyricGeometry, let id {
            _ = await waitForLyricFrame(id: id)
            guard !Task.isCancelled else { return }
            _ = await ensureFocusAlignment(
                to: id,
                viewportHeight: viewportHeight,
                animated: false,
                forcesScrollTargetReapplication: true
            )
        } else if let id {
            guard await reapplyScrollTarget(id) else { return }
        } else {
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return
            }
        }
        guard !Task.isCancelled else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isInitialFocusPrepared = true
        }
    }

    private func prepareFocusForPresentationIfNeeded() async -> Bool {
        switch presentationPhase {
        case .unmanaged, .active:
            return false

        case .opening:
            settlePresentationTransitions()
            return true

        case .hidden:
            return true
        }
    }

    private func settlePresentationTransitions() {
        let settledFocusID = lyricMovementTransition?.focusID
            ?? positionedLyricID
            ?? visualCascadeFocusLyricID
        let settledOffsets = focusedLineFollowingOffsets(
            for: settledFocusID
        )
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricFocusColorTransition = nil
            lyricMovementTransition = nil
            if positionedInterludeID != nil, settledFocusID == nil {
                visualCascadeFocusLyricID = nil
                lyricMovementOffsetByID.removeAll()
            } else {
                visualCascadeFocusLyricID = settledFocusID
                lyricMovementOffsetByID = settledOffsets
            }
        }
    }

    private func reapplyScrollTarget(_ id: String) async -> Bool {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            requestScroll(to: id)
        }
        await Task.yield()
        guard !Task.isCancelled else { return false }
        do {
            try await Task.sleep(for: .milliseconds(16))
        } catch {
            return false
        }
        return !Task.isCancelled
    }

    private func prepareInitialFocus(at id: LyricLine.ID) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            requestScroll(to: id)
            positionedLyricID = id
            positionedInterludeID = nil
            visualHighlightedLyricID = id
            lyricFocusColorTransition = nil
            visualCascadeFocusLyricID = id
            lyricMovementOffsetByID = focusedLineFollowingOffsets(for: id)
            lyricMovementTransition = nil
        }
    }

    private func prepareInitialFocus(at interlude: LyricInterlude) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            requestScroll(to: interlude.id)
            positionedLyricID = interlude.precedingLyricID
            positionedInterludeID = interlude.id
            visualHighlightedLyricID = nil
            lyricFocusColorTransition = nil
            visualCascadeFocusLyricID = nil
            lyricMovementOffsetByID.removeAll()
            lyricMovementTransition = nil
        }
    }

    private func waitForLyricFrame(id: LyricLine.ID) async -> Bool {
        for attempt in 0..<30 {
            if geometryCache.frameByID[id] != nil {
                return true
            }
            guard !Task.isCancelled, attempt < 29 else { return false }
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return false
            }
        }
        return false
    }

    private func movePlaybackFocus(
        to interlude: LyricInterlude
    ) async {
        guard !isBrowsingLyrics else {
            settlePlaybackFocusDuringBrowsing(at: interlude)
            return
        }
        guard positionedInterludeID != interlude.id
                || requestedScrollID != interlude.id else { return }

        let animationDuration: TimeInterval? = if reduceMotion
                || !isActive
                || isViewportChanging
                || requestedScrollID == nil {
            nil
        } else {
            0.5
        }
        lyricMovementTransition = nil
        lyricMovementOffsetByID.removeAll()
        updateVisualColorFocus(to: nil)
        let animation = animationDuration.map {
            Animation.smooth(duration: $0)
        }
        withAnimation(animation) {
            visualCascadeFocusLyricID = nil
        }
        requestScroll(
            to: interlude.id,
            animationDuration: animationDuration
        )
        positionedLyricID = interlude.precedingLyricID
        positionedInterludeID = interlude.id
        await Task.yield()
    }

    private func movePlaybackFocus(
        to highlightedID: LyricLine.ID,
        viewportHeight proposedViewportHeight: CGFloat,
        scrollProxy: ScrollViewProxy? = nil,
        viewportSize: CGSize? = nil
    ) async {
        let viewportHeight = currentViewportHeight(
            fallback: proposedViewportHeight
        )
        let handsOffFromInterlude = isInterludeHandoff(
            to: highlightedID
        )
        guard !isBrowsingLyrics else {
            settlePlaybackFocusDuringBrowsing(at: highlightedID)
            return
        }
        if handsOffFromInterlude {
            guard model.settings.lyricsAutoFollow else {
                updateVisualFocus(to: highlightedID)
                synchronizeStationaryFollowingOffsets()
                positionedLyricID = highlightedID
                positionedInterludeID = nil
                return
            }
            await moveFocusFromInterlude(
                to: highlightedID,
                viewportHeight: viewportHeight,
                scrollProxy: scrollProxy,
                viewportSize: viewportSize
            )
            return
        }
        let resolvedFocusPosition = focusPosition(
            for: viewportHeight,
            lyricID: highlightedID
        )
        guard positionedLyricID != highlightedID else {
            let viewportAnchorY = viewportHeight * resolvedFocusPosition
            guard !isFocusAligned(
                        id: highlightedID,
                        viewportAnchorY: viewportAnchorY,
                        focusPosition: resolvedFocusPosition
                    ) else {
                return
            }
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight
            )
            return
        }

        let movementOriginLyricID: LyricLine.ID
        if let positionedLyricID {
            movementOriginLyricID = positionedLyricID
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                requestScroll(to: highlightedID)
                visualHighlightedLyricID = highlightedID
                lyricFocusColorTransition = nil
                visualCascadeFocusLyricID = highlightedID
                lyricMovementOffsetByID = focusedLineFollowingOffsets(
                    for: highlightedID
                )
                lyricMovementTransition = nil
            }
            await Task.yield()
            self.positionedLyricID = highlightedID
            return
        }

        guard model.settings.lyricsAutoFollow else {
            updateVisualFocus(to: highlightedID)
            synchronizeStationaryFollowingOffsets()
            self.positionedLyricID = highlightedID
            return
        }

        let motionProfile = resolvedAppleMusicLyricsMotionProfile
        guard isActive,
              !isViewportChanging,
              !reduceMotion,
              motionProfile != nil
                || isForwardAdjacentTransition(
                    from: movementOriginLyricID,
                    to: highlightedID
                ),
              let highlightedIndex = model.lyrics.lyrics.firstIndex(
                where: { $0.id == highlightedID }
              ) else {
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight
            )
            return
        }

        // LyricsX does not estimate an off-screen target row.  It waits for
        // its measured frame, then uses that frame for the one scroll
        // compensation.  The desktop average-height fallback produced a
        // second correction when real geometry arrived.
        let nextFocusFrame: CGRect?
        if motionProfile != nil {
            guard await waitForLyricFrame(id: highlightedID),
                  !Task.isCancelled,
                  self.highlightedID == highlightedID else {
                return
            }
            nextFocusFrame = geometryCache.frameByID[highlightedID]
        } else {
            nextFocusFrame = focusFrame(
                for: highlightedID,
                from: movementOriginLyricID
            )
        }
        guard let nextFocusFrame else {
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight
            )
            return
        }

        let focusAnchorY = viewportHeight * resolvedFocusPosition
        let nextFocusAnchorY = nextFocusFrame.minY
            + nextFocusFrame.height * resolvedFocusPosition
        let movementDistance = nextFocusAnchorY - focusAnchorY
        guard movementDistance.isFinite,
              abs(movementDistance) > 0.5 else {
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight
            )
            return
        }

        if let motionProfile {
            await animateAppleMusicCascade(
                from: movementOriginLyricID,
                to: highlightedID,
                animationOriginID: .lyric(movementOriginLyricID),
                movementDistance: movementDistance,
                viewportHeight: viewportHeight,
                profile: motionProfile
            )
            return
        }

        let firstChasingIndex = max(
            highlightedIndex - 1,
            model.lyrics.lyrics.startIndex
        )
        let maximumChaseOrder = min(
            max(
                model.lyrics.lyrics.index(before: model.lyrics.lyrics.endIndex)
                    - firstChasingIndex,
                0
            ),
            12
        )
        let baseDuration = LyricPlaybackTimeline.focusAnimationDuration(
            for: highlightedID,
            in: model.lyrics.lyrics
        )
        let cascadeDuration = LyricPlaybackTimeline.focusCascadeAnimationDuration(
            baseDuration: baseDuration,
            preferredDuration: model.settings.lyricsFocusCascadeDuration
        )
        let playbackTime = model.player.estimatedProgress()
            + effectiveLyricsAdvanceTime
        let remainingDuration = LyricPlaybackTimeline.remainingFocusDuration(
            for: highlightedID,
            at: playbackTime,
            in: model.lyrics.lyrics
        )
        let focusColorLeadTime = min(
            max(
                model.settings.lyricsFocusColorLeadTime,
                AppSettings.lyricsFocusColorLeadTimeRange.lowerBound
            ),
            AppSettings.lyricsFocusColorLeadTimeRange.upperBound
        )
        guard let cascadeTiming = LyricPlaybackTimeline.focusCascadeTiming(
            maximumLineOrder: maximumChaseOrder,
            preferredDelayPerLine: model.settings.lyricsFocusCascadeDelay,
            preferredDelayIncreasePerLine:
                model.settings.lyricsFocusCascadeDelayIncrease,
            followingLineBaseDelay:
                model.settings.lyricsFocusCascadeFollowingDelay,
            preferredCatchUpCompletionRatio:
                model.settings.lyricsFocusCascadeCatchUpRatio,
            focusColorLeadTime: focusColorLeadTime,
            baseAnimationDuration: baseDuration,
            preferredAnimationDuration: cascadeDuration,
            prefersBounce: model.settings.lyricsFocusCascadeBounceEnabled,
            snapThreshold: model.settings.lyricsFocusSnapThreshold,
            remainingDuration: remainingDuration
        ) else {
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight
            )
            return
        }

        let transitionDate = Date.now
        let carriedPresentations = lyricMovementTransition?
            .presentationStates(at: transitionDate) ?? [:]
        var carriedOffsets = lyricMovementOffsetByID
        carriedOffsets.merge(
            carriedPresentations.mapValues(\.offset),
            uniquingKeysWith: { _, presentationOffset in
                presentationOffset
            }
        )
        let carriedVelocities = carriedPresentations.mapValues(\.velocity)
        let destinationOffsets = focusedLineFollowingOffsets(
            for: highlightedID
        )
        let preparedOffsets = Dictionary(
            uniqueKeysWithValues: model.lyrics.lyrics.map { line in
                (
                    line.id,
                    movementDistance
                        + carriedOffsets[line.id, default: 0]
                )
            }
        )
        let preparedTransition = LyricMovementTransition(
            focusID: highlightedID,
            initialOffsetsByID: preparedOffsets,
            destinationOffsetsByID: destinationOffsets
        )
        var preparation = Transaction()
        preparation.disablesAnimations = true
        withTransaction(preparation) {
            lyricMovementOffsetByID = preparedOffsets
            lyricMovementTransition = preparedTransition
            requestScroll(to: highlightedID)
        }
        self.positionedLyricID = highlightedID
        await Task.yield()
        let destinationIsPrepared = await waitForPreparedFocus(
            id: highlightedID,
            viewportHeight: viewportHeight
        )
        guard !Task.isCancelled,
              lyricMovementTransition?.id == preparedTransition.id else {
            return
        }
        guard destinationIsPrepared else {
            completeCascadeMovement(to: highlightedID)
            _ = await ensureFocusAlignment(
                to: highlightedID,
                viewportHeight: viewportHeight,
                animated: false
            )
            return
        }

        let chaseSpeedGradient = min(
            max(
                model.settings.lyricsFocusCascadeChaseSpeedGradient,
                AppSettings
                    .lyricsFocusCascadeChaseSpeedGradientRange.lowerBound
            ),
            AppSettings.lyricsFocusCascadeChaseSpeedGradientRange.upperBound
        )
        let slowestDuration = cascadeTiming.lineTiming(for: 0).duration
        let movementAnimations = Dictionary(
            uniqueKeysWithValues:
                model.lyrics.lyrics.enumerated().map { index, line in
                    let movementOrder = min(
                        max(index - highlightedIndex, 0),
                        maximumChaseOrder
                    )
                    let chaseOrder = min(
                        max(index - firstChasingIndex, 0),
                        maximumChaseOrder
                    )
                    let movementTiming = cascadeTiming.lineTiming(
                        for: movementOrder
                    )
                    let chaseTiming = cascadeTiming.lineTiming(
                        for: chaseOrder
                    )
                    let duration = slowestDuration
                        + (chaseTiming.duration - slowestDuration)
                            * chaseSpeedGradient
                    let destinationOffset = destinationOffsets[
                        line.id,
                        default: 0
                    ]
                    let initialOffset = preparedOffsets[
                        line.id,
                        default: destinationOffset
                    ]
                    let distance = destinationOffset - initialOffset
                    let rawVelocity = abs(distance) > 0.5
                        ? Double(
                            carriedVelocities[line.id, default: 0]
                                / distance
                        )
                        : 0
                    let initialVelocity = rawVelocity.isFinite
                        ? min(max(rawVelocity, -12), 12)
                        : 0
                    return (
                        line.id,
                        LyricMovementAnimationConfiguration(
                            delay: movementTiming.delay,
                            duration: duration,
                            usesBounce: cascadeTiming.usesBounce,
                            bounce: lyricFocusCascadeBounce(
                                chaseOrder: chaseOrder,
                                maximumChaseOrder: maximumChaseOrder
                            ),
                            initialVelocity: initialVelocity
                        )
                    )
                }
        )

        if focusColorLeadTime >= 0 {
            updateVisualColorFocus(to: highlightedID)
        }
        if focusColorLeadTime > 0 {
            try? await Task.sleep(for: .seconds(focusColorLeadTime))
        }
        guard !Task.isCancelled,
              self.highlightedID == highlightedID,
              lyricMovementTransition?.id == preparedTransition.id else {
            return
        }

        let startedTransition = preparedTransition.starting(
            with: movementAnimations,
            at: .now
        )
        var movementTransaction = Transaction(animation: nil)
        movementTransaction.disablesAnimations = true
        withTransaction(movementTransaction) {
            lyricMovementTransition = startedTransition
            lyricMovementOffsetByID = destinationOffsets
        }
        visualCascadeFocusLyricID = highlightedID

        if focusColorLeadTime < 0 {
            try? await Task.sleep(
                for: .seconds(max(-focusColorLeadTime, 0))
            )
            guard !Task.isCancelled,
                  self.highlightedID == highlightedID else { return }
            updateVisualColorFocus(to: highlightedID)
        }

        let elapsed = startedTransition.startedAt.map {
            Date.now.timeIntervalSince($0)
        } ?? 0
        let completionDuration = max(
            startedTransition.completionDuration - elapsed,
            0
        )
        // Extra grace lets the last TimelineView frame reach the exact
        // destination before the movement phase switches back to stationary
        // values, avoiding the one-frame downward snap reported at the end
        // of a line-change cascade.
        try? await Task.sleep(
            for: .seconds(completionDuration + 0.05)
        )
        guard !Task.isCancelled,
              self.highlightedID == highlightedID,
              lyricMovementTransition?.id == startedTransition.id else {
            return
        }
        completeCascadeMovement(to: highlightedID)
    }

    private func animateAppleMusicCascade(
        from previousID: LyricLine.ID?,
        to highlightedID: LyricLine.ID,
        animationOriginID: PositionCascadeLineID,
        movementDistance: CGFloat,
        viewportHeight: CGFloat,
        profile: AppleMusicLyricsMotionProfile,
        usesTimedWordSourceSpring: Bool = true
    ) async {
        let transitionDate = Date.now
        let carriedPresentations = lyricMovementTransition?
            .presentationStates(at: transitionDate) ?? [:]
        var carriedOffsets = lyricMovementOffsetByID
        carriedOffsets.merge(
            carriedPresentations.mapValues(\.offset),
            uniquingKeysWith: { _, presentation in presentation }
        )
        let initialMountedIDs = Set(geometryCache.frameByID.keys)
        let initialMountedInterludeIDs = Set(
            geometryCache.interludeFrameByID.keys
        )
        let initialVisibleIDs = Set(
            geometryCache.frameByID.compactMap { id, frame in
                Self.isVisibleLyricFrame(
                    frame,
                    movementOffset: carriedOffsets[id, default: 0],
                    viewportHeight: viewportHeight
                ) ? id : nil
            }
        )
        let initialVisibleInterludeIDs = Set(
            geometryCache.interludeFrameByID.compactMap { id, frame in
                Self.isVisibleLyricFrame(
                    frame,
                    viewportHeight: viewportHeight
                ) ? id : nil
            }
        )
        let destinationOffsets = focusedLineFollowingOffsets(
            for: highlightedID
        )
        let preparedOffsets = Dictionary(
            uniqueKeysWithValues: model.lyrics.lyrics.map { line in
                (
                    line.id,
                    movementDistance
                        + carriedOffsets[line.id, default: 0]
                )
            }
        )
        let preparedTransition = LyricMovementTransition(
            focusID: highlightedID,
            initialOffsetsByID: preparedOffsets,
            destinationOffsetsByID: destinationOffsets
        )

        var preparation = Transaction(animation: nil)
        preparation.disablesAnimations = true
        withTransaction(preparation) {
            lyricMovementOffsetByID = preparedOffsets
            lyricMovementTransition = preparedTransition
            requestScroll(to: highlightedID)
        }
        positionedLyricID = highlightedID
        await Task.yield()

        let destinationIsPrepared = await waitForPreparedFocus(
            id: highlightedID,
            viewportHeight: viewportHeight
        )
        guard !Task.isCancelled,
              lyricMovementTransition?.id == preparedTransition.id else {
            return
        }
        guard destinationIsPrepared else {
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight
            )
            return
        }

        let targetMountedIDs = Set(geometryCache.frameByID.keys)
        let targetMountedInterludeIDs = Set(
            geometryCache.interludeFrameByID.keys
        )
        let targetVisibleIDs = Set(
            geometryCache.frameByID.compactMap { id, frame in
                Self.isVisibleLyricFrame(
                    frame,
                    viewportHeight: viewportHeight
                ) ? id : nil
            }
        )
        let targetVisibleInterludeIDs = Set(
            geometryCache.interludeFrameByID.compactMap { id, frame in
                Self.isVisibleLyricFrame(
                    frame,
                    viewportHeight: viewportHeight
                ) ? id : nil
            }
        )
        let mountedLyricIDs = initialMountedIDs.union(targetMountedIDs)
        let mountedInterludeIDs = initialMountedInterludeIDs.union(
            targetMountedInterludeIDs
        )
        let mountedIDsInLyricOrder = positionCascadeLineIDs.filter { id in
            switch id {
            case let .lyric(lyricID):
                mountedLyricIDs.contains(lyricID)
            case let .interlude(interludeID):
                mountedInterludeIDs.contains(interludeID)
            }
        }
        let plan = AppleMusicLyricsLinePositionPlanner.plan(
            mountedIDsInLyricOrder: mountedIDsInLyricOrder,
            currentViewportIDs: Set(
                initialVisibleIDs.map(PositionCascadeLineID.lyric)
                    + initialVisibleInterludeIDs.map(
                        PositionCascadeLineID.interlude
                    )
            ),
            targetViewportIDs: Set(
                targetVisibleIDs.map(PositionCascadeLineID.lyric)
                    + targetVisibleInterludeIDs.map(
                        PositionCascadeLineID.interlude
                    )
            ),
            animationOriginID: animationOriginID,
            contentOffsetDelta: Double(movementDistance),
            profile: profile
        )
        guard !plan.isEmpty else {
            completeCascadeMovement(to: highlightedID)
            return
        }

        let physicalSpring: LyricPhysicalSpringParameters
        if usesTimedWordSourceSpring,
           let previousID,
           let sourceDuration = appleMusicTimedWordTransitionSourceDuration(
               from: previousID,
               to: highlightedID
           ) {
            physicalSpring = profile.dynamicSpring(
                sourceDuration: sourceDuration
            )
        } else {
            physicalSpring = profile.lineChangeSpring
        }
        let movementAnimations: [
            LyricLine.ID: LyricMovementAnimationConfiguration
        ] = Dictionary(
            uniqueKeysWithValues: plan.compactMap { plannedLine -> (
                LyricLine.ID,
                LyricMovementAnimationConfiguration
            )? in
                guard case let .lyric(lyricID) = plannedLine.id else {
                    return nil
                }
                let destination = destinationOffsets[
                    lyricID,
                    default: 0
                ]
                let initial = preparedOffsets[
                    lyricID,
                    default: destination
                ]
                guard destination != initial else { return nil }
                return (
                    lyricID,
                    LyricMovementAnimationConfiguration(
                        delay: plannedLine.delay,
                        duration: 0,
                        physicalSpring: physicalSpring,
                        // The recovered LyricsX descriptor always starts
                        // this line-position path at zero velocity. Carrying
                        // the prior SwiftUI presentation velocity gives the
                        // old focused row a second, unsupported movement.
                        initialVelocity: 0
                    )
                )
            }
        )
        guard !movementAnimations.isEmpty else {
            completeCascadeMovement(to: highlightedID)
            return
        }

        updateVisualColorFocus(to: highlightedID)
        let startedTransition = preparedTransition.starting(
            with: movementAnimations,
            at: .now
        )
        var movementTransaction = Transaction(animation: nil)
        movementTransaction.disablesAnimations = true
        withTransaction(movementTransaction) {
            lyricMovementTransition = startedTransition
            lyricMovementOffsetByID = destinationOffsets
        }
        visualCascadeFocusLyricID = highlightedID

        let elapsed = startedTransition.startedAt.map {
            Date.now.timeIntervalSince($0)
        } ?? 0
        let remaining = max(
            startedTransition.completionDuration - elapsed,
            0
        ) + 0.05
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }
        guard !Task.isCancelled,
              self.highlightedID == highlightedID,
              lyricMovementTransition?.id == startedTransition.id else {
            return
        }
        completeCascadeMovement(to: highlightedID)
    }

    private func appleMusicTimedWordTransitionSourceDuration(
        from previousID: LyricLine.ID,
        to highlightedID: LyricLine.ID
    ) -> TimeInterval? {
        guard let previousLine = model.lyrics.lyrics.first(
            where: { $0.id == previousID }
        ), let highlightedLine = model.lyrics.lyrics.first(
            where: { $0.id == highlightedID }
        ), previousLine.isSyllableSynced,
           highlightedLine.isSyllableSynced,
           let previousDuration = previousLine.duration,
           previousDuration.isFinite,
           previousDuration >= 0 else { return nil }

        let sourceDuration = highlightedLine.time
            - (previousLine.time + previousDuration)
        return sourceDuration.isFinite ? sourceDuration : nil
    }

    private func focusFrame(
        for targetID: LyricLine.ID,
        from originID: LyricLine.ID
    ) -> CGRect? {
        if let frame = geometryCache.frameByID[targetID] {
            return frame
        }
        guard let originFrame = geometryCache.frameByID[originID],
              let originIndex = model.lyrics.lyrics.firstIndex(
                where: { $0.id == originID }
              ),
              let targetIndex = model.lyrics.lyrics.firstIndex(
                where: { $0.id == targetID }
              ) else { return nil }

        let measuredHeights = geometryCache.layoutHeightByID.values
        let averageHeight = measuredHeights.isEmpty
            ? lyricFontSize * 1.2
            : measuredHeights.reduce(0, +)
                / CGFloat(measuredHeights.count)
        let stride = averageHeight
            + CGFloat(
                resolvedAppleMusicLyricsMotionProfile?.lineSpacing
                    ?? model.settings.lyricsLineSpacing
            )
        let indexDistance = CGFloat(targetIndex - originIndex)
        return CGRect(
            x: originFrame.minX,
            y: originFrame.minY + stride * indexDistance,
            width: originFrame.width,
            height: averageHeight
        )
    }

    nonisolated private static func isVisibleLyricFrame(
        _ frame: CGRect,
        movementOffset: CGFloat = 0,
        viewportHeight: CGFloat
    ) -> Bool {
        !frame.isNull
            && !frame.isInfinite
            && !frame.isEmpty
            && frame.maxY + movementOffset > 0
            && frame.minY + movementOffset < viewportHeight
    }

    private func lyricFocusCascadeBounce(
        chaseOrder: Int,
        maximumChaseOrder: Int
    ) -> Double {
        let maximumBounce = min(
            max(
                model.settings.lyricsFocusCascadeBounce,
                AppSettings.lyricsFocusCascadeBounceRange.lowerBound
            ),
            AppSettings.lyricsFocusCascadeBounceRange.upperBound
        )
        let bounceGradient = min(
            max(
                model.settings.lyricsFocusCascadeBounceGradient,
                AppSettings.lyricsFocusCascadeBounceGradientRange.lowerBound
            ),
            AppSettings.lyricsFocusCascadeBounceGradientRange.upperBound
        )
        let linePosition = min(
            max(chaseOrder, 0),
            maximumChaseOrder
        ) + 1
        let normalizedPosition = Double(linePosition)
            / Double(max(maximumChaseOrder + 1, 1))
        let bounceScale = 1
            - (1 - normalizedPosition) * bounceGradient
        return maximumBounce * bounceScale
    }

    private func isForwardAdjacentTransition(
        from currentID: LyricLine.ID,
        to nextID: LyricLine.ID
    ) -> Bool {
        guard let currentIndex = model.lyrics.lyrics.firstIndex(
                where: { $0.id == currentID }
              ),
              let nextIndex = model.lyrics.lyrics.firstIndex(
                where: { $0.id == nextID }
              ) else { return false }
        return nextIndex == currentIndex + 1
    }

    private func isInterludeHandoff(
        to highlightedID: LyricLine.ID
    ) -> Bool {
        // `visibleInterludeID` is a presentation detail: the indicator can
        // become visually empty before (or in the same update as) the focus
        // promotion. LyricsX retains the positioned instrumental view until
        // its source-to-destination scroll transaction has been committed.
        // Use that committed position first so the handoff cannot fall into
        // the ordinary lyric-to-lyric path when the dots have just vanished.
        let handoffInterludeID = positionedInterludeID ?? visibleInterludeID
        let handoffInterlude = handoffInterludeID.flatMap {
            interludeByID[$0]
        }
        return handoffInterlude?.followingLyricID == highlightedID
    }

    /// Indicator-to-lyric handoff. The dots are already visually gone when
    /// the timeline promotes the following lyric, so use the reliable
    /// non-cascade path: clear the interlude presentation, scroll the next
    /// lyric into the focus anchor, then run the normal color/offset
    /// transition. This must never be skipped, or the empty indicator row
    /// keeps focus until the next lyric forces a regular transition.
    private func moveFocusFromInterlude(
        to highlightedID: LyricLine.ID,
        viewportHeight: CGFloat,
        scrollProxy: ScrollViewProxy? = nil,
        viewportSize: CGSize? = nil
    ) async {
        let handoffInterludeID = positionedInterludeID
            ?? visibleInterludeID
        guard let handoffInterludeID,
              let handoffInterlude = interludeByID[
                  handoffInterludeID
              ],
              handoffInterlude.followingLyricID == highlightedID else {
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight,
                scrollProxy: scrollProxy,
                viewportSize: viewportSize
            )
            return
        }

        // Give the indicator's TimelineView one display frame to commit its
        // hidden presentation before the resident row starts moving.
        await Task.yield()
        guard !Task.isCancelled,
              self.highlightedID == highlightedID else {
            return
        }

        // Drop the stale frame that may still describe the lyric's position
        // from before the interlude took focus. Otherwise alignment checks
        // can accept an old measurement and skip the handoff scroll entirely.
        let resolvedFocusPosition = focusPosition(
            for: viewportHeight,
            lyricID: highlightedID
        )
        let nextLyricHeight = geometryCache.layoutHeightByID[
            highlightedID
        ] ?? geometryCache.frameByID[highlightedID]?.height
            ?? lyricFontSize * 1.2
        geometryCache.removeMeasurements(for: highlightedID)

        // Start the color handoff before the scroll commits so the next lyric
        // is already gaining focus while it travels into the anchor.
        updateVisualColorFocus(to: highlightedID)

        // Use the interlude row (which is definitely mounted) as the scroll
        // target, but compensate the anchor so the *following lyric* lands on
        // the focus position. This avoids trusting the interlude's own anchor
        // and also works when the next lyric is not realized by LazyVStack.
        if let scrollProxy, let viewportSize {
            let interludeProfile =
                resolvedAppleMusicLyricsMotionProfile?
                    .instrumentalBreak ?? .macOS26_6
            let interludeHeight = CGFloat(interludeProfile.viewHeight)
                / max(visualScale, 1)
            let lineSpacing = DesktopLyricsLayoutMetrics.lineSpacing(
                setting:
                    resolvedAppleMusicLyricsMotionProfile?.lineSpacing
                        ?? model.settings.lyricsLineSpacing,
                compact: compact,
                usesAppleMusicMotion:
                    resolvedAppleMusicLyricsMotionProfile != nil
            )
            let availableTravel = viewportHeight - interludeHeight
            let interludeAnchorY: CGFloat = if availableTravel > 1 {
                (
                    resolvedFocusPosition * viewportHeight
                        - interludeHeight
                        - lineSpacing
                        - resolvedFocusPosition * nextLyricHeight
                ) / availableTravel
            } else {
                0
            }
            performAnchoredScroll(
                to: handoffInterludeID,
                anchor: UnitPoint(
                    x: 0.5,
                    y: min(max(interludeAnchorY, -2), 3)
                ),
                animationDuration: reduceMotion ? nil : 0.34,
                with: scrollProxy,
                viewportSize: viewportSize
            )
            _ = await waitForPreparedFocus(
                id: highlightedID,
                viewportHeight: viewportHeight
            )
            guard !Task.isCancelled,
                  self.highlightedID == highlightedID else {
                return
            }
        }

        await moveFocusWithoutCascade(
            to: highlightedID,
            viewportHeight: viewportHeight,
            scrollProxy: scrollProxy,
            viewportSize: viewportSize,
            forcesScrollTargetReapplication: false
        )
    }

    private func waitForPreparedFocus(
        id: LyricLine.ID,
        viewportHeight proposedViewportHeight: CGFloat
    ) async -> Bool {
        for attempt in 0..<30 {
            let viewportHeight = currentViewportHeight(
                fallback: proposedViewportHeight
            )
            let resolvedFocusPosition = focusPosition(
                for: viewportHeight,
                lyricID: id
            )
            let viewportAnchorY = viewportHeight * resolvedFocusPosition
            if let frame = geometryCache.frameByID[id] {
                let preparedAnchorY = frame.minY
                    + frame.height * resolvedFocusPosition
                if abs(preparedAnchorY - viewportAnchorY) <= 2 {
                    return true
                }
            }
            guard !Task.isCancelled, attempt < 29 else { return false }
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return false
            }
        }
        return false
    }

    private func completeCascadeMovement(to id: LyricLine.ID) {
        let finalOffsets = focusedLineFollowingOffsets(for: id)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visualCascadeFocusLyricID = id
            lyricMovementOffsetByID = finalOffsets
            lyricMovementTransition = nil
            positionedLyricID = id
            positionedInterludeID = nil
        }
        updateVisualColorFocus(to: id)
    }

    private func resetPlaybackFocus() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visualHighlightedLyricID = nil
            visualCascadeFocusLyricID = nil
            lyricFocusColorTransition = nil
            lyricMovementOffsetByID.removeAll()
            lyricMovementTransition = nil
            positionedLyricID = nil
            positionedInterludeID = nil
        }
    }

    /// Mirrors LyricsX's non-cascade fallback: first freeze the completed
    /// presentation at the current focus, then move the scroll container, and
    /// finally commit one destination offset set with the line-change spring.
    private func resetMovementOffsets() {
        let focusID = visualCascadeFocusLyricID
            ?? playbackFocus?.lyricID
            ?? highlightedID
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementOffsetByID = focusedLineFollowingOffsets(
                for: focusID
            )
            lyricMovementTransition = nil
        }
    }

    private func moveFocusWithoutCascade(
        to highlightedID: LyricLine.ID,
        viewportHeight: CGFloat,
        scrollProxy: ScrollViewProxy? = nil,
        viewportSize: CGSize? = nil,
        forcesScrollTargetReapplication: Bool = false
    ) async {
        let duration = LyricPlaybackTimeline.focusAnimationDuration(
            for: highlightedID,
            in: model.lyrics.lyrics
        )
        resetMovementOffsets()
        let isFocusPrepared = await ensureFocusAlignment(
            to: highlightedID,
            viewportHeight: viewportHeight,
            animated: true,
            animationDuration: max(duration, 0.34),
            scrollProxy: scrollProxy,
            viewportSize: viewportSize,
            forcesScrollTargetReapplication:
                forcesScrollTargetReapplication
        )
        if !isFocusPrepared {
            // Last-resort state-driven request. The direct proxy path above
            // covers the handoff, but keeping the existing request path as a
            // fallback guarantees the scroll target is still applied.
            requestScroll(to: highlightedID)
            _ = await waitForPreparedFocus(
                id: highlightedID,
                viewportHeight: viewportHeight
            )
        }
        await Task.yield()
        guard !Task.isCancelled else { return }
        let destinationOffsets = focusedLineFollowingOffsets(
            for: highlightedID
        )
        updateVisualColorFocus(to: highlightedID)
        withAnimation(
            reduceMotion
                ? nil
                : lyricLineChangeAnimation(
                    fallback: .easeInOut(duration: duration)
                )
        ) {
            visualCascadeFocusLyricID = highlightedID
            lyricMovementOffsetByID = destinationOffsets
        }
        positionedLyricID = highlightedID
        positionedInterludeID = nil
    }

    private func lyricLineChangeAnimation(
        fallback: Animation
    ) -> Animation {
        guard let spring = resolvedAppleMusicLyricsMotionProfile?
            .lineChangeSpring else {
            return fallback
        }
        return .interpolatingSpring(
            mass: spring.mass,
            stiffness: spring.stiffness,
            damping: spring.damping,
            initialVelocity: 0
        )
    }

    private func ensureFocusAlignment(
        to id: LyricLine.ID,
        viewportHeight proposedViewportHeight: CGFloat,
        animated: Bool,
        animationDuration: TimeInterval? = nil,
        scrollProxy: ScrollViewProxy? = nil,
        viewportSize: CGSize? = nil,
        forcesScrollTargetReapplication: Bool = false
    ) async -> Bool {
        let viewportHeight = currentViewportHeight(
            fallback: proposedViewportHeight
        )
        let resolvedFocusPosition = focusPosition(
            for: viewportHeight,
            lyricID: id
        )
        let viewportAnchorY = viewportHeight * resolvedFocusPosition
        if !forcesScrollTargetReapplication,
           isFocusAligned(
               id: id,
               viewportAnchorY: viewportAnchorY,
               focusPosition: resolvedFocusPosition
           ) {
            return true
        }

        for attempt in 0..<3 {
            guard !Task.isCancelled else { return false }

            let duration = animationDuration
                ?? LyricPlaybackTimeline.focusAnimationDuration(
                    for: id,
                    in: model.lyrics.lyrics
                )
            let requestAnimationDuration = animated
                    && attempt == 0
                    && !reduceMotion
                    && isActive
                    && !isViewportChanging
                ? duration
                : nil
            if let scrollProxy, let viewportSize {
                // The handoff runs inside the ScrollViewReader task, so drive
                // the proxy directly instead of waiting for a `scrollRequest`
                // state round-trip. This keeps the first post-indicator lyric
                // moving even when the pending state update is coalesced away.
                performScroll(
                    ScrollRequest(
                        id: id,
                        generation: (scrollRequest?.generation ?? 0)
                            &+ 1,
                        animationDuration: requestAnimationDuration,
                        usesLineChangeSpring: false
                    ),
                    with: scrollProxy,
                    viewportSize: viewportSize
                )
            } else {
                requestScroll(
                    to: id,
                    animationDuration: requestAnimationDuration
                )
            }
            await Task.yield()
            guard !Task.isCancelled else { return false }
            if await waitForPreparedFocus(
                id: id,
                viewportHeight: viewportHeight
            ) {
                return true
            }
        }
        return isFocusAligned(
            id: id,
            viewportAnchorY: viewportAnchorY,
            focusPosition: resolvedFocusPosition
        )
    }

    private func isFocusAligned(
        id: LyricLine.ID,
        viewportAnchorY: CGFloat,
        focusPosition: CGFloat
    ) -> Bool {
        guard let frame = geometryCache.frameByID[id] else { return false }
        let currentAnchorY = frame.minY + frame.height * focusPosition
        return abs(currentAnchorY - viewportAnchorY) <= 2
    }

    private func updateVisualFocus(to highlightedID: LyricLine.ID) {
        updateVisualColorFocus(to: highlightedID)
        withAnimation(
            isActive && !isViewportChanging
                ? DesktopLyricsAnimations.focusScaleAnimation(
                    settings: model.settings,
                    highlightedID: highlightedID,
                    lyrics: model.lyrics.lyrics,
                    reduceMotion: reduceMotion,
                    isFocused: true
                )
                : nil
        ) {
            visualCascadeFocusLyricID = highlightedID
        }
    }

    private func updateVisualColorFocus(
        to highlightedID: LyricLine.ID?
    ) {
        guard !reduceMotion, isActive, !isViewportChanging else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                lyricFocusColorTransition = nil
                visualHighlightedLyricID = highlightedID
            }
            return
        }
        startFocusColorTransition(to: highlightedID)
    }

    private func startFocusColorTransition(
        to highlightedLyricID: LyricLine.ID?
    ) {
        guard visualHighlightedLyricID != highlightedLyricID else { return }
        let now = Date.now
        let initialColorProgressByID: [LyricLine.ID: CGFloat]
        let initialBlurProgressByID: [LyricLine.ID: CGFloat]
        if let lyricFocusColorTransition {
            initialColorProgressByID = lyricFocusColorTransition
                .presentationColorProgressByID(at: now)
            initialBlurProgressByID = lyricFocusColorTransition
                .presentationBlurProgressByID(at: now)
        } else if let visualHighlightedLyricID {
            initialColorProgressByID = [visualHighlightedLyricID: 1]
            initialBlurProgressByID = [visualHighlightedLyricID: 1]
        } else {
            initialColorProgressByID = [:]
            initialBlurProgressByID = [:]
        }
        let motionProfile = resolvedAppleMusicLyricsMotionProfile
        let colorTimingCurve: LyricFocusColorTransition.TimingCurve =
            motionProfile.map {
                .physicalSpring($0.lineChangeSpring)
            } ?? .smoothStep
        let blurTimingCurve: LyricFocusColorTransition.TimingCurve =
            motionProfile.map {
                .cubicBezier(
                    CGFloat($0.focusBlurTransitionControlPoint1X),
                    CGFloat($0.focusBlurTransitionControlPoint1Y),
                    CGFloat($0.focusBlurTransitionControlPoint2X),
                    CGFloat($0.focusBlurTransitionControlPoint2Y)
                )
            } ?? .smoothStep
        let colorDuration: TimeInterval
        if let spring = motionProfile?.lineChangeSpring {
            colorDuration = Spring(
                mass: spring.mass,
                stiffness: spring.stiffness,
                damping: spring.damping,
                allowOverDamping: true
            ).settlingDuration(
                target: 1,
                initialVelocity: 0,
                epsilon: 0.001
            )
        } else {
            colorDuration = Self.focusColorTransitionDuration
        }
        let transition = LyricFocusColorTransition(
            initialColorProgressByID: initialColorProgressByID,
            initialBlurProgressByID: initialBlurProgressByID,
            destinationLyricID: highlightedLyricID,
            startedAt: now,
            colorDuration: colorDuration,
            blurDuration: motionProfile?.focusBlurTransitionDuration
                ?? Self.focusColorTransitionDuration,
            colorTimingCurve: colorTimingCurve,
            blurTimingCurve: blurTimingCurve
        )
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visualHighlightedLyricID = highlightedLyricID
            lyricFocusColorTransition = transition
        }
    }

    private func finishFocusColorTransition(
        _ transition: LyricFocusColorTransition
    ) async {
        let remainingDuration = transition.completionDate
            .timeIntervalSince(.now)
        if remainingDuration > 0 {
            do {
                try await Task.sleep(for: .seconds(remainingDuration))
            } catch {
                return
            }
        }
        guard !Task.isCancelled,
              lyricFocusColorTransition?.id == transition.id else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricFocusColorTransition = nil
        }
    }

    private func lyricMovementPhase(
        for id: LyricLine.ID
    ) -> LyricMovementPhase {
        let fallbackOffset = lyricMovementOffsetByID[id, default: 0]
        guard !reduceMotion,
              let lyricMovementTransition else {
            return .stationary(offset: fallbackOffset)
        }
        return lyricMovementTransition.phase(
            for: id,
            fallbackOffset: fallbackOffset
        )
    }

    @ViewBuilder
    private func surfacedScrollView(viewportSize: CGSize) -> some View {
        let lyrics = model.lyrics.lyrics
        let activePlaybackLyricIDs = activePlaybackLyricIDs
        let viewportHeight = viewportSize.height
        let textLayoutWidth = DesktopLyricsLayoutMetrics.textLayoutWidth(
            viewportWidth: viewportSize.width,
            compact: compact
        )
        let resolvedFontSize = resolvedLyricFontSize(
            for: viewportSize.width
        )
        let resolvedFocusPosition = focusPosition(
            for: viewportHeight,
            viewportWidth: viewportSize.width,
            lyricID: requestedFocusLyricID,
            focusedHeightOverride: requestedFocusHeightOverride
        )
        // LyricsX measures every row effect from the same selected-line
        // position used by its scroll controller. Keeping one anchor avoids a
        // second position update after the line-change spring settles.
        let visualFocusAnchorY = DesktopLyricsLayoutMetrics
            .quantizedVisualFocusAnchorY(
                viewportHeight * resolvedFocusPosition
        )
        // Music's recovered first-row offset is smaller than the viewport
        // mask's fade. When a prelude opens the song, start it at the mask's
        // fully-opaque boundary so scrolling to the top does not fade it.
        let hasLeadingPrelude = interludes.first?.isPrelude == true
        let leadingPreludeMaskPadding: CGFloat = if compact
            || !hasLeadingPrelude {
            0
        } else {
            viewportMaskTopOpaqueY(for: viewportHeight)
                + Self.viewportMaskTopContentClearance
        }
        let topPadding: CGFloat = if let profile =
            resolvedAppleMusicLyricsMotionProfile {
            max(
                CGFloat(profile.firstLineStartOffset),
                leadingPreludeMaskPadding
            )
        } else if compact {
            max(viewportHeight * resolvedFocusPosition, 44)
        } else {
            max(
                viewportHeight * resolvedFocusPosition,
                40,
                leadingPreludeMaskPadding
            )
        }
        let bottomPadding: CGFloat = compact
            ? max(viewportHeight * (1 - resolvedFocusPosition), 96)
            : max(viewportHeight * (1 - resolvedFocusPosition), 80)
        let lineSpacing = DesktopLyricsLayoutMetrics.lineSpacing(
            setting:
                resolvedAppleMusicLyricsMotionProfile?.lineSpacing
                    ?? model.settings.lyricsLineSpacing,
            compact: compact,
            usesAppleMusicMotion:
                resolvedAppleMusicLyricsMotionProfile != nil
        )
        let blurFocusIndex = lyrics.firstIndex {
            $0.id == blurFocusID
        }
        let precedingFocusID = blurFocusIndex.flatMap {
            index -> LyricLine.ID? in
            index > lyrics.startIndex ? lyrics[index - 1].id : nil
        }
        let followingFocusID = blurFocusIndex.flatMap {
            index -> LyricLine.ID? in
            let followingIndex = index + 1
            return followingIndex < lyrics.endIndex
                ? lyrics[followingIndex].id
                : nil
        }
        let containsSyllableSyncedLyrics = lyrics.contains(
            where: \.isSyllableSynced
        )

        let scrollView = ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(
                    alignment: .leading,
                    spacing: lineSpacing
                ) {
                    ForEach(lyrics) { line in
                        if let interlude = interludeByDisplayLyricID[line.id] {
                            AppleMusicLyricInterludeView(
                                interlude: interlude,
                                isVisible:
                                    visibleInterludeID == interlude.id,
                                advanceTime: effectiveLyricsAdvanceTime,
                                motionProfile:
                                    resolvedAppleMusicLyricsMotionProfile?
                                        .instrumentalBreak
                                        ?? .macOS26_6,
                                visualScale: visualScale,
                                onInterfaceInteraction: nil
                            )
                            .environment(model.player)
                            .onGeometryChange(for: CGRect.self) { geometry in
                                Self.quantizedGeometryFrame(
                                    geometry.frame(
                                        in: .scrollView(axis: .vertical)
                                    )
                                )
                            } action: { frame in
                                guard acceptsGeometryUpdates else { return }
                                recordInterludeGeometry(
                                    frame,
                                    for: interlude.id
                                )
                            }
                            .onDisappear {
                                geometryCache.removeInterludeMeasurements(
                                    for: interlude.id
                                )
                            }
                            .id(interlude.id)
                        }

                        lyricLine(
                            line,
                            fontSize: resolvedFontSize,
                            layoutWidth: textLayoutWidth,
                            visualFocusAnchorY: visualFocusAnchorY,
                            isBlurFocusLine: line.id == blurFocusID,
                            isPrecedingFocusLine: line.id == precedingFocusID,
                            isFollowingFocusLine: line.id == followingFocusID,
                            hasSyllableSyncedLyrics:
                                containsSyllableSyncedLyrics,
                            activePlaybackLyricIDs:
                                activePlaybackLyricIDs
                        )
                            .id(line.id)
                    }
                }
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scrollTargetLayout()
            }
            .scrollClipDisabled(!compact)
            .defaultScrollAnchor(
                resolvedAppleMusicLyricsMotionProfile == nil
                    ? focusAnchor(
                        for: viewportHeight,
                        viewportWidth: viewportSize.width,
                        lyricID: requestedFocusLyricID,
                        focusedHeightOverride:
                            requestedFocusHeightOverride
                    )
                    : .top,
                for: .sizeChanges
            )
            .onScrollPhaseChange { _, newPhase in
                switch newPhase {
                case .tracking, .interacting:
                    beginManualLyricsBrowsing()
                case .idle:
                    schedulePlaybackFollowing()
                case .decelerating, .animating:
                    break
                }
            }
            .onChange(of: scrollRequest, initial: true) { _, request in
                guard let request else { return }
                performScroll(
                    request,
                    with: proxy,
                    viewportSize: viewportSize
                )
            }
            .transaction { transaction in
                if !isInitialFocusPrepared
                    || isViewportChanging
                    || (
                        keepsPlaybackFocusSynchronized
                            && isPresented
                            && !isActive
                    ) {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
            .task(id: focusRequestID) {
                let preparesInitialFocus = !isInitialFocusPrepared
                if let focusedInterlude {
                    if preparesInitialFocus {
                        prepareInitialFocus(at: focusedInterlude)
                        await finishInitialFocusPreparation(
                            at: focusedInterlude.id,
                            waitsForLyricGeometry: false,
                            viewportHeight: viewportSize.height
                        )
                        return
                    }
                    if await prepareFocusForPresentationIfNeeded() {
                        return
                    }
                    await movePlaybackFocus(to: focusedInterlude)
                    return
                }
                guard let highlightedID else {
                    resetPlaybackFocus()
                    if preparesInitialFocus {
                        // Give the coordinator one layout turn to publish the
                        // current playback line before falling back to row one.
                        await Task.yield()
                        do {
                            try await Task.sleep(for: .milliseconds(16))
                        } catch {
                            return
                        }
                        guard !Task.isCancelled,
                              self.highlightedID == nil else { return }
                        await finishInitialFocusPreparation(
                            at: model.lyrics.lyrics.first?.id,
                            waitsForLyricGeometry: false,
                            viewportHeight: viewportSize.height
                        )
                    }
                    return
                }
                if preparesInitialFocus {
                    prepareInitialFocus(at: highlightedID)
                    await finishInitialFocusPreparation(
                        at: highlightedID,
                        waitsForLyricGeometry: true,
                        viewportHeight: viewportSize.height
                    )
                    return
                }
                if await prepareFocusForPresentationIfNeeded() {
                    return
                }
                guard !Task.isCancelled,
                      self.highlightedID == highlightedID else { return }
                await movePlaybackFocus(
                    to: highlightedID,
                    viewportHeight: viewportSize.height,
                    scrollProxy: proxy,
                    viewportSize: viewportSize
                )
            }
        }

        if compact {
            scrollView
        } else {
            scrollView.mask {
                let topOpaquePercent =
                    resolvedAppleMusicLyricsMotionProfile?
                        .viewportMaskTopOpaquePercent
                        ?? Self.viewportMaskTopOpaqueFallbackPercent
                let topOpaqueLocation = min(
                    max(CGFloat(topOpaquePercent) / 100, 0),
                    1
                )
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(
                            color: .black,
                            location: topOpaqueLocation
                        ),
                        .init(color: .black, location: 0.86),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(
                    width:
                        viewportSize.width
                        + horizontalVisualOverflow(
                            viewportWidth: viewportSize.width
                        ) * 2
                )
            }
        }
    }

    nonisolated private static func lyricGlowOverflow(
        isEnabled: Bool,
        fontSize: Double,
        intensity: Double
    ) -> CGFloat {
        guard isEnabled else { return 0 }
        return CGFloat(min(max(fontSize * intensity * 0.75, 16), 32))
    }

    nonisolated private static func quantizedGeometryFrame(
        _ frame: CGRect
    ) -> CGRect {
        CGRect(
            x: quantizedGeometryValue(frame.minX),
            y: quantizedGeometryValue(frame.minY),
            width: quantizedGeometryValue(frame.width),
            height: quantizedGeometryValue(frame.height)
        )
    }

    nonisolated private static func quantizedGeometryValue(
        _ value: CGFloat
    ) -> CGFloat {
        (value * 2).rounded() / 2
    }

    private func lyricLine(
        _ line: LyricLine,
        fontSize: CGFloat,
        layoutWidth: CGFloat,
        visualFocusAnchorY: CGFloat,
        isBlurFocusLine: Bool,
        isPrecedingFocusLine: Bool,
        isFollowingFocusLine: Bool,
        hasSyllableSyncedLyrics: Bool,
        activePlaybackLyricIDs: Set<LyricLine.ID>
    ) -> some View {
        return DesktopLyricLineView(
            line: line,
            isPlaybackLine: line.id == visualHighlightedLyricID,
            isActualPlaybackLine:
                activePlaybackLyricIDs.contains(line.id),
            isScaleFocused: line.id == visualFocusID,
            isBlurFocusLine: isBlurFocusLine,
            isPrecedingFocusLine: isPrecedingFocusLine,
            isFollowingFocusLine: isFollowingFocusLine,
            isBrowsingLyrics: isBrowsingLyrics,
            actualHighlightedLyricID: highlightedID,
            visualHighlightedLyricID: visualHighlightedLyricID,
            focusColorTransition: lyricFocusColorTransition,
            movementPhase: lyricMovementPhase(for: line.id),
            fontSize: fontSize,
            layoutWidth: layoutWidth,
            visualFocusAnchorY: visualFocusAnchorY,
            motionProfile: resolvedAppleMusicLyricsMotionProfile,
            compact: compact,
            allowsLyricBlur: allowsLyricBlur,
            foregroundColor: foregroundColor,
            hasSyllableSyncedLyrics: hasSyllableSyncedLyrics,
            onAnnotationHeightChange: { height in
                guard acceptsGeometryUpdates else { return }
                recordAnnotationHeight(height, for: line.id)
            },
            onSeek: {
                resumePlaybackFollowing()
            }
        )
        .equatable()
        .onGeometryChange(for: CGRect.self) { geometry in
            Self.quantizedGeometryFrame(
                geometry.frame(in: .scrollView(axis: .vertical))
            )
        } action: { frame in
            guard acceptsGeometryUpdates else { return }
            recordLyricGeometry(frame, for: line.id)
        }
        .onDisappear {
            geometryCache.removeMeasurements(for: line.id)
        }
    }

    private var lyricFontSize: CGFloat {
        resolvedLyricFontSize(for: geometryCache.viewportSize.width)
    }

    private func resolvedLyricFontSize(
        for proposedViewportWidth: CGFloat
    ) -> CGFloat {
        guard resolvedAppleMusicLyricsMotionProfile != nil else {
            return CGFloat(model.settings.lyricsFontSize)
        }
        let viewportWidth = proposedViewportWidth.isFinite
                && proposedViewportWidth > 0
            ? proposedViewportWidth
            : 384
        return AppleMusicLyricsTypographyProfile.macOS26_6
            .primaryFontSize(for: viewportWidth)
    }

    private var lyricsCurrentLineScale: CGFloat {
        CGFloat(
            min(
                max(
                    model.settings.effectiveAppleMusicLyricsCurrentLineScale,
                    AppSettings.lyricsCurrentLineScaleRange.lowerBound
                ),
                AppSettings.lyricsCurrentLineScaleRange.upperBound
            )
        )
    }

    private func recordLyricGeometry(
        _ frame: CGRect,
        for id: LyricLine.ID
    ) {
        guard acceptsGeometryUpdates else { return }
        guard frame.minY.isFinite,
              frame.maxY.isFinite,
              frame.height.isFinite,
              frame.height > 0 else { return }
        guard let update = geometryCache.recordFrame(frame, for: id) else {
            return
        }
        if id == visualCascadeFocusLyricID,
           lyricMovementTransition == nil,
           update.layoutHeightChanged,
           !isViewportChanging {
            synchronizeStationaryFollowingOffsets()
        }
    }

    private func recordInterludeGeometry(
        _ frame: CGRect,
        for id: LyricInterlude.ID
    ) {
        guard acceptsGeometryUpdates else { return }
        geometryCache.recordInterludeFrame(frame, for: id)
    }

    private func recordAnnotationHeight(
        _ height: CGFloat,
        for id: LyricLine.ID
    ) {
        guard acceptsGeometryUpdates else { return }
        guard height.isFinite, height > 0 else { return }
        guard geometryCache.recordAnnotationHeight(height, for: id) else {
            return
        }
        if id == visualCascadeFocusLyricID,
           lyricMovementTransition == nil,
           !isViewportChanging {
            synchronizeStationaryFollowingOffsets()
        }
    }

    private func synchronizeStationaryFollowingOffsets() {
        let offsets = focusedLineFollowingOffsets(
            for: visualCascadeFocusLyricID
                ?? playbackFocus?.lyricID
                ?? highlightedID
        )
        guard !Self.offsetsAreApproximatelyEqual(
            lyricMovementOffsetByID,
            offsets
        ) else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementOffsetByID = offsets
        }
    }

    private func beginManualLyricsBrowsing() {
        browsingGeneration &+= 1
        guard !isBrowsingLyrics else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isBrowsingLyrics = true
            scrollRequest = nil
            lyricMovementTransition = nil
            lyricMovementOffsetByID = focusedLineFollowingOffsets(
                for: visualCascadeFocusLyricID ?? highlightedID
            )
        }
    }

    private func schedulePlaybackFollowing() {
        guard isBrowsingLyrics,
              model.settings.lyricsAutoFollow else { return }

        let generation = browsingGeneration
        let delay = model.settings.lyricsFollowDelay
        Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard generation == browsingGeneration else { return }
            isBrowsingLyrics = false
        }
    }

    private func resumePlaybackFollowing() {
        browsingGeneration &+= 1
        isBrowsingLyrics = false
    }

    private func settlePlaybackFocusDuringBrowsing(
        at highlightedID: LyricLine.ID
    ) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementTransition = nil
            lyricMovementOffsetByID = focusedLineFollowingOffsets(
                for: highlightedID
            )
            visualCascadeFocusLyricID = highlightedID
            positionedLyricID = highlightedID
            positionedInterludeID = nil
        }
        updateVisualColorFocus(to: highlightedID)
    }

    private func settlePlaybackFocusDuringBrowsing(
        at interlude: LyricInterlude
    ) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementTransition = nil
            lyricMovementOffsetByID.removeAll()
            lyricFocusColorTransition = nil
            visualHighlightedLyricID = nil
            visualCascadeFocusLyricID = nil
            positionedLyricID = interlude.precedingLyricID
            positionedInterludeID = interlude.id
        }
    }

    nonisolated private static func offsetsAreApproximatelyEqual(
        _ lhs: [LyricLine.ID: CGFloat],
        _ rhs: [LyricLine.ID: CGFloat]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return lhs.allSatisfy { id, value in
            guard let otherValue = rhs[id] else { return false }
            return abs(value - otherValue) <= 0.5
        }
    }

    private func focusedLineFollowingOffsets(
        for focusedLyricID: LyricLine.ID?
    ) -> [LyricLine.ID: CGFloat] {
        guard let focusedLyricID,
              let focusedIndex = model.lyrics.lyrics.firstIndex(
                where: { $0.id == focusedLyricID }
              ),
              focusedIndex + 1 < model.lyrics.lyrics.endIndex else {
            return [:]
        }

        let focusedLine = model.lyrics.lyrics[focusedIndex]
        let fallbackPrimaryHeight = lyricFontSize * 1.2
        var focusedLayoutHeight = geometryCache.layoutHeightByID[
            focusedLyricID
        ]
            ?? fallbackPrimaryHeight
        let expandsRomanization =
            model.settings.lyricsRomanizationEnabled
                && focusedLine.hasRomanization
                && model.settings.lyricsRomanizationDisplayMode
                    == .focusedLine
        let expandsTranslation =
            model.settings.lyricsTranslationEnabled
                && focusedLine.hasTranslation
                && model.settings.lyricsTranslationDisplayMode
                    == .focusedLine
        if resolvedAppleMusicLyricsMotionProfile != nil {
            // LyricsX's primary/transliteration/translation layers share the
            // line content geometry. `layoutHeightByID` already contains the
            // reserved supplemental height, so use it directly and never add
            // a second estimated annotation delta after the focus settles.
            let followingOffset = max(
                focusedLayoutHeight * (lyricsCurrentLineScale - 1),
                0
            )
            guard followingOffset > 0.5 else { return [:] }
            return Dictionary(
                uniqueKeysWithValues:
                    model.lyrics.lyrics[(focusedIndex + 1)...].map {
                        ($0.id, followingOffset)
                    }
            )
        }

        if (expandsRomanization || expandsTranslation),
           focusedLyricID != visualCascadeFocusLyricID {
            if expandsRomanization {
                focusedLayoutHeight += max(
                    lyricFontSize
                        * CGFloat(
                            model.settings.lyricsRomanizationFontScale
                        ),
                    compact ? 11 : 13
                ) * 1.2 + Self.annotationSpacing
            }
            if expandsTranslation {
                focusedLayoutHeight +=
                    (geometryCache.annotationHeightByID[focusedLyricID]
                        ?? max(
                            lyricFontSize
                                * CGFloat(
                                    model.settings
                                        .lyricsTranslationFontScale
                                ),
                            compact ? 11 : 13
                        ) * 1.2)
                    + Self.annotationSpacing
            }
        }
        let followingOffset = max(
            focusedLayoutHeight * (lyricsCurrentLineScale - 1),
            0
        )
        guard followingOffset > 0.5 else { return [:] }
        return Dictionary(
            uniqueKeysWithValues:
                model.lyrics.lyrics[(focusedIndex + 1)...].map {
                    ($0.id, followingOffset)
                }
        )
    }

}
