import SwiftUI

enum NowPlayingLyricsPresentation: Equatable {
    case portrait
    case landscape
}

struct NowPlayingLyricsPage: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let song: Song
    let lyrics: [LyricLine]
    let errorMessage: String?
    let highlightedLyricID: LyricLine.ID?
    let presentation: NowPlayingLyricsPresentation
    let onToggleInterface: (() -> Void)?

    @State private var scrollPositionID: LyricLine.ID?
    @State private var isBrowsingLyrics = false
    @State private var browsingGeneration = 0
    @State private var isPreparingInitialFocus = true
    @State private var visualHighlightedLyricID: LyricLine.ID?
    @State private var visualBlurFocusLyricID: LyricLine.ID?
    @State private var lyricFrameByID: [LyricLine.ID: CGRect] = [:]
    @State private var lyricMovementOffsetByID: [LyricLine.ID: CGFloat] = [:]

    init(
        song: Song,
        lyrics: [LyricLine],
        errorMessage: String?,
        highlightedLyricID: LyricLine.ID?,
        presentation: NowPlayingLyricsPresentation = .portrait,
        onToggleInterface: (() -> Void)? = nil
    ) {
        self.song = song
        self.lyrics = lyrics
        self.errorMessage = errorMessage
        self.highlightedLyricID = highlightedLyricID
        self.presentation = presentation
        self.onToggleInterface = onToggleInterface
        _scrollPositionID = State(initialValue: highlightedLyricID)
        _visualHighlightedLyricID = State(initialValue: highlightedLyricID)
        _visualBlurFocusLyricID = State(initialValue: highlightedLyricID)
    }

    var body: some View {
        VStack(spacing: presentation == .portrait ? 18 : 0) {
            if presentation == .portrait {
                songHeader
            }

            lyricsContent
        }
        .padding(.bottom, presentation == .portrait ? 12 : 0)
        .keepsScreenAwake(settings.lyricsKeepsScreenAwake)
    }

    private var songHeader: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: song.album?.artworkURL, cornerRadius: 8)
                .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(song.artistText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            NowPlayingSongActions(song: song)
        }
    }

    @ViewBuilder
    private var lyricsContent: some View {
        if lyrics.isEmpty {
            if let errorMessage {
                ContentUnavailableView(
                    "暂无歌词",
                    systemImage: "quote.bubble",
                    description: Text(errorMessage)
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .onTapGesture {
                    onToggleInterface?()
                }
            } else {
                ProgressView("正在载入歌词")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
                    .onTapGesture {
                        onToggleInterface?()
                    }
            }
        } else {
            let focusPosition = lyricsFocusPosition
            let blurFocusLyricID = isBrowsingLyrics
                ? scrollPositionID
                : visualBlurFocusLyricID ?? scrollPositionID ?? highlightedLyricID
            let focusNeighborIDs = lyricNeighborIDs(around: blurFocusLyricID)
            let focusEffectAnimation = lyricFocusEffectAnimation(
                for: visualHighlightedLyricID
            )
            let hasSyllableSyncedLyrics = lyrics.contains { $0.isSyllableSynced }
            let usesPseudoTiming = settings.lyricsPseudoWordByWord
                && !hasSyllableSyncedLyrics
            let showsTranslations = settings.lyricsTranslationEnabled
                && lyrics.contains { $0.translation != nil }
            let translationHeight = showsTranslations
                ? CGFloat(settings.lyricsFontSize * settings.lyricsTranslationFontScale * 1.2) + 5
                : 0
            let lyricStride = max(
                CGFloat(settings.lyricsFontSize) * 1.2
                    + translationHeight
                    + CGFloat(settings.lyricsLineSpacing),
                1
            )
            let blurIntensity = CGFloat(settings.lyricsBlurIntensity)
            let dimAmount = settings.lyricsDimAmount
            let glowOverflow = Self.lyricGlowOverflow(
                isEnabled: settings.lyricsGlowEnabled
                    && (
                        (settings.lyricsWordByWord && hasSyllableSyncedLyrics)
                            || usesPseudoTiming
                    ),
                fontSize: settings.lyricsFontSize,
                intensity: settings.lyricsGlowIntensity
            )

            GeometryReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CGFloat(settings.lyricsLineSpacing)) {
                        ForEach(lyrics) { line in
                            let isPlaybackLine = line.id == visualHighlightedLyricID
                            let isActualPlaybackLine = line.id == highlightedLyricID
                            let isPrecedingFocusLine = line.id == focusNeighborIDs.preceding
                            let isFollowingFocusLine = line.id == focusNeighborIDs.following
                            let isBrowsingFocus = isBrowsingLyrics && line.id == scrollPositionID
                            let movementOffset = lyricMovementOffsetByID[line.id, default: 0]
                            let focusBlurRadius = Self.lyricFocusBlurRadius(
                                intensity: blurIntensity,
                                isPrecedingFocusLine: isPrecedingFocusLine,
                                isFollowingFocusLine: isFollowingFocusLine
                            )

                            SynchronizedLyricText(
                                line: line,
                                isPlaybackLine: isPlaybackLine,
                                usesPseudoTiming: usesPseudoTiming,
                                fontSize: CGFloat(settings.lyricsFontSize),
                                layoutWidth: proxy.size.width
                            )
                                .opacity(
                                    Self.lyricEmphasis(
                                        isPlaybackLine: isPlaybackLine,
                                        isBrowsingFocus: isBrowsingFocus,
                                        dimAmount: dimAmount
                                    )
                                )
                                .animation(
                                    focusEffectAnimation,
                                    value: isPlaybackLine
                                )
                                .contentShape(.rect)
                                .visualEffect { content, geometry in
                                    let frame = geometry.frame(in: .scrollView(axis: .vertical))
                                    let visualMidY = frame.midY + movementOffset
                                    let distance = abs(
                                        visualMidY - proxy.size.height * focusPosition
                                    )
                                    let bottomRevealOpacity = Self.lyricBottomRevealOpacity(
                                        frame: frame,
                                        movementOffset: movementOffset,
                                        viewportHeight: proxy.size.height
                                    )
                                    return content
                                        .blur(
                                            radius: Self.lyricDistanceBlurRadius(
                                                forPixelDistance: distance,
                                                lyricStride: lyricStride,
                                                intensity: blurIntensity
                                            )
                                        )
                                        .opacity(
                                            Self.lyricOpacity(
                                                forPixelDistance: distance,
                                                lyricStride: lyricStride,
                                                dimAmount: dimAmount
                                            ) * bottomRevealOpacity
                                        )
                                        .offset(y: movementOffset)
                                }
                                .blur(radius: focusBlurRadius)
                                .animation(focusEffectAnimation, value: focusBlurRadius)
                                .onGeometryChange(for: CGRect.self) { geometry in
                                    geometry.frame(in: .scrollView(axis: .vertical))
                                } action: { frame in
                                    lyricFrameByID[line.id] = frame
                                }
                                .gesture(lyricTapGesture(for: line))
                                .id(line.id)
                                .onDisappear {
                                    lyricFrameByID.removeValue(forKey: line.id)
                                    lyricMovementOffsetByID.removeValue(forKey: line.id)
                                }
                                .accessibilityLabel(
                                    line.accessibilityText(
                                        includingTranslation: settings.lyricsTranslationEnabled
                                    )
                                )
                                .accessibilityValue(
                                    lyricAccessibilityValue(
                                        isPlaybackLine: isActualPlaybackLine,
                                        isBrowsingFocus: isBrowsingFocus
                                    )
                                )
                                .accessibilityHint(settings.lyricsTapToSeek ? "双击跳转到这行歌词" : "歌词跳转已在设置中关闭")
                                .accessibilityAddTraits(settings.lyricsTapToSeek ? .isButton : [])
                                .accessibilityAction {
                                    seek(to: line)
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.top, max(proxy.size.height * focusPosition, 40))
                    .padding(.bottom, max(proxy.size.height * (1 - focusPosition), 40))
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .scrollPosition(
                    id: $scrollPositionID,
                    anchor: UnitPoint(x: 0.5, y: focusPosition)
                )
                .transaction { transaction in
                    if isPreparingInitialFocus {
                        transaction.animation = nil
                    }
                }
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.08),
                            .init(color: .black, location: 0.84),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: proxy.size.width + glowOverflow * 2)
                }
                .onScrollPhaseChange { _, newPhase in
                    switch newPhase {
                    case .tracking, .interacting:
                        browsingGeneration += 1
                        isBrowsingLyrics = true
                    case .idle:
                        schedulePlaybackFollowing()
                    case .decelerating, .animating:
                        break
                    }
                }
                .onChange(of: highlightedLyricID) { _, newValue in
                    guard newValue == nil else { return }
                    visualHighlightedLyricID = nil
                    visualBlurFocusLyricID = nil
                    lyricMovementOffsetByID.removeAll()
                }
                .onAppear {
                    synchronizeFocusIfNeeded()
                }
                .task {
                    await Task.yield()
                    isPreparingInitialFocus = false
                }
                .task(id: focusMovementTrigger) {
                    await cascadeMoveFocus(
                        to: highlightedLyricID,
                        viewportHeight: proxy.size.height,
                        preloadLineCount: 2
                    )
                }
                .onDisappear {
                    browsingGeneration += 1
                    lyricFrameByID.removeAll()
                    lyricMovementOffsetByID.removeAll()
                }
            }
        }
    }

    private var lyricsFocusPosition: CGFloat {
        CGFloat(min(max(settings.lyricsFocusPosition, 0.2), 0.5))
    }

    private var focusMovementTrigger: LyricFocusMovementTrigger {
        LyricFocusMovementTrigger(
            highlightedLyricID: highlightedLyricID,
            isBrowsingLyrics: isBrowsingLyrics
        )
    }

    private func lyricFocusEffectAnimation(
        for highlightedLyricID: LyricLine.ID?
    ) -> Animation? {
        guard !accessibilityReduceMotion else { return nil }
        let movementDuration = LyricPlaybackTimeline.focusAnimationDuration(
            for: highlightedLyricID,
            in: lyrics
        )
        return .easeInOut(duration: max(movementDuration, 0.2))
    }

    private var lyricsFocusColorLeadTime: TimeInterval {
        min(
            max(
                settings.lyricsFocusColorLeadTime,
                AppSettings.lyricsFocusColorLeadTimeRange.lowerBound
            ),
            AppSettings.lyricsFocusColorLeadTimeRange.upperBound
        )
    }

    private func remainingFocusDuration(
        for highlightedLyricID: LyricLine.ID
    ) -> TimeInterval? {
        guard player.isPlaying else { return nil }
        return LyricPlaybackTimeline.remainingFocusDuration(
            for: highlightedLyricID,
            at: player.estimatedProgress() + settings.lyricsAdvanceTime,
            in: lyrics
        )
    }

    private func cascadeMoveFocus(
        to highlightedLyricID: LyricLine.ID?,
        viewportHeight: CGFloat,
        preloadLineCount: Int
    ) async {
        guard let highlightedLyricID else { return }
        guard !isBrowsingLyrics else {
            visualHighlightedLyricID = highlightedLyricID
            visualBlurFocusLyricID = highlightedLyricID
            return
        }
        guard scrollPositionID != highlightedLyricID else {
            visualHighlightedLyricID = highlightedLyricID
            visualBlurFocusLyricID = highlightedLyricID
            return
        }
        guard isAdjacentFocusTransition(
            from: scrollPositionID,
            to: highlightedLyricID
        ) else {
            await moveFocusWithoutCascade(to: highlightedLyricID)
            return
        }

        guard !accessibilityReduceMotion,
              settings.lyricsFocusCascadeDelay > 0,
              let nextFocusFrame = lyricFrameByID[highlightedLyricID] else {
            await moveFocusWithoutCascade(to: highlightedLyricID)
            return
        }

        let focusPosition = lyricsFocusPosition
        let viewportAnchorY = viewportHeight * focusPosition
        let nextFocusAnchorY = nextFocusFrame.minY
            + nextFocusFrame.height * focusPosition
        let movementDistance = nextFocusAnchorY - viewportAnchorY
        guard abs(movementDistance) > 0.5 else {
            moveFocus(to: highlightedLyricID, animated: false)
            visualHighlightedLyricID = highlightedLyricID
            visualBlurFocusLyricID = highlightedLyricID
            return
        }

        let initialVisibleIDs = lyricFrameByID
            .filter { entry in
                let frame = entry.value
                return frame.maxY >= 0 && frame.minY <= viewportHeight
            }
            .sorted { left, right in
                left.value.minY < right.value.minY
            }
            .map(\.key)
        let animationDuration = LyricPlaybackTimeline.focusAnimationDuration(
            for: highlightedLyricID,
            in: lyrics
        )
        let focusColorLeadTime = lyricsFocusColorLeadTime
        guard initialVisibleIDs.count > 1 else {
            await moveFocusWithoutCascade(to: highlightedLyricID)
            return
        }

        var preparationTransaction = Transaction(animation: nil)
        preparationTransaction.disablesAnimations = true
        withTransaction(preparationTransaction) {
            lyricMovementOffsetByID = Dictionary(
                uniqueKeysWithValues: lyrics.map { line in
                    (line.id, movementDistance)
                }
            )
            scrollPositionID = highlightedLyricID
        }

        var destinationIsPrepared = false
        for _ in 0..<4 {
            await Task.yield()
            guard !Task.isCancelled else {
                resolveInterruptedMovement(to: highlightedLyricID)
                return
            }
            guard let preparedFocusFrame = lyricFrameByID[highlightedLyricID] else {
                continue
            }
            let preparedAnchorY = preparedFocusFrame.minY
                + preparedFocusFrame.height * focusPosition
            if abs(preparedAnchorY - viewportAnchorY) <= 1.5 {
                destinationIsPrepared = true
                break
            }
        }
        guard destinationIsPrepared else {
            completeCascadeMovement(to: highlightedLyricID)
            return
        }

        let destinationVisibleIDs = lyricFrameByID
            .filter { entry in
                let frame = entry.value
                return frame.maxY >= 0 && frame.minY <= viewportHeight
            }
            .sorted { left, right in
                left.value.minY < right.value.minY
            }
            .map(\.key)
        let lyricIndexByID = Dictionary(
            uniqueKeysWithValues: lyrics.enumerated().map { index, line in
                (line.id, index)
            }
        )
        var movingIDSet = Set(initialVisibleIDs)
        movingIDSet.formUnion(destinationVisibleIDs)
        if preloadLineCount > 0,
           let bottomVisibleIndex = destinationVisibleIDs
            .compactMap({ lyricIndexByID[$0] })
            .max() {
            let preloadStartIndex = bottomVisibleIndex + 1
            let preloadEndIndex = min(
                preloadStartIndex + preloadLineCount,
                lyrics.endIndex
            )
            if preloadStartIndex < preloadEndIndex {
                for index in preloadStartIndex..<preloadEndIndex {
                    movingIDSet.insert(lyrics[index].id)
                }
            }
        }
        let orderedMovingIDs = movingIDSet.sorted {
            lyricIndexByID[$0, default: 0] < lyricIndexByID[$1, default: 0]
        }
        guard orderedMovingIDs.count > 1 else {
            completeCascadeMovement(to: highlightedLyricID)
            return
        }
        guard LyricPlaybackTimeline.shouldUseFocusCascade(
            visibleLineCount: orderedMovingIDs.count,
            preferredDelayPerLine: settings.lyricsFocusCascadeDelay,
            focusColorLeadTime: focusColorLeadTime,
            animationDuration: animationDuration,
            remainingDuration: remainingFocusDuration(
                for: highlightedLyricID
            ),
            highlightedLyricID: highlightedLyricID,
            in: lyrics
        ) else {
            completeCascadeMovement(to: highlightedLyricID)
            return
        }
        await animatePreparedCascade(
            orderedMovingIDs,
            to: highlightedLyricID,
            focusColorLeadTime: focusColorLeadTime,
            animationDuration: animationDuration
        )
    }

    private func animatePreparedCascade(
        _ orderedMovingIDs: [LyricLine.ID],
        to highlightedLyricID: LyricLine.ID,
        focusColorLeadTime: TimeInterval,
        animationDuration: TimeInterval
    ) async {
        withAnimation(lyricFocusEffectAnimation(for: highlightedLyricID)) {
            visualHighlightedLyricID = highlightedLyricID
        }
        if focusColorLeadTime > 0 {
            do {
                try await Task.sleep(for: .seconds(focusColorLeadTime))
            } catch {
                resolveInterruptedMovement(to: highlightedLyricID)
                return
            }
        }
        guard !Task.isCancelled else {
            resolveInterruptedMovement(to: highlightedLyricID)
            return
        }

        var elapsedDelay: TimeInterval = 0
        for (order, id) in orderedMovingIDs.enumerated() {
            let targetDelay = LyricPlaybackTimeline.focusCascadeDelay(
                visibleOrder: order,
                visibleLineCount: orderedMovingIDs.count,
                preferredDelayPerLine: settings.lyricsFocusCascadeDelay,
                highlightedLyricID: highlightedLyricID,
                in: lyrics
            )
            let nextDelay = targetDelay - elapsedDelay
            if nextDelay > 0 {
                do {
                    try await Task.sleep(for: .seconds(nextDelay))
                } catch {
                    resolveInterruptedMovement(to: highlightedLyricID)
                    return
                }
            }
            guard !Task.isCancelled else {
                resolveInterruptedMovement(to: highlightedLyricID)
                return
            }

            withAnimation(.smooth(duration: animationDuration)) {
                if order == 0 {
                    visualBlurFocusLyricID = highlightedLyricID
                }
                lyricMovementOffsetByID[id] = 0
            }
            elapsedDelay = targetDelay
        }

        do {
            try await Task.sleep(for: .seconds(animationDuration))
        } catch {
            resolveInterruptedMovement(to: highlightedLyricID)
            return
        }
        guard !Task.isCancelled else {
            resolveInterruptedMovement(to: highlightedLyricID)
            return
        }
        completeCascadeMovement(to: highlightedLyricID)
    }

    private func isAdjacentFocusTransition(
        from currentID: LyricLine.ID?,
        to nextID: LyricLine.ID
    ) -> Bool {
        guard let currentID,
              let currentIndex = lyrics.firstIndex(where: { $0.id == currentID }),
              let nextIndex = lyrics.firstIndex(where: { $0.id == nextID }) else {
            return false
        }
        return abs(nextIndex - currentIndex) == 1
    }

    private func moveFocusWithoutCascade(to id: LyricLine.ID) async {
        moveFocus(to: id, animated: true)
        await Task.yield()
        guard !Task.isCancelled else { return }
        withAnimation(
            accessibilityReduceMotion
                ? nil
                : .easeInOut(
                    duration: LyricPlaybackTimeline.focusAnimationDuration(
                        for: id,
                        in: lyrics
                    )
                )
        ) {
            visualHighlightedLyricID = id
            visualBlurFocusLyricID = id
        }
    }

    private func resolveInterruptedMovement(to id: LyricLine.ID) {
        if isBrowsingLyrics {
            resetMovementOffsets()
        } else {
            completeCascadeMovement(to: highlightedLyricID ?? id)
        }
    }

    private func completeCascadeMovement(to id: LyricLine.ID) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollPositionID = id
            visualHighlightedLyricID = id
            visualBlurFocusLyricID = id
            lyricMovementOffsetByID.removeAll()
        }
    }

    private func resetMovementOffsets() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementOffsetByID.removeAll()
        }
    }

    private func lyricNeighborIDs(
        around focusedLyricID: LyricLine.ID?
    ) -> (
        preceding: LyricLine.ID?,
        following: LyricLine.ID?
    ) {
        guard let focusedLyricID,
              let focusIndex = lyrics.firstIndex(where: { $0.id == focusedLyricID }) else {
            return (nil, nil)
        }

        let precedingID = focusIndex > lyrics.startIndex
            ? lyrics[lyrics.index(before: focusIndex)].id
            : nil
        let followingIndex = lyrics.index(after: focusIndex)
        let followingID = followingIndex < lyrics.endIndex
            ? lyrics[followingIndex].id
            : nil
        return (precedingID, followingID)
    }

    private func lyricAccessibilityValue(
        isPlaybackLine: Bool,
        isBrowsingFocus: Bool
    ) -> String {
        switch (isPlaybackLine, isBrowsingFocus) {
        case (true, true): "当前播放，浏览焦点"
        case (true, false): "当前播放"
        case (false, true): "浏览焦点"
        case (false, false): ""
        }
    }

    nonisolated private static func lyricDistanceBlurRadius(
        forPixelDistance distance: CGFloat,
        lyricStride: CGFloat,
        intensity: CGFloat
    ) -> CGFloat {
        let lineDistance = distance / lyricStride
        let blurProgress = max(lineDistance - 1.35, 0)
        let baseRadius = min(blurProgress * 3.1, 10)
        return baseRadius * intensity
    }

    nonisolated private static func lyricFocusBlurRadius(
        intensity: CGFloat,
        isPrecedingFocusLine: Bool,
        isFollowingFocusLine: Bool
    ) -> CGFloat {
        let precedingLineRadius: CGFloat = isPrecedingFocusLine ? 0.9 : 0
        let followingLineRadius: CGFloat = isFollowingFocusLine ? 0.55 : 0
        return (precedingLineRadius + followingLineRadius) * intensity
    }

    nonisolated private static func lyricOpacity(
        forPixelDistance distance: CGFloat,
        lyricStride: CGFloat,
        dimAmount: Double
    ) -> Double {
        let lineDistance = Double(distance / lyricStride)
        let baseOpacity: Double
        switch lineDistance {
        case ...1:
            baseOpacity = 1 - lineDistance * 0.44
        case ...2:
            baseOpacity = 0.56 - (lineDistance - 1) * 0.22
        default:
            baseOpacity = max(0.12, 0.34 - (lineDistance - 2) * 0.07)
        }
        return 1 - (1 - baseOpacity) * dimAmount
    }

    nonisolated private static func lyricBottomRevealOpacity(
        frame: CGRect,
        movementOffset: CGFloat,
        viewportHeight: CGFloat
    ) -> Double {
        let visualMinY = frame.minY + movementOffset
        let revealDistance = min(max(frame.height * 0.8, 32), 72)
        let progress = (viewportHeight - visualMinY) / revealDistance
        return Double(min(max(progress, 0), 1))
    }

    nonisolated private static func lyricEmphasis(
        isPlaybackLine: Bool,
        isBrowsingFocus: Bool,
        dimAmount: Double
    ) -> Double {
        guard !isPlaybackLine else { return 1 }
        let baseOpacity = isBrowsingFocus ? 0.7 : 0.52
        return 1 - (1 - baseOpacity) * dimAmount
    }

    nonisolated private static func lyricGlowOverflow(
        isEnabled: Bool,
        fontSize: Double,
        intensity: Double
    ) -> CGFloat {
        guard isEnabled else { return 0 }
        return CGFloat(min(max(fontSize * intensity * 0.75, 16), 32))
    }

    private func schedulePlaybackFollowing() {
        guard isBrowsingLyrics, settings.lyricsAutoFollow else { return }
        let generation = browsingGeneration
        let delay = settings.lyricsFollowDelay

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

    private func synchronizeFocusIfNeeded() {
        let existingFocusIsValid = scrollPositionID.map { focusedID in
            lyrics.contains { $0.id == focusedID }
        } ?? false
        guard !existingFocusIsValid else { return }

        guard let initialID = highlightedLyricID ?? lyrics.first?.id else { return }
        moveFocus(to: initialID, animated: false)
    }

    private func seek(to line: LyricLine) {
        guard settings.lyricsTapToSeek else { return }
        browsingGeneration += 1
        isBrowsingLyrics = false
        moveFocus(to: line.id, animated: true)
        player.seek(to: line.time)
    }

    private func lyricTapGesture(for line: LyricLine) -> some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { gesture in
                switch gesture {
                case .first:
                    seek(to: line)
                case .second:
                    onToggleInterface?()
                }
            }
    }

    private func moveFocus(to id: LyricLine.ID, animated: Bool) {
        let update = {
            scrollPositionID = id
        }

        if animated, !accessibilityReduceMotion {
            withAnimation(
                .smooth(
                    duration: LyricPlaybackTimeline.focusAnimationDuration(
                        for: id,
                        in: lyrics
                    )
                ),
                update
            )
        } else {
            update()
        }
    }
}

private struct LyricFocusMovementTrigger: Hashable {
    let highlightedLyricID: LyricLine.ID?
    let isBrowsingLyrics: Bool
}
