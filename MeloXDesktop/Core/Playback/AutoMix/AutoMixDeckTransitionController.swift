@preconcurrency import AVFoundation
import Foundation

enum AutoMixPreparationError: LocalizedError {
    case itemFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .itemFailed(let error):
            error?.localizedDescription
                ?? L10n.string("ui.error.automix.preload_failed")
        }
    }
}

@MainActor
final class AutoMixDeckTransitionController {
    var onTransitionBegan:
        ((Int, AutoMixTransitionPlan) -> Void)?
    var onTransitionProgress: ((Double) -> Void)?
    var onTransitionCompleted: ((Int) -> Void)?
    var onPreparationFailed:
        ((Int, Error) -> Void)?
    var onActiveDeckChanged: (() -> Void)?

    let decks: [AudioPlaybackDeck]
    private(set) var activeDeckIndex = 0

    private struct PreparedTransition {
        let identifier: Int
        let deckIndex: Int
        let itemID: UUID
        let plan: AutoMixTransitionPlan
    }

    private final class ActiveTransition {
        let identifier: Int
        let outgoingDeckIndex: Int
        let incomingDeckIndex: Int
        let plan: AutoMixTransitionPlan
        let outgoingStartPosition:
            TimeInterval
        let incomingStartPosition:
            TimeInterval
        var lastProgress = 0.0
        var lastPublishedProgress = 0.0

        init(
            identifier: Int,
            outgoingDeckIndex: Int,
            incomingDeckIndex: Int,
            plan: AutoMixTransitionPlan,
            outgoingStartPosition:
                TimeInterval,
            incomingStartPosition:
                TimeInterval
        ) {
            self.identifier = identifier
            self.outgoingDeckIndex =
                outgoingDeckIndex
            self.incomingDeckIndex =
                incomingDeckIndex
            self.plan = plan
            self.outgoingStartPosition =
                outgoingStartPosition
            self.incomingStartPosition =
                incomingStartPosition
        }
    }

    private var preparationGeneration = 0
    private var baseVolume: Float = 1
    private var deckGains: [Float] = [1, 0]
    private var preparedTransition:
        PreparedTransition?
    private var activeTransition:
        ActiveTransition?
    private var envelopeTask:
        Task<Void, Never>?
    private var wantsPlayback = false

    var activeDeck: AudioPlaybackDeck {
        decks[activeDeckIndex]
    }

    var hasPreparedTransition: Bool {
        preparedTransition != nil
            || activeTransition != nil
    }

    private var standbyDeckIndex: Int {
        activeDeckIndex == 0 ? 1 : 0
    }

    init(equalizerConfiguration: AudioEqualizerConfiguration) {
        decks = [
            AudioPlaybackDeck(equalizerConfiguration: equalizerConfiguration),
            AudioPlaybackDeck(equalizerConfiguration: equalizerConfiguration),
        ]
        applyOutputVolumes()
    }

    deinit {
        envelopeTask?.cancel()
    }

    func prepare(
        _ source: PlaybackSource,
        identifier: Int,
        plan: AutoMixTransitionPlan
    ) async {
        guard plan.duration > 0 else { return }
        preparationGeneration += 1
        let generation = preparationGeneration
        clearStandbyDeck()
        let deckIndex = standbyDeckIndex
        let deck = decks[deckIndex]
        deckGains[deckIndex] = 0
        applyOutputVolumes()
        let ready = await deck.load(
            source, identifier: identifier, startAt: plan.incomingStartTime
        )
        guard generation == preparationGeneration,
              !Task.isCancelled, activeTransition == nil else { return }
        guard ready, let itemID = deck.itemID else {
            onPreparationFailed?(identifier, AutoMixPreparationError.itemFailed(deck.error))
            return
        }
        preparedTransition = PreparedTransition(
            identifier: identifier, deckIndex: deckIndex, itemID: itemID, plan: plan
        )
        startIfNeeded(wantsPlayback: wantsPlayback)
    }

    func cancel(wantsPlayback: Bool) {
        self.wantsPlayback = wantsPlayback
        preparationGeneration += 1
        envelopeTask?.cancel()
        envelopeTask = nil

        if let activeTransition {
            decks[
                activeTransition
                    .incomingDeckIndex
            ].clear()
            activeDeckIndex =
                activeTransition
                    .outgoingDeckIndex
        } else if let preparedTransition {
            decks[
                preparedTransition.deckIndex
            ].clear()
        } else {
            clearStandbyDeck()
        }

        preparedTransition = nil
        activeTransition = nil
        resetAutoMixEqualizers()
        deckGains = activeDeckIndex == 0
            ? [1, 0]
            : [0, 1]
        activeDeck.rate =
            wantsPlayback ? 1 : 0
        applyOutputVolumes()
        onTransitionProgress?(0)
    }

    func reset() {
        cancel(wantsPlayback: false)
        for deck in decks {
            deck.clear()
        }
        activeDeckIndex = 0
        deckGains = [1, 0]
        applyOutputVolumes()
    }

    func setVolume(_ volume: Double) {
        baseVolume = Float(
            min(max(volume, 0), 1)
        )
        applyOutputVolumes()
    }

    func pauseAll() {
        wantsPlayback = false
        for deck in decks {
            deck.pause()
        }
    }

    func resumeIncomingIfNeeded() {
        wantsPlayback = true
        guard let activeTransition else {
            return
        }
        let progress = currentProgress(
            for: activeTransition
        )
        decks[
            activeTransition.outgoingDeckIndex
        ].rate = outgoingRate(
            for: activeTransition,
            progress: progress
        )
        decks[
            activeTransition.incomingDeckIndex
        ].play(
            atRate:
                incomingRate(
                    for: activeTransition,
                    progress: progress
                )
        )
    }

    func startIfNeeded(wantsPlayback: Bool) {
        self.wantsPlayback = wantsPlayback
        guard activeTransition == nil, let preparedTransition, wantsPlayback,
              decks[preparedTransition.deckIndex].isReady,
              decks[preparedTransition.deckIndex].itemID == preparedTransition.itemID,
              let seconds = activeDeck.currentPlaybackTime,
              seconds >= preparedTransition.plan.outgoingStartTime else { return }
        start(preparedTransition)
    }

    func finishIfOutgoingEnded(at deckIndex: Int, wantsPlayback: Bool) -> Bool {
        self.wantsPlayback = wantsPlayback
        guard let activeTransition, activeTransition.outgoingDeckIndex == deckIndex else { return false }
        finish(activeTransition, wantsPlayback: wantsPlayback)
        return true
    }

    private func start(
        _ prepared: PreparedTransition
    ) {
        guard prepared.deckIndex
                == standbyDeckIndex,
              decks[prepared.deckIndex]
                .itemID
                == prepared.itemID else {
            return
        }
        let outgoingPosition =
            activeDeck.currentPlaybackTime
        let incomingPosition =
            decks[prepared.deckIndex]
                .currentPlaybackTime
        let transition = ActiveTransition(
            identifier: prepared.identifier,
            outgoingDeckIndex:
                activeDeckIndex,
            incomingDeckIndex:
                prepared.deckIndex,
            plan: prepared.plan,
            outgoingStartPosition:
                outgoingPosition
                    ?? prepared.plan
                        .outgoingStartTime,
            incomingStartPosition:
                incomingPosition
                    ?? prepared.plan
                        .incomingStartTime
        )
        preparedTransition = nil
        activeTransition = transition
        deckGains[
            transition.outgoingDeckIndex
        ] = 1
        deckGains[
            transition.incomingDeckIndex
        ] = 0
        applyAutoMixEqualizer(
            progress: 0,
            transition: transition
        )
        applyOutputVolumes()
        decks[transition.incomingDeckIndex].play(
                atRate:
                    incomingRate(
                        for: transition,
                        progress: 0
                    )
            )
        onTransitionBegan?(
            transition.identifier,
            transition.plan
        )
        runEnvelope(transition)
    }

    private func runEnvelope(
        _ transition: ActiveTransition
    ) {
        envelopeTask?.cancel()
        envelopeTask = Task {
            @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled,
                  let current =
                    self.activeTransition,
                  current.identifier
                    == transition.identifier {
                let progress =
                    self.currentProgress(
                        for: current
                    )
                let gains =
                    AutoMixFadeEnvelope.gains(
                        at: progress,
                        curve:
                            current.plan.fadeCurve
                    )
                self.deckGains[
                    current.outgoingDeckIndex
                ] = gains.outgoing
                self.deckGains[
                    current.incomingDeckIndex
                ] = gains.incoming
                self.applyAutoMixEqualizer(
                    progress: progress,
                    transition: current
                )
                self.applyOutputVolumes()

                let outgoingPlayer =
                    self.decks[
                        current.outgoingDeckIndex
                    ]
                let incomingPlayer =
                    self.decks[
                        current.incomingDeckIndex
                    ]
                if self.wantsPlayback {
                    outgoingPlayer.rate =
                        self.outgoingRate(
                            for: current,
                            progress: progress
                        )
                    incomingPlayer.rate =
                        self.incomingRate(
                            for: current,
                            progress: progress
                        )
                } else {
                    if outgoingPlayer.rate != 0 {
                        outgoingPlayer.pause()
                    }
                    if incomingPlayer.rate != 0 {
                        incomingPlayer.pause()
                    }
                }
                self.publishProgressIfNeeded(
                    progress,
                    transition: current
                )
                if progress >= 1 {
                    self.finish(
                        current,
                        wantsPlayback:
                            self.wantsPlayback
                    )
                    return
                }
                try? await Task.sleep(
                    for: .milliseconds(20)
                )
            }
        }
    }

    private func currentProgress(
        for transition: ActiveTransition
    ) -> Double {
        guard let outgoingPosition = decks[
                  transition.outgoingDeckIndex
              ].currentPlaybackTime,
              let incomingPosition = decks[
                  transition.incomingDeckIndex
              ].currentPlaybackTime else {
            return transition.lastProgress
        }

        let outgoingProgress =
            AutoMixTempoEnvelope.progress(
                forContentDuration:
                    max(
                        outgoingPosition
                            - transition
                                .outgoingStartPosition,
                        0
                    ),
                wallClockDuration:
                    transition.plan.duration,
                startRate: 1,
                endRate:
                    transition.plan
                        .outgoingEndPlaybackRate
            )
        let incomingProgress =
            AutoMixTempoEnvelope.progress(
                forContentDuration:
                    max(
                        incomingPosition
                            - transition
                                .incomingStartPosition,
                        0
                    ),
                wallClockDuration:
                    transition.plan.duration,
                startRate:
                    transition.plan
                        .incomingStartPlaybackRate,
                endRate: 1
            )
        transition.lastProgress = max(
            transition.lastProgress,
            min(
                max(
                    min(
                        outgoingProgress,
                        incomingProgress
                    ),
                    0
                ),
                1
            )
        )
        return transition.lastProgress
    }

    private func outgoingRate(
        for transition: ActiveTransition,
        progress: Double
    ) -> Float {
        AutoMixTempoEnvelope.playbackRate(
            at: progress,
            startRate: 1,
            endRate:
                transition.plan
                    .outgoingEndPlaybackRate
        )
    }

    private func incomingRate(
        for transition: ActiveTransition,
        progress: Double
    ) -> Float {
        AutoMixTempoEnvelope.playbackRate(
            at: progress,
            startRate:
                transition.plan
                    .incomingStartPlaybackRate,
            endRate: 1
        )
    }

    private func finish(
        _ transition: ActiveTransition,
        wantsPlayback: Bool
    ) {
        guard activeTransition?.identifier
                == transition.identifier else {
            return
        }
        envelopeTask?.cancel()
        envelopeTask = nil
        decks[
            transition.outgoingDeckIndex
        ].clear()
        activeDeckIndex =
            transition.incomingDeckIndex
        resetAutoMixEqualizers()
        activeDeck.rate =
            wantsPlayback ? 1 : 0
        deckGains = activeDeckIndex == 0
            ? [1, 0]
            : [0, 1]
        activeTransition = nil
        applyOutputVolumes()
        onActiveDeckChanged?()
        onTransitionProgress?(1)
        onTransitionCompleted?(
            transition.identifier
        )
    }

    func failPrepared(
        on deckIndex: Int,
        error: Error?
    ) {
        guard let preparedTransition,
              preparedTransition.deckIndex
                == deckIndex else {
            return
        }
        let identifier =
            preparedTransition.identifier
        decks[deckIndex].clear()
        self.preparedTransition = nil
        deckGains[deckIndex] = 0
        applyOutputVolumes()
        onPreparationFailed?(
            identifier,
            AutoMixPreparationError
                .itemFailed(error)
        )
    }

    private func clearStandbyDeck() {
        guard activeTransition == nil else {
            return
        }
        let index = standbyDeckIndex
        decks[index].clear()
        deckGains[index] = 0
        preparedTransition = nil
    }

    private func applyOutputVolumes() {
        for index in decks.indices {
            decks[index].volume =
                baseVolume * deckGains[index]
        }
    }

    private func applyAutoMixEqualizer(
        progress: Double,
        transition: ActiveTransition
    ) {
        let adjustments =
            AutoMixEqualizerEnvelope
                .adjustments(at: progress)
        decks[
            transition.outgoingDeckIndex
        ].setAutoMixEqualizer(
            lowGain:
                adjustments.outgoing.low,
            midGain:
                adjustments.outgoing.mid,
            highGain:
                adjustments.outgoing.high
        )
        decks[
            transition.incomingDeckIndex
        ].setAutoMixEqualizer(
            lowGain:
                adjustments.incoming.low,
            midGain:
                adjustments.incoming.mid,
            highGain:
                adjustments.incoming.high
        )
    }

    private func resetAutoMixEqualizers() {
        for deck in decks {
            deck.resetAutoMixEqualizer()
        }
    }

    private func publishProgressIfNeeded(
        _ progress: Double,
        transition: ActiveTransition
    ) {
        let minimumStep = max(
            0.004,
            0.08
                / max(
                    transition.plan.duration,
                    0.1
                )
        )
        guard progress >= 1
                || progress
                    - transition
                        .lastPublishedProgress
                    >= minimumStep else {
            return
        }
        transition.lastPublishedProgress =
            progress
        onTransitionProgress?(progress)
    }

    private func normalizedRate(
        _ rate: Double
    ) -> Float {
        Float(min(max(rate, 0.5), 2))
    }

}
