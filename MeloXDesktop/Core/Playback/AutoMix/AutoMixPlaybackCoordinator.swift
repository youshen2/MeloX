import Foundation

nonisolated struct PreparedAutoMixContext {
    let outgoingSongID: Int
    let incomingSong: Song
    let source: PlaybackSource
    let sourceIsDownloaded: Bool
}

@MainActor
final class AutoMixPlaybackCoordinator {
    var onTransitionBegan:
        ((PreparedAutoMixContext, AutoMixTransitionPlan) -> Void)?
    var onTransitionProgress: ((Double) -> Void)?
    var onPlaybackHandoff: ((PreparedAutoMixContext) -> Void)?
    var onTransitionCompleted:
        ((PreparedAutoMixContext) -> Void)?

    private struct Attempt: Equatable {
        let outgoingSongID: Int
        let incomingSongID: Int
    }

    private struct PlannedTransition {
        let attempt: Attempt
        let context: PreparedAutoMixContext
        let plan: AutoMixTransitionPlan
        let outgoingDuration: TimeInterval
    }

    private let api: NeteaseAPI
    private let downloads: DownloadStore
    private let engine: AudioPlaybackEngine
    private let analyzer: AutoMixAudioAnalyzer

    private var planningTask: Task<Void, Never>?
    private var deckPreparationTask: Task<Void, Never>?
    private var preparationGeneration = 0
    private var attempt: Attempt?
    private var plannedTransition: PlannedTransition?
    private var preparedContext: PreparedAutoMixContext?
    private var transitionHasBegun = false
    private var latestRemainingTime =
        TimeInterval.infinity
    private var latestPreloadLeadTime: TimeInterval = 0

    init(
        api: NeteaseAPI,
        downloads: DownloadStore,
        engine: AudioPlaybackEngine,
        analyzer: AutoMixAudioAnalyzer
    ) {
        self.api = api
        self.downloads = downloads
        self.engine = engine
        self.analyzer = analyzer
        bindEngine()
    }

    func prepareIfNeeded(
        isEnabled: Bool,
        isPlaying: Bool,
        repeatsCurrentSong: Bool,
        outgoingSong: Song?,
        outgoingSource: PlaybackSource?,
        outgoingSourceIsDownloaded: Bool,
        outgoingDuration: TimeInterval,
        outgoingProgress: TimeInterval,
        incomingSong: Song?,
        configuration: AutoMixConfiguration
    ) {
        guard isEnabled,
              isPlaying,
              !repeatsCurrentSong,
              !transitionHasBegun,
              let outgoingSong,
              let outgoingSource,
              let incomingSong else {
            return
        }

        let nextAttempt = Attempt(
            outgoingSongID: outgoingSong.id,
            incomingSongID: incomingSong.id
        )

        let outgoingDuration = max(
            outgoingDuration,
            TimeInterval(outgoingSong.durationMS) / 1_000
        )
        let remaining = max(
            outgoingDuration - outgoingProgress,
            0
        )

        if let attempt,
           attempt != nextAttempt {
            cancel()
        }
        latestRemainingTime = remaining
        latestPreloadLeadTime =
            configuration.preloadLeadTime

        if plannedTransition?.attempt
            == nextAttempt {
            prepareDeckIfNeeded()
            return
        }

        guard planningTask == nil,
              deckPreparationTask == nil,
              preparedContext == nil,
              !engine.hasPreparedAutoMix,
              attempt != nextAttempt else {
            return
        }

        if configuration.mode != .smart,
           remaining > configuration.preloadLeadTime {
            return
        }

        attempt = nextAttempt
        preparationGeneration += 1
        let generation = preparationGeneration
        planningTask = Task {
            @MainActor [weak self] in
            guard let self else { return }
            defer {
                if generation == self.preparationGeneration {
                    self.planningTask = nil
                }
            }

            do {
                let incomingSource =
                    try await self.resolvePlaybackSource(
                        for: incomingSong
                    )
                try Task.checkCancellation()

                let analysis = await self.analysis(
                    configuration: configuration,
                    outgoingSong: outgoingSong,
                    outgoingSource: outgoingSource,
                    outgoingSourceIsDownloaded:
                        outgoingSourceIsDownloaded,
                    outgoingDuration: outgoingDuration,
                    incomingSong: incomingSong,
                    incomingSource: incomingSource
                )
                try Task.checkCancellation()

                guard generation == self.preparationGeneration else {
                    return
                }
                guard let plan =
                        AutoMixTransitionPlanner.makePlan(
                            configuration: configuration,
                            outgoingDuration: outgoingDuration,
                            incomingDuration:
                                Self.duration(
                                    of: incomingSong
                                ),
                            analysis: analysis
                        ) else {
                    return
                }

                let context = PreparedAutoMixContext(
                    outgoingSongID: outgoingSong.id,
                    incomingSong: incomingSong,
                    source: incomingSource.source,
                    sourceIsDownloaded:
                        incomingSource.isDownloaded
                )
                self.plannedTransition =
                    PlannedTransition(
                        attempt: nextAttempt,
                        context: context,
                        plan: plan,
                        outgoingDuration:
                            outgoingDuration
                    )
                self.prepareDeckIfNeeded()
            } catch is CancellationError {
                return
            } catch {
                if generation
                    == self.preparationGeneration {
                    self.attempt = nil
                }
                return
            }
        }
    }

    private func prepareDeckIfNeeded() {
        guard deckPreparationTask == nil,
              preparedContext == nil,
              !engine.hasPreparedAutoMix,
              !transitionHasBegun,
              let plannedTransition,
              plannedTransition.attempt
                == attempt else {
            return
        }
        let transitionLeadTime = max(
            plannedTransition
                .outgoingDuration
                - plannedTransition
                    .plan
                    .outgoingStartTime
                + 12,
            latestPreloadLeadTime
        )
        guard latestRemainingTime
                <= transitionLeadTime else {
            return
        }

        self.plannedTransition = nil
        preparedContext =
            plannedTransition.context
        let generation = preparationGeneration
        deckPreparationTask = Task {
            @MainActor [weak self] in
            guard let self else { return }
            defer {
                if generation
                    == self.preparationGeneration {
                    self.deckPreparationTask = nil
                }
            }
            await self.engine.prepareAutoMix(
                plannedTransition.context.source,
                identifier:
                    plannedTransition.context
                        .incomingSong.id,
                plan: plannedTransition.plan
            )
            if Task.isCancelled {
                return
            }
            guard generation
                    == self.preparationGeneration else {
                return
            }
            if !self.engine.hasPreparedAutoMix,
               !self.transitionHasBegun {
                self.preparedContext = nil
                self.attempt = nil
            }
        }
    }

    func cancel() {
        preparationGeneration += 1
        planningTask?.cancel()
        planningTask = nil
        deckPreparationTask?.cancel()
        deckPreparationTask = nil
        attempt = nil
        plannedTransition = nil
        preparedContext = nil
        transitionHasBegun = false
        latestRemainingTime = .infinity
        latestPreloadLeadTime = 0
        engine.cancelAutoMix()
    }

    private func analysis(
        configuration: AutoMixConfiguration,
        outgoingSong: Song,
        outgoingSource: PlaybackSource,
        outgoingSourceIsDownloaded: Bool,
        outgoingDuration: TimeInterval,
        incomingSong: Song,
        incomingSource: (
            source: PlaybackSource,
            isDownloaded: Bool
        )
    ) async -> AutoMixPairAnalysis? {
        guard configuration.mode == .smart,
              configuration.analyzesStreamingTracks
                || (
                    outgoingSourceIsDownloaded
                        && incomingSource.isDownloaded
                ) else {
            return nil
        }
        return try? await analyzer.analyzePair(
            outgoing: AutoMixAnalysisRequest(
                songID: outgoingSong.id,
                source: outgoingSource,
                duration: outgoingDuration,
                isDownloaded:
                    outgoingSourceIsDownloaded
            ),
            incoming: AutoMixAnalysisRequest(
                songID: incomingSong.id,
                source: incomingSource.source,
                duration: Self.duration(of: incomingSong),
                isDownloaded:
                    incomingSource.isDownloaded
            )
        )
    }

    private func resolvePlaybackSource(
        for song: Song
    ) async throws -> (
        source: PlaybackSource,
        isDownloaded: Bool
    ) {
        if let source = downloads.localPlaybackSource(
            songID: song.id
        ) {
            return (source, true)
        }
        return (
            try await api.playbackSource(for: song),
            false
        )
    }

    private func bindEngine() {
        engine.onAutoMixTransitionBegan = {
            [weak self] identifier, plan in
            guard let self,
                  let context = self.preparedContext,
                  context.incomingSong.id
                    == identifier else {
                return
            }
            self.transitionHasBegun = true
            self.onTransitionBegan?(context, plan)
        }
        engine.onAutoMixTransitionProgress = {
            [weak self] progress in
            guard let self,
                  self.transitionHasBegun else {
                return
            }
            self.onTransitionProgress?(
                min(max(progress, 0), 1)
            )
        }
        engine.onAutoMixPlaybackHandoff = { [weak self] identifier in
            guard let self,
                  let context = self.preparedContext,
                  self.transitionHasBegun,
                  context.incomingSong.id == identifier else { return }
            // Keep preparation blocked until the outgoing fade has finished.
            self.onPlaybackHandoff?(context)
        }
        engine.onAutoMixTransitionCompleted = {
            [weak self] identifier in
            guard let self,
                  let context = self.preparedContext,
                  context.incomingSong.id
                    == identifier else {
                return
            }
            self.planningTask = nil
            self.deckPreparationTask = nil
            self.attempt = nil
            self.plannedTransition = nil
            self.preparedContext = nil
            self.transitionHasBegun = false
            self.latestRemainingTime = .infinity
            self.latestPreloadLeadTime = 0
            self.onTransitionCompleted?(context)
        }
        engine.onAutoMixPreparationFailed = {
            [weak self] identifier, _ in
            self?.handlePreparationFailure(
                incomingSongID: identifier
            )
        }
    }

    private func handlePreparationFailure(
        incomingSongID: Int
    ) {
        guard let context = preparedContext,
              context.incomingSong.id
                == incomingSongID else {
            return
        }
        preparedContext = nil
        transitionHasBegun = false
        guard context.sourceIsDownloaded else {
            return
        }
        downloads.discardInvalidDownload(
            songID: incomingSongID
        )
        attempt = nil
    }

    private static func duration(
        of song: Song
    ) -> TimeInterval {
        TimeInterval(song.durationMS) / 1_000
    }
}
