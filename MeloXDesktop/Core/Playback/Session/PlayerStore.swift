import Foundation
import Observation
import OSLog

private enum LyricsLiveActivityPublication: Equatable {
    case inactive
    case content(LyricsLiveActivityPublicationSignature)
}

private struct LyricsLiveActivityPublicationSignature: Equatable {
    let songID: Int
    let currentLyricID: LyricLine.ID?
    let nextLyricID: LyricLine.ID?
    let isPlaying: Bool
    let title: String
    let subtitle: String
    let compactText: String
    let compactScrollDistancePoints: Int
    let artworkURL: URL?
    let preferences: LyricsLiveActivityPreferences
    let durationMilliseconds: Int
}

private struct ListenTogetherSavedPlaybackOptions {
    let repeatMode: RepeatMode
    let wasShuffled: Bool
    let autoplayEnabled: Bool
    let autoMixEnabled: Bool
}

@MainActor
@Observable
final class PlayerStore {
    private static let beatAnalysisLogger = Logger(
        subsystem:
            Bundle.main.bundleIdentifier
                ?? "MeloX",
        category: "BeatNet"
    )

    private(set) var currentSong: Song?
    private(set) var isPlaying = false
    private(set) var progress: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var seekRevision = 0
    private(set) var isLoading = false
    private(set) var playbackIssue: PlaybackIssue?
    private(set) var volume: Double = 1
    private(set) var isListenTogetherSessionActive = false
    private(set) var isHeartModeActive = false
    private(set) var repeatMode: RepeatMode = .off
    private(set) var isAutoplayEnabled = false
    private(set) var isAutoMixEnabled = false
    private(set) var autoMixTransitionProgress: Double?
    private(set) var autoMixTransitionKind:
        AutoMixTransitionKind?
    private(set) var autoMixIncomingSongName: String?
    private(set) var queueModeIndicator:
        QueuePlaybackModeIndicator?
    private(set) var currentBeatTimeline:
        PlaybackBeatTimeline?
    private(set) var beatAnalysisStatus:
        PlaybackBeatAnalysisStatus = .idle
    private(set) var effectivePlaybackQuality: MusicQuality?
    private(set) var sleepTimer: PlaybackSleepTimer

    var availablePlaybackQualities: [MusicQuality] {
        guard currentSong != nil else { return [] }
        guard !isResolvingCurrentSongAudioAvailability else { return [] }
        if currentSongAudioAvailability.isKnown {
            return MusicQuality.allCases.filter { quality in
                currentSongAudioAvailability.supports(
                    apiLevel: quality.apiLevel
                ) == true || quality == effectivePlaybackQuality
            }
        }
        return effectivePlaybackQuality.map { [$0] } ?? []
    }

    private var playbackQueue = PlaybackQueue()

    var queue: [Song] { playbackQueue.songs }
    var currentIndex: Int { playbackQueue.currentIndex }
    var isShuffled: Bool { playbackQueue.isShuffled }
    var unplayedQueueIndices: [Int] {
        playbackQueue.upcomingIndices(wraps: false)
    }
    var upcomingQueueIndices: [Int] {
        playbackQueue.upcomingIndices(
            wraps: repeatMode == .all
        )
    }
    var queueModeBadgeSystemImage: String? {
        queueModeIndicator?.systemImage
    }
    var listenTogetherDisplaySongIDs: [Int] {
        queue.map(\.id)
    }
    var listenTogetherRandomSongIDs: [Int] {
        guard isShuffled else { return listenTogetherDisplaySongIDs }
        return playbackQueue.persistedShuffleOrder.compactMap { index in
            queue.indices.contains(index) ? queue[index].id : nil
        }
    }
    var isAutoMixTransitioning: Bool {
        autoMixTransitionProgress != nil
    }
    var canPlayNext: Bool {
        isAutoplayEnabled
            || (
                queue.count > 1
                    && playbackQueue.canMove(
                        by: 1,
                        wraps: repeatMode == .all
                    )
            )
    }

    @ObservationIgnored
    private let api: NeteaseAPI

    private var currentSongAudioAvailability:
        SongAudioAvailability = .unknown

    private var isResolvingCurrentSongAudioAvailability = false

    @ObservationIgnored
    private var detailedPlaybackSongs: [Song.ID: Song] = [:]

    @ObservationIgnored
    private var audioAvailabilityTask: Task<Void, Never>?

    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private let downloads: DownloadStore

    @ObservationIgnored
    private let engine: AudioPlaybackEngine

    @ObservationIgnored
    private let beatAnalyzer: AutoMixAudioAnalyzer

    @ObservationIgnored
    private let autoMixCoordinator:
        AutoMixPlaybackCoordinator

    @ObservationIgnored
    private let nowPlayingSession: NowPlayingSession

    @ObservationIgnored
    private let lyricsLiveActivityController:
        LyricsLiveActivityController

    @ObservationIgnored
    private let lyricsNotificationController:
        LyricsNotificationController

    @ObservationIgnored
    private let persistence: PlaybackPersistence

    @ObservationIgnored
    private let historyRecorder: PlaybackHistoryRecorder

    @ObservationIgnored
    private var loadGeneration = 0

    @ObservationIgnored
    private var beatAnalysisGeneration = 0

    @ObservationIgnored
    private var beatAnalysisTask:
        Task<Void, Never>?

    @ObservationIgnored
    private var isResolvingSource = false

    @ObservationIgnored
    private var hasRestoredPlayback = false

    @ObservationIgnored
    private var shouldResumeAfterInterruption = false

    @ObservationIgnored
    private var lastPersistedSecond = -1

    @ObservationIgnored
    private var playbackTimelineClock = PlaybackTimelineClock()

    @ObservationIgnored
    private var historySourceID: Int?

    @ObservationIgnored
    private var hasRecordedCurrentStart = false

    @ObservationIgnored
    private var isUsingDownloadedSource = false

    @ObservationIgnored
    private var currentLoadShouldAutoplay = false

    @ObservationIgnored
    private var currentPlaybackSource: PlaybackSource?

    @ObservationIgnored
    private var isLoadingAutoplayRecommendations = false

    @ObservationIgnored
    private var nowPlayingLyricsSongID: Int?

    @ObservationIgnored
    private var nowPlayingLyrics: [LyricLine] = []

    @ObservationIgnored
    private var publishedNowPlayingLyricID: LyricLine.ID?

    @ObservationIgnored
    private var publishedLyricsLiveActivity:
        LyricsLiveActivityPublication?

    @ObservationIgnored
    private var listenTogetherSavedPlaybackOptions:
        ListenTogetherSavedPlaybackOptions?

    init(
        api: NeteaseAPI,
        settings: AppSettings,
        downloads: DownloadStore,
        lyricsNotificationController:
            LyricsNotificationController,
        persistence: PlaybackPersistence? = nil,
        onPlaybackRecorded: @escaping (Song) -> Void = { _ in }
    ) {
        self.api = api
        self.settings = settings
        self.downloads = downloads
        self.persistence = persistence ?? PlaybackPersistence()
        historyRecorder = PlaybackHistoryRecorder(
            api: api,
            settings: settings,
            onRecorded: onPlaybackRecorded
        )
        let engine = AudioPlaybackEngine(
            equalizerConfiguration: settings.equalizer.configuration,
            spatialAudioMode: settings.spatialAudioMode
        )
        self.engine = engine
        let beatAnalyzer = AutoMixAudioAnalyzer()
        self.beatAnalyzer = beatAnalyzer
        autoMixCoordinator = AutoMixPlaybackCoordinator(
            api: api,
            downloads: downloads,
            engine: engine,
            analyzer: beatAnalyzer
        )
        nowPlayingSession = NowPlayingSession(
            players: engine.nowPlayingPlayers
        )
        lyricsLiveActivityController = LyricsLiveActivityController()
        self.lyricsNotificationController =
            lyricsNotificationController
        sleepTimer = PlaybackSleepTimer()
        bindEngine()
        bindAutoMixCoordinator()
        bindRemoteCommands()
        applyVolumeControlMode()
        sleepTimer.setExpirationHandler { [weak self] in
            guard let self else { return }
            self.engine.pause()
            self.persistSnapshot()
        }
    }

    func restore() async {
        guard !hasRestoredPlayback else { return }
        hasRestoredPlayback = true
        guard let snapshot = persistence.load(), !snapshot.queue.isEmpty else {
            lyricsLiveActivityController.synchronize(with: nil)
            lyricsNotificationController.clear()
            return
        }

        playbackQueue.restore(
            songs: snapshot.queue,
            currentIndex: snapshot.currentIndex,
            isShuffled: snapshot.isShuffled,
            shuffledOrder: snapshot.shuffledOrder
        )
        currentSong = playbackQueue.currentSong
        duration = TimeInterval(currentSong?.durationMS ?? 0) / 1_000
        progress = clampedPlaybackPosition(snapshot.progress)
        reanchorPlaybackTimeline(to: progress, rate: 0)
        repeatMode = RepeatMode(rawValue: snapshot.repeatMode) ?? .off
        volume = min(max(snapshot.volume, 0), 1)
        historySourceID = snapshot.historySourceID
        isHeartModeActive = snapshot.heartModeEnabled ?? false
        isAutoplayEnabled = snapshot.autoplayEnabled ?? false
        isAutoMixEnabled = snapshot.autoMixEnabled ?? false
        updateQueueModeIndicator(
            preferred: snapshot.queueModeIndicator.flatMap(
                QueuePlaybackModeIndicator.init(rawValue:)
            )
        )
        applyVolumeControlMode()

        await loadCurrentSong(
            autoplay: false,
            startAt: progress
        )
    }

    func beginListenTogetherSession() {
        guard listenTogetherSavedPlaybackOptions == nil else { return }
        listenTogetherSavedPlaybackOptions =
            ListenTogetherSavedPlaybackOptions(
                repeatMode: repeatMode,
                wasShuffled: isShuffled,
                autoplayEnabled: isAutoplayEnabled,
                autoMixEnabled: isAutoMixEnabled
            )
        isListenTogetherSessionActive = true
        repeatMode = .all
        if isShuffled {
            playbackQueue.toggleShuffle()
        }
        isAutoplayEnabled = false
        isAutoMixEnabled = false
        isHeartModeActive = false
        cancelAutoMixPreparation()
        updateQueueModeIndicator()
        persistSnapshot()
    }

    func endListenTogetherSession() {
        guard let saved = listenTogetherSavedPlaybackOptions else {
            return
        }
        listenTogetherSavedPlaybackOptions = nil
        isListenTogetherSessionActive = false
        repeatMode = saved.repeatMode
        if isShuffled != saved.wasShuffled {
            playbackQueue.toggleShuffle()
        }
        isAutoplayEnabled = saved.autoplayEnabled
        isAutoMixEnabled = saved.autoMixEnabled
        updateQueueModeIndicator()
        persistSnapshot()
        prepareAutoMixIfNeeded()
    }

    func synchronizeListenTogetherPlayback(
        songs: [Song],
        targetSongID: Int,
        progress targetProgress: TimeInterval,
        isPlaying shouldPlay: Bool,
        shouldSeek: Bool,
        playMode: String?
    ) async {
        guard !songs.isEmpty,
              let targetIndex = songs.firstIndex(where: {
                  $0.id == targetSongID
              }) else {
            return
        }

        isHeartModeActive = false
        applyListenTogetherPlayMode(playMode)
        let queueChanged = songs.map(\.id) != queue.map(\.id)
        let songChanged = currentSong?.id != targetSongID

        if songChanged {
            recordCurrentPlayback()
        }
        if queueChanged {
            cancelAutoMixPreparation()
            playbackQueue.replace(
                with: songs,
                startingAt: targetIndex
            )
            historySourceID = nil
        } else if currentIndex != targetIndex {
            _ = playbackQueue.select(index: targetIndex)
        }

        if songChanged || !engine.hasCurrentItem {
            hasRecordedCurrentStart = false
            await loadCurrentSong(
                autoplay: shouldPlay,
                startAt: max(targetProgress, 0)
            )
            return
        }

        currentSong = songs[targetIndex]
        nowPlayingSession.setSong(
            songs[targetIndex],
            duration: duration,
            queueIndex: currentIndex,
            queueCount: queue.count,
            lyricsDisplaySettings:
                nowPlayingLyricsDisplaySettings
        )

        if shouldSeek,
           abs(estimatedProgress() - targetProgress) > 0.35 {
            seek(to: targetProgress)
        }

        if shouldPlay {
            playbackIssue = nil
            engine.play()
        } else {
            engine.pause()
        }
        updateNowPlayingState()
        persistSnapshot()
    }

    private func applyListenTogetherPlayMode(_ playMode: String?) {
        guard isListenTogetherSessionActive,
              let mode = playMode?.uppercased() else {
            return
        }
        if mode.contains("SINGLE") {
            repeatMode = .one
        } else if mode.contains("LOOP") {
            repeatMode = .all
        } else {
            repeatMode = .off
        }
        if isShuffled {
            playbackQueue.toggleShuffle()
        }
        updateQueueModeIndicator()
    }

    func play(
        _ song: Song,
        in songs: [Song]? = nil,
        sourceID: Int? = nil,
        startAt: TimeInterval = 0
    ) async {
        recordCurrentPlayback()
        isHeartModeActive = false
        if let songs, !songs.isEmpty {
            let index = songs.firstIndex(where: { $0.id == song.id }) ?? 0
            playbackQueue.replace(with: songs, startingAt: index)
            historySourceID = sourceID
        } else if let existingIndex = queue.firstIndex(where: { $0.id == song.id }) {
            _ = playbackQueue.select(index: existingIndex)
        } else {
            playbackQueue.replace(with: [song], startingAt: 0)
            historySourceID = sourceID
        }
        hasRecordedCurrentStart = false
        let maximumPosition = TimeInterval(song.durationMS) / 1_000
        let playbackPosition = maximumPosition > 0
            ? max(0, min(startAt, maximumPosition))
            : max(0, startAt)
        await loadCurrentSong(
            autoplay: true,
            startAt: playbackPosition
        )
    }

    func playAll(_ songs: [Song], sourceID: Int? = nil) async {
        await replaceQueueAndPlay(
            songs,
            sourceID: sourceID,
            activatesHeartMode: false
        )
    }

    func playHeartMode(
        playlistID: Int,
        seedSongID: Int
    ) async throws {
        let songs = try await api.intelligenceModeSongs(
            seedSongID: seedSongID,
            playlistID: playlistID
        )
        try Task.checkCancellation()
        await replaceQueueAndPlay(
            songs,
            sourceID: playlistID,
            activatesHeartMode: true
        )
    }

    func disableHeartMode() {
        guard isHeartModeActive else { return }
        isHeartModeActive = false
        persistSnapshot()
    }

    private func replaceQueueAndPlay(
        _ songs: [Song],
        sourceID: Int?,
        activatesHeartMode: Bool
    ) async {
        guard !songs.isEmpty else { return }
        recordCurrentPlayback()
        playbackQueue.replace(with: songs, startingAt: 0)
        historySourceID = sourceID
        isHeartModeActive = activatesHeartMode
        hasRecordedCurrentStart = false
        await loadCurrentSong(autoplay: true)
    }

    func togglePlayback() {
        guard currentSong != nil else { return }
        if isLoading {
            playbackIssue = nil
            currentLoadShouldAutoplay = true
            engine.play()
            updateNowPlayingState()
            return
        }
        if engine.hasCurrentItem {
            if isPlaying {
                engine.pause()
                persistSnapshot()
            } else {
                playbackIssue = nil
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
        await loadCurrentSong(
            autoplay: true,
            startAt: estimatedProgress()
        )
    }

    func dismissPlaybackIssue() {
        playbackIssue = nil
    }

    func selectPlaybackQuality(_ quality: MusicQuality) {
        guard settings.quality != quality else { return }
        let shouldAutoplay = isPlaying
            || (isLoading && currentLoadShouldAutoplay)
        let resumePosition = engine.currentPlaybackTime
            ?? estimatedProgress()
        let songID = currentSong?.id
        settings.quality = quality
        guard let songID else { return }
        seekRevision += 1
        let qualityChangeRevision = seekRevision
        Task { @MainActor [weak self] in
            guard let self,
                  self.currentSong?.id == songID else { return }
            let startPosition =
                self.seekRevision == qualityChangeRevision
                ? resumePosition
                : self.estimatedProgress()
            await self.loadCurrentSong(
                autoplay: shouldAutoplay,
                startAt: startPosition
            )
        }
    }

    func next() async {
        await moveToNext(recordingCurrentPlayback: true)
    }

    private func moveToNext(recordingCurrentPlayback: Bool) async {
        guard !queue.isEmpty else { return }
        if !playbackQueue.canMove(
            by: 1,
            wraps: repeatMode == .all
        ), isAutoplayEnabled {
            await appendAutoplayRecommendationsIfNeeded()
        }
        if recordingCurrentPlayback {
            recordCurrentPlayback()
        }
        guard playbackQueue.canMove(
            by: 1,
            wraps: repeatMode == .all
        ) else {
            stopAtQueueEnd()
            return
        }
        guard playbackQueue.move(by: 1, wraps: repeatMode == .all) else {
            stopAtQueueEnd()
            return
        }
        hasRecordedCurrentStart = false
        await loadCurrentSong(autoplay: true)
    }

    func previous() async {
        guard !queue.isEmpty else { return }
        if settings.previousRestartsCurrentSong, progress > 5 {
            seek(to: 0)
            return
        }
        guard playbackQueue.canMove(by: -1, wraps: repeatMode == .all) else {
            seek(to: 0)
            return
        }
        recordCurrentPlayback()
        guard playbackQueue.move(by: -1, wraps: repeatMode == .all) else { return }
        hasRecordedCurrentStart = false
        await loadCurrentSong(autoplay: true)
    }

    func playFromQueue(at index: Int) async {
        guard queue.indices.contains(index) else { return }
        recordCurrentPlayback()
        guard playbackQueue.select(index: index) else { return }
        hasRecordedCurrentStart = false
        await loadCurrentSong(autoplay: true)
    }

    func addToPlaybackQueue(_ song: Song) {
        cancelAutoMixPreparation()
        playbackQueue.append(song)
        persistSnapshot()
        prepareAutoMixIfNeeded()
    }

    func clearUpcomingQueue() {
        cancelAutoMixPreparation()
        playbackQueue.clearUpcoming()
        persistSnapshot()
        prepareAutoMixIfNeeded()
    }

    var upcomingQueueEntries: [(queueIndex: Int, song: Song)] {
        playbackQueue.upcomingIndices(wraps: false).compactMap { index in
            guard queue.indices.contains(index) else { return nil }
            return (index, queue[index])
        }
    }

    var historyQueueEntries: [(queueIndex: Int, song: Song)] {
        playbackQueue.historyIndices().compactMap { index in
            guard queue.indices.contains(index) else { return nil }
            return (index, queue[index])
        }
    }

    func clearPlaybackHistory() {
        playbackQueue.clearHistory()
        persistSnapshot()
    }

    func removeFromPlaybackQueue(at index: Int) {
        cancelAutoMixPreparation()
        guard playbackQueue.remove(at: index) else { return }
        persistSnapshot()
        prepareAutoMixIfNeeded()
    }

    func playNext(_ song: Song) async {
        guard currentSong != nil, !queue.isEmpty else {
            await play(song)
            return
        }

        cancelAutoMixPreparation()
        playbackQueue.insertNext(song)
        persistSnapshot()
        prepareAutoMixIfNeeded()
    }

    func moveUpcomingQueueItems(
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) {
        cancelAutoMixPreparation()
        playbackQueue.moveUpcomingSongs(
            fromOffsets: source,
            toOffset: destination,
            wraps: repeatMode == .all
        )
        persistSnapshot()
        prepareAutoMixIfNeeded()
    }

    func seek(to seconds: TimeInterval) {
        let clamped = clampedPlaybackPosition(seconds)
        cancelAutoMixPreparation()
        progress = clamped
        reanchorPlaybackTimeline(to: clamped, rate: 0)
        seekRevision += 1
        engine.seek(to: clamped)
        updateNowPlayingState(
            forceNowPlayingLyrics: true,
            forceLyricsLiveActivity: true
        )
        persistSnapshot()
    }

    func setNowPlayingLyrics(_ lyrics: [LyricLine], for songID: Int?) {
        guard let songID, currentSong?.id == songID else { return }
        nowPlayingLyricsSongID = songID
        nowPlayingLyrics = lyrics
        updateNowPlayingLyricMetadata()
        updateLyricsLiveActivity()
        updateLyricsNotification()
    }

    func applySystemNowPlayingLyricsPreference() {
        updateNowPlayingLyricMetadata(force: true)
    }

    func applyLyricsLiveActivityPreference() {
        updateLyricsLiveActivity(force: true)
    }

    func applyLyricsNotificationPreference() {
        updateLyricsNotification(force: true)
    }

    func refreshLyricsNotification() {
        updateLyricsNotification()
    }

    func presentLyricsNotificationPreview() {
        let song = currentSong
        let lyrics = currentSongLyrics
        lyricsNotificationController.presentPreview(
            song: song,
            lyrics: lyrics,
            playbackTime:
                estimatedProgress()
                    + settings.effectiveLyricsAdvanceTime(
                        for: lyrics
                    )
        )
    }

    func refreshLyricsLiveActivity() {
        updateLyricsLiveActivity(force: true)
    }

    func estimatedProgress(at date: Date = Date()) -> TimeInterval {
        playbackTimelineClock.position(
            at: date,
            duration: playbackDurationLimit
        )
    }

    private var playbackDurationLimit: TimeInterval {
        if duration.isFinite, duration > 0 {
            return duration
        }
        return TimeInterval(currentSong?.durationMS ?? 0) / 1_000
    }

    private func clampedPlaybackPosition(
        _ position: TimeInterval
    ) -> TimeInterval {
        let normalized = position.isFinite
            ? max(position, 0)
            : 0
        let maximum = playbackDurationLimit
        guard maximum.isFinite, maximum > 0 else {
            return normalized
        }
        return min(normalized, maximum)
    }

    private func reanchorPlaybackTimeline(
        to position: TimeInterval,
        rate: Double,
        at date: Date = Date()
    ) {
        playbackTimelineClock.reanchor(
            to: position,
            rate: rate,
            at: date
        )
    }

    func beatDebugSnapshot(
        at date: Date = Date()
    ) -> PlaybackBeatDebugSnapshot? {
        currentBeatTimeline?.debugSnapshot(
            at: estimatedProgress(at: date)
        )
    }

    func clearCurrentSongBeatAnalysis() {
        resetBeatAnalysis()
    }

    func clearPlaybackAnalysisCache() async {
        cancelAutoMixPreparation()
        resetBeatAnalysis()
        await beatAnalyzer.clearCache()
        scheduleBeatAnalysisIfNeeded()
        prepareAutoMixIfNeeded()
    }

    @discardableResult
    func analyzeCurrentSongBeats() async -> PlaybackBeatTimeline? {
        guard let song = currentSong,
              !song.isPodcastProgram,
              let source = currentPlaybackSource else {
            currentBeatTimeline = nil
            beatAnalysisStatus = .idle
            return nil
        }
        if let currentBeatTimeline {
            return currentBeatTimeline
        }
        if case .analyzing = beatAnalysisStatus {
            return nil
        }

        beatAnalysisGeneration += 1
        let generation = beatAnalysisGeneration
        let songID = song.id
        beatAnalysisStatus = .analyzing
        let request = AutoMixAnalysisRequest(
            songID: songID,
            source: source,
            duration: max(
                duration,
                TimeInterval(song.durationMS) / 1_000
            ),
            isDownloaded: isUsingDownloadedSource
        )

        do {
            let analysis = try await beatAnalyzer.analyzeFullTrack(
                request
            )
            try Task.checkCancellation()
            guard generation == beatAnalysisGeneration,
                  currentSong?.id == songID,
                  currentPlaybackSource == source else {
                return nil
            }
            guard let timeline = PlaybackBeatTimeline(
                analysis: analysis
            ) else {
                throw AutoMixAnalysisError
                    .invalidModelOutput
            }
            currentBeatTimeline = timeline
            beatAnalysisStatus = .ready(
                bpm: timeline.bpm,
                confidence: timeline.confidence
            )
            return timeline
        } catch is CancellationError {
            guard generation == beatAnalysisGeneration else {
                return nil
            }
            restoreBeatAnalysisStatus()
            return nil
        } catch {
            guard generation == beatAnalysisGeneration,
                  currentSong?.id == songID,
                  currentPlaybackSource == source else {
                return nil
            }
            beatAnalysisStatus = .failed(
                message: error.localizedDescription
            )
            Self.beatAnalysisLogger.error(
                "Beat analysis failed for song \(songID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func resetBeatAnalysis() {
        beatAnalysisTask?.cancel()
        beatAnalysisTask = nil
        beatAnalysisGeneration += 1
        currentBeatTimeline = nil
        beatAnalysisStatus = .idle
    }

    private func scheduleBeatAnalysisIfNeeded() {
        guard settings.playerBackgroundStyle
            == .flowingLight,
            settings
                .playerBackgroundBeatEffectsEnabled,
            currentSong?.isPodcastProgram == false,
            currentPlaybackSource != nil,
            currentBeatTimeline == nil else {
            return
        }
        if case .analyzing = beatAnalysisStatus {
            return
        }

        beatAnalysisTask?.cancel()
        beatAnalysisTask = Task {
            [weak self] in
            await self?.analyzeCurrentSongBeats()
        }
    }

    private func restoreBeatAnalysisStatus() {
        if let currentBeatTimeline {
            beatAnalysisStatus = .ready(
                bpm: currentBeatTimeline.bpm,
                confidence:
                    currentBeatTimeline.confidence
            )
        } else {
            beatAnalysisStatus = .idle
        }
    }

    func setVolume(_ value: Double) {
        volume = min(max(value, 0), 1)
        applyVolumeControlMode()
        persistSnapshot()
    }

    func applyVolumeControlMode() {
        let effectiveVolume = settings.playerVolumeControlMode == .independent
            ? volume
            : 1
        engine.setVolume(effectiveVolume)
    }

    func applyEqualizerSettings() {
        engine.setEqualizerConfiguration(settings.equalizer.configuration)
    }

    func applySpatialAudioSettings() {
        engine.setSpatialAudioMode(settings.spatialAudioMode)
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off:
            setRepeatMode(.all)
        case .all:
            setRepeatMode(.one)
        case .one:
            setRepeatMode(.off)
        }
    }

    func setRepeatMode(_ mode: RepeatMode) {
        guard !isListenTogetherSessionActive,
              repeatMode != mode else { return }
        cancelAutoMixPreparation()
        repeatMode = mode
        updateQueueModeIndicator()
        persistSnapshot()
    }

    func toggleShuffle() {
        guard !isListenTogetherSessionActive else { return }
        cancelAutoMixPreparation()
        playbackQueue.toggleShuffle()
        if isShuffled {
            queueModeIndicator = .shuffle
        } else {
            updateQueueModeIndicator()
        }
        persistSnapshot()
    }

    func toggleAutoplay() {
        guard !isListenTogetherSessionActive else { return }
        isAutoplayEnabled.toggle()
        if isAutoplayEnabled {
            queueModeIndicator = .autoplay
        } else {
            updateQueueModeIndicator()
        }
        persistSnapshot()
        guard isAutoplayEnabled else { return }

        Task { @MainActor [weak self] in
            await self?.appendAutoplayRecommendationsIfNeeded()
        }
    }

    func toggleAutoMix() {
        guard !isListenTogetherSessionActive else { return }
        setAutoMixEnabled(!isAutoMixEnabled)
    }

    func setAutoMixEnabled(_ isEnabled: Bool) {
        guard !isListenTogetherSessionActive else { return }
        guard isAutoMixEnabled != isEnabled else { return }
        isAutoMixEnabled = isEnabled
        if isEnabled {
            queueModeIndicator = .autoMix
        } else {
            updateQueueModeIndicator()
            cancelAutoMixPreparation()
        }
        persistSnapshot()
        if isEnabled {
            prepareAutoMixIfNeeded()
        }
    }

    func applyAutoMixSettings() {
        cancelAutoMixPreparation()
        persistSnapshot()
        guard isAutoMixEnabled else { return }
        prepareAutoMixIfNeeded()
    }

    private func loadCurrentSong(
        autoplay: Bool,
        startAt: TimeInterval = 0
    ) async {
        guard let song = playbackQueue.currentSong else { return }
        cancelAutoMixPreparation()
        loadGeneration += 1
        let generation = loadGeneration
        currentSong = song
        let cachedDetailedSong = detailedPlaybackSongs[song.id]
        resolveCurrentSongAudioAvailability(
            for: song,
            generation: generation
        )
        resetBeatAnalysis()
        duration = TimeInterval(song.durationMS) / 1_000
        let playbackStartPosition = clampedPlaybackPosition(startAt)
        progress = playbackStartPosition
        reanchorPlaybackTimeline(
            to: playbackStartPosition,
            rate: 0
        )
        isResolvingSource = true
        isLoading = true
        isPlaying = false
        isUsingDownloadedSource = false
        currentPlaybackSource = nil
        effectivePlaybackQuality = nil
        currentLoadShouldAutoplay = autoplay
        playbackIssue = nil
        if nowPlayingLyricsSongID != song.id {
            nowPlayingLyricsSongID = nil
            nowPlayingLyrics = []
            publishedNowPlayingLyricID = nil
        }
        engine.unload()
        nowPlayingSession.setSong(
            song,
            duration: duration,
            queueIndex: currentIndex,
            queueCount: queue.count,
            lyricsDisplaySettings: nowPlayingLyricsDisplaySettings
        )
        updateNowPlayingState()
        persistSnapshot()

        do {
            let source: PlaybackSource
            if let downloadedSource = downloads.localPlaybackSource(songID: song.id) {
                source = downloadedSource
                isUsingDownloadedSource = true
            } else if let cachedDetailedSong {
                source = try await api.playbackSource(
                    for: cachedDetailedSong
                )
            } else {
                // A list response can contain only part of the quality
                // metadata. Let the v1 source endpoint try the requested
                // level while song details resolve in parallel.
                source = try await api.playbackSource(id: song.id)
            }
            guard generation == loadGeneration, currentSong?.id == song.id else { return }
            isResolvingSource = false
            currentPlaybackSource = source
            effectivePlaybackQuality = source.quality
            let shouldAutoplay = currentLoadShouldAutoplay
            let resolvedStartPosition = estimatedProgress()
            await engine.load(
                source,
                startAt: resolvedStartPosition,
                autoplay: shouldAutoplay
            )
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration, currentSong?.id == song.id else { return }
            isResolvingSource = false
            isLoading = false
            isPlaying = false
            playbackIssue = PlaybackIssue(song: song, error: error)
            updateNowPlayingState()
            persistSnapshot()
        }
    }

    private func handlePlaybackEnded() async {
        recordCurrentPlayback(completed: true)
        if repeatMode == .one {
            hasRecordedCurrentStart = false
            seek(to: 0)
            engine.play()
            return
        }
        await moveToNext(recordingCurrentPlayback: false)
    }

    private func handleEngineFailure(_ error: Error) async {
        if let playbackError = error as? AudioPlaybackError,
           case .itemFailed = playbackError,
           isUsingDownloadedSource,
           let song = currentSong {
            let resumePosition = estimatedProgress()
            let shouldAutoplay = currentLoadShouldAutoplay
            isUsingDownloadedSource = false
            downloads.discardInvalidDownload(songID: song.id)
            await loadCurrentSong(
                autoplay: shouldAutoplay,
                startAt: resumePosition
            )
            return
        }

        if let song = currentSong {
            playbackIssue = PlaybackIssue(song: song, error: error)
        }
        isLoading = false
        isPlaying = false
        updateNowPlayingState()

        if let playbackError = error as? AudioPlaybackError,
           case .itemFailed = playbackError {
            engine.unload()
        }
        persistSnapshot()
    }

    private func stopAtQueueEnd() {
        cancelAutoMixPreparation()
        engine.pause()
        engine.seek(to: 0)
        progress = 0
        reanchorPlaybackTimeline(to: 0, rate: 0)
        seekRevision += 1
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
                if self.engine.expectsPlaybackToContinue {
                    self.isLoading = true
                    self.currentLoadShouldAutoplay = true
                } else {
                    self.isLoading = false
                }
            case .playing:
                self.isPlaying = true
                self.isLoading = false
                self.currentLoadShouldAutoplay = true
                self.playbackIssue = nil
                self.recordCurrentPlaybackStartIfNeeded()
                self.scheduleBeatAnalysisIfNeeded()
                self.prepareAutoMixIfNeeded()
            }
            self.updateNowPlayingState()
        }
        engine.onPlaybackClockChanged = { [weak self] sample in
            self?.handlePlaybackClockSample(sample)
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

    private func handlePlaybackClockSample(
        _ sample: AudioPlaybackClockSample
    ) {
        let measuredProgress = clampedPlaybackPosition(
            sample.position
        )
        progress = measuredProgress
        reanchorPlaybackTimeline(
            to: measuredProgress,
            rate: sample.rate,
            at: sample.sampledAt
        )
        updateNowPlayingLyricMetadata()
        updateLyricsLiveActivity()
        updateLyricsNotification()
        let second = Int(measuredProgress)
        if second != lastPersistedSecond {
            lastPersistedSecond = second
            persistSnapshot()
        }
        prepareAutoMixIfNeeded()
    }

    private func bindAutoMixCoordinator() {
        autoMixCoordinator.onTransitionBegan = {
            [weak self] context, plan in
            guard let self,
                  context.outgoingSongID
                    == self.currentSong?.id else {
                return
            }
            self.autoMixTransitionKind = plan.kind
            self.autoMixIncomingSongName =
                context.incomingSong.name
            self.autoMixTransitionProgress = 0
        }
        autoMixCoordinator.onTransitionProgress = {
            [weak self] progress in
            guard let self,
                  self.autoMixTransitionProgress != nil else {
                return
            }
            self.autoMixTransitionProgress = progress
        }
        autoMixCoordinator.onTransitionCompleted = {
            [weak self] context in
            self?.completeAutoMixTransition(
                context: context
            )
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
        nowPlayingSession.onTogglePlayPause = { [weak self] in
            self?.togglePlayback()
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

    private func updateNowPlayingState(
        forceNowPlayingLyrics: Bool = false,
        forceLyricsLiveActivity: Bool = false
    ) {
        updateNowPlayingLyricMetadata(
            force: forceNowPlayingLyrics
        )
        updateLyricsLiveActivity(force: forceLyricsLiveActivity)
        updateLyricsNotification()
        nowPlayingSession.updatePlayback(
            position: progress,
            duration: duration,
            isPlaying: isPlaying
        )
    }

    private func updateNowPlayingLyricMetadata(
        force: Bool = false
    ) {
        guard let song = currentSong else { return }
        let lyrics = currentSongLyrics
        let advanceTime = settings.effectiveLyricsAdvanceTime(
            for: lyrics
        )
        let highlightedLyricID = settings.systemNowPlayingLyricsEnabled
            ? LyricPlaybackTimeline.position(
                at: estimatedProgress() + advanceTime,
                in: lyrics
            ).highlightedLyricID
            : nil
        guard force
                || highlightedLyricID
                    != publishedNowPlayingLyricID else {
            return
        }

        let currentLyric = highlightedLyricID.flatMap { lyricID in
            lyrics.first(where: { $0.id == lyricID })
        }
        publishedNowPlayingLyricID = highlightedLyricID
        nowPlayingSession.updateCurrentLyric(
            currentLyric?.text,
            for: song,
            lyricsDisplaySettings: nowPlayingLyricsDisplaySettings
        )
    }

    private func updateLyricsLiveActivity(force: Bool = false) {
        guard let song = currentSong,
              shouldPresentLyricsLiveActivity else {
            publishLyricsLiveActivity(
                .inactive,
                snapshot: nil,
                force: force
            )
            return
        }
        guard settings.lyricsLiveActivityEnabled else {
            publishLyricsLiveActivity(
                .inactive,
                snapshot: nil,
                force: force
            )
            return
        }

        let lyrics = currentSongLyrics
        let adjustedProgress = estimatedProgress()
            + settings.effectiveLyricsAdvanceTime(for: lyrics)
        let position = LyricPlaybackTimeline.position(
            at: adjustedProgress,
            in: lyrics
        )
        let currentLyricIndex = position.highlightedLyricID.flatMap {
            lyricID in
            lyrics.firstIndex(where: { $0.id == lyricID })
        }
        let currentLyric = currentLyricIndex.map { lyrics[$0] }
        let nextLyric: LyricLine? = if let currentLyricIndex {
            lyrics.indices.contains(currentLyricIndex + 1)
                ? lyrics[currentLyricIndex + 1]
                : nil
        } else {
            lyrics.first
        }
        let preferences = LyricsLiveActivityPreferences(
            settings: settings
        )
        let displayText = LyricsLiveActivityFormatter.text(
            songTitle: song.name,
            songArtist: song.artistText,
            currentLyric: currentLyric?.text,
            preferences: preferences
        )
        let artworkURL = preferences.showsArtwork
            ? song.album?.artworkURL
            : nil
        let compactScrollDistance =
            lyricsLiveActivityCompactScrollDistance(
                text: displayText.compact,
                currentLyric: currentLyric,
                nextTransitionTime: position.nextTransitionTime,
                adjustedProgress: adjustedProgress,
                preferences: preferences
            )
        let signature = LyricsLiveActivityPublicationSignature(
            songID: song.id,
            currentLyricID: currentLyric?.id,
            nextLyricID: preferences.showsNextLyric
                ? nextLyric?.id
                : nil,
            isPlaying: isPlaying,
            title: displayText.title,
            subtitle: displayText.subtitle,
            compactText: displayText.compact,
            compactScrollDistancePoints:
                Int(compactScrollDistance.rounded()),
            artworkURL: artworkURL,
            preferences: preferences,
            durationMilliseconds: Int((duration * 1_000).rounded())
        )
        let snapshot = LyricsLiveActivitySnapshot(
            songID: song.id,
            title: displayText.title,
            subtitle: displayText.subtitle,
            compactText: displayText.compact,
            compactScrollDistance: compactScrollDistance,
            nextLyric: preferences.showsNextLyric
                ? nextLyric?.text
                : nil,
            artworkURL: artworkURL,
            presentation: preferences.presentation,
            isPlaying: isPlaying,
            playbackPosition: estimatedProgress(),
            duration: duration,
            staleDate: nil
        )
        publishLyricsLiveActivity(
            .content(signature),
            snapshot: snapshot,
            force: force
        )
    }

    private func updateLyricsNotification(force: Bool = false) {
        let lyrics = currentSongLyrics
        lyricsNotificationController.update(
            song: currentSong,
            lyrics: lyrics,
            playbackTime:
                estimatedProgress()
                    + settings.effectiveLyricsAdvanceTime(
                        for: lyrics
                    ),
            isPlaying: isPlaying,
            force: force
        )
    }

    private var currentSongLyrics: [LyricLine] {
        guard let songID = currentSong?.id,
              nowPlayingLyricsSongID == songID else {
            return []
        }
        return nowPlayingLyrics
    }

    private var shouldPresentLyricsLiveActivity: Bool {
        isPlaying || (isLoading && currentLoadShouldAutoplay)
    }

    private func publishLyricsLiveActivity(
        _ publication: LyricsLiveActivityPublication,
        snapshot: LyricsLiveActivitySnapshot?,
        force: Bool
    ) {
        guard force || publication != publishedLyricsLiveActivity else {
            return
        }
        publishedLyricsLiveActivity = publication
        lyricsLiveActivityController.synchronize(with: snapshot)
    }

    private func lyricsLiveActivityCompactScrollDistance(
        text: String,
        currentLyric: LyricLine?,
        nextTransitionTime: TimeInterval?,
        adjustedProgress: TimeInterval,
        preferences: LyricsLiveActivityPreferences
    ) -> Double {
        let pointSize = preferences.compactTextSize.pointSize
        guard preferences.scrollsCompactText,
              LyricsLiveActivityCompactLayout.requiresScrolling(
                text: text,
                pointSize: pointSize
              )
        else {
            return 0
        }

        guard let currentLyric else { return 0 }
        let startTime = currentLyric.time
        let elapsed = max(adjustedProgress - startTime, 0)
        let scrollDistance =
            LyricsLiveActivityCompactLayout
                .scrollDistanceToRevealEnd(
                    text: text,
                    pointSize: pointSize
                )
        guard scrollDistance > 0 else { return 0 }

        let configuredPause = max(
            preferences.scrollPause,
            0
        )
        let lineEndTime = nextTransitionTime
            ?? currentLyric.duration.map {
                currentLyric.time + $0
            }
        let timing: (pause: TimeInterval, speed: Double) = {
            guard let lineEndTime else {
                return (
                    configuredPause,
                    max(preferences.scrollSpeed, 1)
                )
            }

            let lineDuration = max(
                lineEndTime - currentLyric.time,
                0.25
            )
            let pause = min(
                configuredPause,
                lineDuration * 0.2
            )
            // ActivityKit updates are delivered asynchronously. Keep the
            // completed tail visible long enough for the last page to arrive
            // before the lyric transition.
            let endingHold = min(
                1.25,
                lineDuration * 0.25
            )
            let availableTravelTime = max(
                lineDuration - pause - endingHold,
                0.25
            )
            let requiredSpeed =
                scrollDistance / availableTravelTime
            return (
                pause,
                max(
                    max(preferences.scrollSpeed, requiredSpeed),
                    1
                )
            )
        }()

        let travelDistance = min(
            max(elapsed - timing.pause, 0) * timing.speed,
            scrollDistance
        )
        return travelDistance.rounded()
    }

    private var nowPlayingLyricsDisplaySettings:
        NowPlayingLyricsDisplaySettings {
        NowPlayingLyricsDisplaySettings(
            isEnabled:
                settings.systemNowPlayingLyricsEnabled
                && currentSong?.isPodcastProgram != true,
            titleFormat: settings.systemNowPlayingLyricsTitleFormat,
            subtitleFormat: settings.systemNowPlayingLyricsSubtitleFormat
        )
    }

    private func recordCurrentPlayback(completed: Bool = false) {
        guard hasRecordedCurrentStart,
              let currentSong,
              !currentSong.isPodcastProgram else {
            return
        }
        historyRecorder.recordPlaybackDuration(
            song: currentSong,
            sourceID: historySourceID,
            playbackTime: estimatedProgress(),
            completed: completed
        )
    }

    private func recordCurrentPlaybackStartIfNeeded() {
        guard !hasRecordedCurrentStart, let currentSong else { return }
        hasRecordedCurrentStart = true
        guard !currentSong.isPodcastProgram else { return }
        historyRecorder.recordRecentPlayback(
            song: currentSong,
            sourceID: historySourceID
        )
        downloads.recordPlayback(currentSong)
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
                volume: volume,
                historySourceID: historySourceID,
                heartModeEnabled: isHeartModeActive,
                autoplayEnabled: isAutoplayEnabled,
                autoMixEnabled: isAutoMixEnabled,
                queueModeIndicator: queueModeIndicator?.rawValue
            )
        )
    }

    private func updateQueueModeIndicator(
        preferred: QueuePlaybackModeIndicator? = nil
    ) {
        if let preferred, isModeActive(preferred) {
            queueModeIndicator = preferred
            return
        }

        if repeatMode == .one {
            queueModeIndicator = .repeatOne
        } else if repeatMode == .all {
            queueModeIndicator = .repeatAll
        } else if isShuffled {
            queueModeIndicator = .shuffle
        } else if isAutoplayEnabled {
            queueModeIndicator = .autoplay
        } else if isAutoMixEnabled {
            queueModeIndicator = .autoMix
        } else {
            queueModeIndicator = nil
        }
    }

    private func isModeActive(
        _ mode: QueuePlaybackModeIndicator
    ) -> Bool {
        switch mode {
        case .shuffle:
            isShuffled
        case .repeatAll:
            repeatMode == .all
        case .repeatOne:
            repeatMode == .one
        case .autoplay:
            isAutoplayEnabled
        case .autoMix:
            isAutoMixEnabled
        }
    }

    private func appendAutoplayRecommendationsIfNeeded() async {
        guard isAutoplayEnabled,
              !isLoadingAutoplayRecommendations,
              playbackQueue.upcomingIndices(wraps: false).isEmpty,
              let currentSong,
              !currentSong.isPodcastProgram else {
            return
        }

        isLoadingAutoplayRecommendations = true
        defer { isLoadingAutoplayRecommendations = false }

        do {
            let recommendations = try await api.similarSongs(
                id: currentSong.id
            )
            guard isAutoplayEnabled else { return }
            let existingSongIDs = Set(queue.map(\.id))
            let newSongs = recommendations.filter {
                !existingSongIDs.contains($0.id)
            }
            playbackQueue.append(
                contentsOf: Array(newSongs.prefix(25))
            )
            persistSnapshot()
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    private func prepareAutoMixIfNeeded() {
        let nextSong = upcomingQueueIndices.first.flatMap {
            queue.indices.contains($0)
                ? queue[$0]
                : nil
        }
        autoMixCoordinator.prepareIfNeeded(
            isEnabled:
                isAutoMixEnabled
                && currentSong?.isPodcastProgram != true
                && nextSong?.isPodcastProgram != true,
            isPlaying: isPlaying,
            repeatsCurrentSong: repeatMode == .one,
            outgoingSong: currentSong,
            outgoingSource: currentPlaybackSource,
            outgoingSourceIsDownloaded:
                isUsingDownloadedSource,
            outgoingDuration: duration,
            outgoingProgress: estimatedProgress(),
            incomingSong: nextSong,
            configuration: settings.autoMix.configuration
        )
    }

    private func cancelAutoMixPreparation() {
        autoMixTransitionProgress = nil
        autoMixTransitionKind = nil
        autoMixIncomingSongName = nil
        autoMixCoordinator.cancel()
    }

    private func completeAutoMixTransition(
        context: PreparedAutoMixContext
    ) {
        guard context.outgoingSongID == currentSong?.id else {
            cancelAutoMixPreparation()
            return
        }

        recordCurrentPlayback(completed: true)
        guard playbackQueue.move(
            by: 1,
            wraps: repeatMode == .all
        ),
              playbackQueue.currentSong?.id
                == context.incomingSong.id else {
            cancelAutoMixPreparation()
            return
        }

        loadGeneration += 1
        let generation = loadGeneration
        currentSong = context.incomingSong
        resolveCurrentSongAudioAvailability(
            for: context.incomingSong,
            generation: generation
        )
        resetBeatAnalysis()
        currentPlaybackSource = context.source
        effectivePlaybackQuality = context.source.quality
        isUsingDownloadedSource =
            context.sourceIsDownloaded
        currentLoadShouldAutoplay = true
        isResolvingSource = false
        isLoading = engine.state == .loading
        isPlaying = engine.state == .playing
        playbackIssue = nil
        hasRecordedCurrentStart = false
        lastPersistedSecond = Int(progress)
        nowPlayingLyricsSongID = nil
        nowPlayingLyrics = []
        publishedNowPlayingLyricID = nil
        publishedLyricsLiveActivity = nil

        autoMixTransitionProgress = nil
        autoMixTransitionKind = nil
        autoMixIncomingSongName = nil

        nowPlayingSession.setSong(
            context.incomingSong,
            duration: duration,
            queueIndex: currentIndex,
            queueCount: queue.count,
            lyricsDisplaySettings:
                nowPlayingLyricsDisplaySettings
        )
        if isPlaying {
            recordCurrentPlaybackStartIfNeeded()
        }
        updateNowPlayingState(
            forceNowPlayingLyrics: true,
            forceLyricsLiveActivity: true
        )
        persistSnapshot()
        scheduleBeatAnalysisIfNeeded()
        prepareAutoMixIfNeeded()
    }

    private func resolveCurrentSongAudioAvailability(
        for song: Song,
        generation: Int
    ) {
        audioAvailabilityTask?.cancel()
        if let detailedSong = detailedPlaybackSongs[song.id] {
            currentSongAudioAvailability =
                detailedSong.audioAvailability
            isResolvingCurrentSongAudioAvailability = false
            audioAvailabilityTask = nil
            return
        }

        currentSongAudioAvailability = song.audioAvailability
        isResolvingCurrentSongAudioAvailability = true
        audioAvailabilityTask = Task { @MainActor [weak self] in
            guard let api = self?.api else { return }
            let detailedSong: Song?
            do {
                detailedSong = try await api.songDetails(
                    ids: [song.id]
                ).first
            } catch is CancellationError {
                return
            } catch {
                detailedSong = nil
            }
            guard let self,
                  !Task.isCancelled,
                  generation == loadGeneration,
                  currentSong?.id == song.id else { return }
            if let detailedSong {
                detailedPlaybackSongs[song.id] = detailedSong
                currentSongAudioAvailability =
                    detailedSong.audioAvailability
            }
            isResolvingCurrentSongAudioAvailability = false
            audioAvailabilityTask = nil
        }
    }
}
