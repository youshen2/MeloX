"""Run the desktop engine/controller with deterministic decks, without audio.

Artifacts remain under the system temporary melox-tests.noindex directory.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
# Keep inspectable artifacts outside the checkout; no recursive deletion.
ARTIFACTS = Path(tempfile.gettempdir()) / "melox-tests.noindex"
ARTIFACTS.mkdir(parents=True, exist_ok=True)


def method(source, signature):
    start = source.index(signature)
    opening = source.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


STUBS = r'''
import Foundation
struct Song { let id: Int; var name: String { "song-\(id)" } }
struct PlaybackSource { let id: Int; let duration: Double }
struct AudioEqualizerConfiguration {}
enum SpatialAudioMode { case automatic }
enum AutoMixFadeCurve { case equalPower, smooth, linear }
struct AutoMixTransitionPlan {
    var outgoingStartTime: Double = 90
    var duration: Double = 10
    var incomingStartTime: Double = 10
    var outgoingEndPlaybackRate: Double = 1
    var incomingStartPlaybackRate: Double = 1
    var fadeCurve: AutoMixFadeCurve = .equalPower
}
enum L10n { static func string(_ key: String) -> String { key }
    static func format(_ key: String, _ args: CVarArg...) -> String { key } }
enum AudioPlaybackSessionConfigurator { static func activate() throws {} }
@MainActor enum AudioSpatializationPolicy {
    static func apply(_ mode: SpatialAudioMode, to deck: AudioPlaybackDeck) {}
}
@MainActor final class AudioPlaybackDeck {
    static var instances: [AudioPlaybackDeck] = []
    var onStateChanged: (() -> Void)?
    var onSeekCompleted: (() -> Void)?
    var onEnded: (() -> Void)?
    var onFailure: ((Error) -> Void)?
    var state: AudioPlaybackState = .idle
    var itemID: UUID?
    var itemIdentifier: Int?
    var error: Error?
    var time = 0.0
    var playbackDuration: Double?
    var volume: Float = 1
    var speed: Float = 1
    var hasCurrentItem: Bool { itemID != nil }
    var isReady: Bool { state == .playing || state == .paused }
    var currentPlaybackTime: Double? { hasCurrentItem ? time : nil }
    var rate: Float {
        get { state == .playing ? speed : 0 }
        set { if newValue == 0 { pause() } else { speed = newValue; play() } }
    }
    init(equalizerConfiguration: AudioEqualizerConfiguration) { Self.instances.append(self) }
    func load(_ source: PlaybackSource, identifier: Int? = nil,
              startAt: Double = 0, autoplay: Bool = false) async -> Bool {
        itemID = UUID(); itemIdentifier = identifier ?? source.id
        time = startAt; playbackDuration = source.duration
        setState(autoplay ? .playing : .paused); return true
    }
    func setState(_ value: AudioPlaybackState) {
        if state != value { state = value; onStateChanged?() }
    }
    func play() { setState(.playing) }
    func play(atRate value: Float) { rate = value }
    func pause() { setState(.paused) }
    func seek(to value: Double) { time = value; onSeekCompleted?() }
    func clear() { itemID = nil; itemIdentifier = nil; setState(.idle) }
    func setAutoMixEqualizer(lowGain: Float, midGain: Float, highGain: Float) {}
    func resetAutoMixEqualizer() {}
    func setEqualizerConfiguration(_ value: AudioEqualizerConfiguration) {}
}
struct PreparedAutoMixContext {
    let outgoingSongID: Int
    let incomingSong: Song
    let source: PlaybackSource
    let sourceIsDownloaded: Bool
}
@MainActor final class Coordinator {
    let engine: AudioPlaybackEngine
    var preparedContext: PreparedAutoMixContext?
    var transitionHasBegun = false
    var planningTask: Task<Void, Never>?
    var deckPreparationTask: Task<Void, Never>?
    var attempt: Int?
    var plannedTransition: Int?
    var latestRemainingTime = Double.infinity
    var latestPreloadLeadTime = 0.0
    var onTransitionBegan: ((PreparedAutoMixContext, AutoMixTransitionPlan) -> Void)?
    var onTransitionProgress: ((Double) -> Void)?
    var onPlaybackHandoff: ((PreparedAutoMixContext) -> Void)?
    var onTransitionCompleted: ((PreparedAutoMixContext) -> Void)?
    init(engine: AudioPlaybackEngine) { self.engine = engine; bindEngine() }
    func handlePreparationFailure(incomingSongID: Int) {}
    // COORDINATOR_BIND
}
@MainActor final class Fixture {
    let engine: AudioPlaybackEngine
    let coordinator: Coordinator
    let decks: [AudioPlaybackDeck]
    var presentedSongID = 1
    var handoffs = 0
    var completions = 0
    var clock: Double = 0
    var duration: Double = 0
    init() {
        engine = AudioPlaybackEngine(equalizerConfiguration: .init(), spatialAudioMode: .automatic)
        coordinator = Coordinator(engine: engine)
        decks = Array(AudioPlaybackDeck.instances.suffix(2))
        coordinator.onPlaybackHandoff = { [weak self] context in
            guard let self else { return }
            precondition(self.engine.currentPlaybackTime == self.decks[1].time)
            self.presentedSongID = context.incomingSong.id
            self.handoffs += 1
        }
        coordinator.onTransitionCompleted = { [weak self] _ in self?.completions += 1 }
        engine.onPlaybackClockChanged = { [weak self] sample in self?.clock = sample.position }
        engine.onDurationChanged = { [weak self] value in self?.duration = value }
    }
    func start() async {
        await engine.load(.init(id: 1, duration: 100), startAt: 90, autoplay: true)
        coordinator.preparedContext = .init(outgoingSongID: 1, incomingSong: .init(id: 2),
                                           source: .init(id: 2, duration: 240), sourceIsDownloaded: false)
        await engine.prepareAutoMix(.init(id: 2, duration: 240), identifier: 2, plan: .init())
    }
    func advance(_ fraction: Double) async throws {
        decks[0].time = 90 + fraction * 10
        decks[1].time = 10 + fraction * 10
        try await Task.sleep(for: .milliseconds(60))
    }
}
@main struct Checks {
    @MainActor static func main() async throws {
        let normal = Fixture(); await normal.start()
        try await normal.advance(0.49)
        precondition(normal.presentedSongID == 1 && normal.handoffs == 0)
        try await normal.advance(0.51)
        precondition(normal.presentedSongID == 2 && normal.handoffs == 1)
        precondition(abs(normal.clock - 15.1) < 0.01 && normal.duration == 240)
        precondition(normal.coordinator.transitionHasBegun && normal.coordinator.preparedContext != nil)
        try await normal.advance(0.9)
        precondition(normal.handoffs == 1 && normal.completions == 0)
        try await normal.advance(1)
        precondition(normal.handoffs == 1 && normal.completions == 1)
        precondition(!normal.coordinator.transitionHasBegun && normal.coordinator.preparedContext == nil)
        normal.engine.unload()
        print("PASS: metadata and incoming clock hand off at dominance; fade completion never advances twice")

        let early = Fixture(); await early.start()
        early.decks[0].onEnded?()
        precondition(early.handoffs == 1 && early.completions == 1 && early.presentedSongID == 2)
        early.engine.unload()
        print("PASS: early outgoing EOF performs the same one-time handoff")

        let before = Fixture(); await before.start()
        try await before.advance(0.2); before.engine.cancelAutoMix()
        precondition(before.engine.currentPlaybackTime == before.decks[0].time)
        precondition(before.decks[0].hasCurrentItem && !before.decks[1].hasCurrentItem)
        before.engine.unload()
        let after = Fixture(); await after.start()
        try await after.advance(0.6); after.engine.cancelAutoMix()
        precondition(after.engine.currentPlaybackTime == after.decks[1].time)
        precondition(after.decks[1].hasCurrentItem && !after.decks[0].hasCurrentItem)
        after.engine.unload()
        print("PASS: cancellation keeps the song that actually owns playback")

        let interrupted = Fixture()
        interrupted.coordinator.onPlaybackHandoff = { [weak interrupted] context in
            interrupted?.presentedSongID = context.incomingSong.id
            interrupted?.engine.cancelAutoMix()
        }
        await interrupted.start(); try await interrupted.advance(0.7)
        precondition(interrupted.engine.currentPlaybackTime == interrupted.decks[1].time)
        precondition(interrupted.completions == 0 && interrupted.presentedSongID == 2)
        interrupted.engine.unload()
        print("PASS: reentrant cancellation during handoff cannot finish a cancelled fade")
    }
}
'''


class AutoMixHandoffTests(unittest.TestCase):
    def test_engine_and_controller(self):
        base = ROOT / 'MeloXDesktop/Core/Playback'
        coordinator = (base / 'AutoMix/AutoMixPlaybackCoordinator.swift').read_text()
        source = STUBS.replace('// COORDINATOR_BIND', method(coordinator, '    private func bindEngine()'))
        for name in ['AutoMix/AutoMixFadeEnvelope.swift', 'AutoMix/AutoMixTempoEnvelope.swift',
                     'AutoMix/AutoMixEqualizerEnvelope.swift', 'AutoMix/AutoMixDeckTransitionController.swift',
                     'Engine/AudioPlaybackClockSample.swift', 'Engine/AudioPlaybackEngine.swift']:
            source += '\n' + (base / name).read_text()
        path = Path(tempfile.mkdtemp(prefix='handoff-checks-', dir=ARTIFACTS))
        (path / 'Checks.swift').write_text(source)
        subprocess.run(['swiftc', '-parse-as-library', str(path / 'Checks.swift'), '-o', str(path / 'checks')], check=True)
        subprocess.run([str(path / 'checks')], check=True)


if __name__ == '__main__':
    unittest.main()
