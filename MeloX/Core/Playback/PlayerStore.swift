import Foundation
import Observation

@MainActor
@Observable
final class PlayerStore {
    private(set) var currentSong: Song?
    private(set) var isPlaying = false
    private(set) var progress: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var seekRevision = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var volume: Double = 1
    private(set) var repeatMode: RepeatMode = .off

    private var playbackQueue = PlaybackQueue()

    var queue: [Song] { playbackQueue.songs }
    var currentIndex: Int { playbackQueue.currentIndex }
    var isShuffled: Bool { playbackQueue.isShuffled }

    @ObservationIgnored
    private let api: NeteaseAPI

    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private let engine: AudioPlaybackEngine

    @ObservationIgnored
    private let nowPlayingSession: NowPlayingSession

    @ObservationIgnored
    private let persistence: PlaybackPersistence

    @ObservationIgnored
    private var loadGeneration = 0

    @ObservationIgnored
    private var isResolvingSource = false

    @ObservationIgnored
    private var hasRestoredPlayback = false

    @ObservationIgnored
    private var shouldResumeAfterInterruption = false

    @ObservationIgnored
    private var currentFailureAttempt = 0

    @ObservationIgnored
    private var lastPersistedSecond = -1

    @ObservationIgnored
    private var lastProgressUpdateDate = Date()

    init(
        api: NeteaseAPI,
        settings: AppSettings,
        persistence: PlaybackPersistence? = nil
    ) {
        self.api = api
        self.settings = settings
        self.persistence = persistence ?? PlaybackPersistence()
        engine = AudioPlaybackEngine()
        nowPlayingSession = NowPlayingSession(player: engine.nowPlayingPlayer)
        bindEngine()
        bindRemoteCommands()
        engine.setVolume(volume)
    }

    func restore() async {
        guard !hasRestoredPlayback else { return }
        hasRestoredPlayback = true
        guard let snapshot = persistence.load(), !snapshot.queue.isEmpty else { return }

        playbackQueue.restore(
            songs: snapshot.queue,
            currentIndex: snapshot.currentIndex,
            isShuffled: snapshot.isShuffled,
            shuffledOrder: snapshot.shuffledOrder
        )
        currentSong = playbackQueue.currentSong
        progress = max(snapshot.progress, 0)
        lastProgressUpdateDate = Date()
        duration = TimeInterval(currentSong?.durationMS ?? 0) / 1_000
        repeatMode = RepeatMode(rawValue: snapshot.repeatMode) ?? .off
        volume = min(max(snapshot.volume, 0), 1)
        engine.setVolume(volume)

        await loadCurrentSong(
            autoplay: false,
            startAt: progress,
            failureAttempt: 0
        )
    }

    func play(_ song: Song, in songs: [Song]? = nil) async {
        if let songs, !songs.isEmpty {
            let index = songs.firstIndex(where: { $0.id == song.id }) ?? 0
            playbackQueue.replace(with: songs, startingAt: index)
        } else if let existingIndex = queue.firstIndex(where: { $0.id == song.id }) {
            _ = playbackQueue.select(index: existingIndex)
        } else {
            playbackQueue.replace(with: [song], startingAt: 0)
        }
        await loadCurrentSong(autoplay: true)
    }

    func playAll(_ songs: [Song]) async {
        guard !songs.isEmpty else { return }
        playbackQueue.replace(with: songs, startingAt: 0)
        await loadCurrentSong(autoplay: true)
    }

    func togglePlayback() {
        guard currentSong != nil else { return }
        if engine.hasCurrentItem {
            if isPlaying {
                engine.pause()
                persistSnapshot()
            } else {
                errorMessage = nil
                engine.play()
            }
        } else {
            Task { @MainActor [weak self] in
                await self?.retry()
            }
        }
    }

    func retry() async {
        guard currentSong != nil else { return }
        await loadCurrentSong(autoplay: true)
    }

    func reloadCurrentSongForQualityChange() async {
        guard currentSong != nil else { return }
        let shouldAutoplay = isPlaying
        let resumePosition = estimatedProgress()
        await loadCurrentSong(
            autoplay: shouldAutoplay,
            startAt: resumePosition
        )
    }

    func next() async {
        guard !queue.isEmpty else { return }
        guard playbackQueue.move(by: 1, wraps: repeatMode == .all) else {
            stopAtQueueEnd()
            return
        }
        await loadCurrentSong(autoplay: true)
    }

    func previous() async {
        guard !queue.isEmpty else { return }
        if settings.previousRestartsCurrentSong, progress > 5 {
            seek(to: 0)
            return
        }
        guard playbackQueue.move(by: -1, wraps: repeatMode == .all) else {
            seek(to: 0)
            return
        }
        await loadCurrentSong(autoplay: true)
    }

    func playFromQueue(at index: Int) async {
        guard playbackQueue.select(index: index) else { return }
        await loadCurrentSong(autoplay: true)
    }

    func seek(to seconds: TimeInterval) {
        let maximum = duration > 0 ? duration : TimeInterval(currentSong?.durationMS ?? 0) / 1_000
        let clamped = max(0, min(seconds, maximum))
        engine.seek(to: clamped)
        progress = clamped
        seekRevision += 1
        lastProgressUpdateDate = Date()
        updateNowPlayingState()
        persistSnapshot()
    }

    func estimatedProgress(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return progress }
        let elapsed = max(date.timeIntervalSince(lastProgressUpdateDate), 0)
        let maximum = duration > 0 ? duration : TimeInterval(currentSong?.durationMS ?? 0) / 1_000
        let estimated = progress + elapsed
        return maximum > 0 ? min(estimated, maximum) : estimated
    }

    func setVolume(_ value: Double) {
        volume = min(max(value, 0), 1)
        engine.setVolume(volume)
        persistSnapshot()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        persistSnapshot()
    }

    func toggleShuffle() {
        playbackQueue.toggleShuffle()
        persistSnapshot()
    }

    private func loadCurrentSong(
        autoplay: Bool,
        startAt: TimeInterval = 0,
        failureAttempt: Int = 0
    ) async {
        guard let song = playbackQueue.currentSong else { return }
        loadGeneration += 1
        let generation = loadGeneration
        currentFailureAttempt = failureAttempt
        currentSong = song
        progress = max(0, startAt)
        lastProgressUpdateDate = Date()
        duration = TimeInterval(song.durationMS) / 1_000
        isResolvingSource = true
        isLoading = true
        isPlaying = false
        errorMessage = nil
        engine.unload()
        nowPlayingSession.setSong(
            song,
            duration: duration,
            queueIndex: currentIndex,
            queueCount: queue.count
        )
        updateNowPlayingState()
        persistSnapshot()

        do {
            let source = try await api.playbackSource(id: song.id)
            guard generation == loadGeneration, currentSong?.id == song.id else { return }
            isResolvingSource = false
            engine.load(source, startAt: startAt, autoplay: autoplay)
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration, currentSong?.id == song.id else { return }
            isResolvingSource = false
            isLoading = false
            isPlaying = false
            errorMessage = error.localizedDescription
            updateNowPlayingState()
            if autoplay {
                await advancePastFailure(attempt: failureAttempt + 1)
            }
        }
    }

    private func advancePastFailure(attempt: Int) async {
        guard attempt < queue.count,
              playbackQueue.move(by: 1, wraps: repeatMode == .all) else {
            engine.unload()
            isLoading = false
            isPlaying = false
            persistSnapshot()
            return
        }
        await loadCurrentSong(autoplay: true, failureAttempt: attempt)
    }

    private func handlePlaybackEnded() async {
        if repeatMode == .one {
            seek(to: 0)
            engine.play()
            return
        }
        await next()
    }

    private func handleEngineFailure(_ error: Error) async {
        errorMessage = error.localizedDescription
        isLoading = false
        isPlaying = false
        updateNowPlayingState()

        guard let playbackError = error as? AudioPlaybackError,
              case .itemFailed = playbackError else {
            persistSnapshot()
            return
        }
        await advancePastFailure(attempt: currentFailureAttempt + 1)
    }

    private func stopAtQueueEnd() {
        engine.pause()
        engine.seek(to: 0)
        progress = 0
        lastProgressUpdateDate = Date()
        isPlaying = false
        isLoading = false
        updateNowPlayingState()
        persistSnapshot()
    }

    private func bindEngine() {
        engine.onStateChanged = { [weak self] state in
            guard let self else { return }
            switch state {
            case .idle:
                self.isPlaying = false
                if !self.isResolvingSource {
                    self.isLoading = false
                }
            case .loading:
                self.isPlaying = false
                self.isLoading = true
            case .paused:
                self.isPlaying = false
                self.isLoading = false
            case .playing:
                self.isPlaying = true
                self.isLoading = false
                self.errorMessage = nil
                self.currentFailureAttempt = 0
            }
            self.lastProgressUpdateDate = Date()
            self.updateNowPlayingState()
        }
        engine.onProgressChanged = { [weak self] value in
            guard let self else { return }
            self.progress = value
            self.lastProgressUpdateDate = Date()
            let second = Int(value)
            if second != self.lastPersistedSecond {
                self.lastPersistedSecond = second
                self.persistSnapshot()
            }
        }
        engine.onDurationChanged = { [weak self] value in
            guard let self else { return }
            self.duration = value
            self.updateNowPlayingState()
        }
        engine.onPlaybackEnded = { [weak self] in
            Task { @MainActor in
                await self?.handlePlaybackEnded()
            }
        }
        engine.onFailure = { [weak self] error in
            Task { @MainActor in
                await self?.handleEngineFailure(error)
            }
        }
        engine.onInterruptionBegan = { [weak self] in
            guard let self else { return }
            self.shouldResumeAfterInterruption = self.isPlaying
            self.engine.pause()
        }
        engine.onInterruptionEnded = { [weak self] shouldResume in
            guard let self else { return }
            if shouldResume, self.shouldResumeAfterInterruption {
                self.engine.play()
            }
            self.shouldResumeAfterInterruption = false
        }
        engine.onOutputDeviceDisconnected = { [weak self] in
            self?.shouldResumeAfterInterruption = false
        }
    }

    private func bindRemoteCommands() {
        nowPlayingSession.onPlay = { [weak self] in
            guard let self else { return }
            if self.engine.hasCurrentItem {
                self.engine.play()
            } else {
                Task { @MainActor in await self.retry() }
            }
        }
        nowPlayingSession.onPause = { [weak self] in
            self?.engine.pause()
        }
        nowPlayingSession.onNext = { [weak self] in
            Task { @MainActor in await self?.next() }
        }
        nowPlayingSession.onPrevious = { [weak self] in
            Task { @MainActor in await self?.previous() }
        }
        nowPlayingSession.onSeek = { [weak self] position in
            self?.seek(to: position)
        }
    }

    private func updateNowPlayingState() {
        nowPlayingSession.updatePlayback(
            position: progress,
            duration: duration,
            isPlaying: isPlaying
        )
    }

    private func persistSnapshot() {
        guard !queue.isEmpty else {
            persistence.clear()
            return
        }
        persistence.save(
            PlaybackSnapshot(
                queue: queue,
                currentIndex: currentIndex,
                progress: progress,
                repeatMode: repeatMode.rawValue,
                isShuffled: isShuffled,
                shuffledOrder: playbackQueue.persistedShuffleOrder,
                volume: volume
            )
        )
    }
}
