import AVFoundation
import Combine
import Foundation

@MainActor
final class WatchPlaybackStore: ObservableObject {
    @Published private(set) var currentSong: WatchSong?
    @Published private var playbackQueue = WatchPlaybackQueue()
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var progress: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var repeatMode: WatchRepeatMode = .off
    @Published private(set) var volume: Double = 1
    @Published private(set) var errorMessage: String?
    @Published private(set) var effectiveStreamingQuality:
        WatchStreamingQuality?

    private let api: WatchNeteaseAPI
    private let player = WatchAudioPlaybackEngine()
    private var clockTask: Task<Void, Never>?
    private var interruptionObserver: NSObjectProtocol?
    private var loadGeneration = 0
    private var lastPersistenceDate = Date.distantPast
    private var wasPlayingBeforeInterruption = false

    var queue: [WatchSong] {
        playbackQueue.songs
    }

    var currentIndex: Int {
        playbackQueue.currentIndex
    }

    var isShuffled: Bool {
        playbackQueue.isShuffled
    }

    var playbackOrderIndices: [Int] {
        playbackQueue.playbackOrderIndices
    }

    init(api: WatchNeteaseAPI) {
        self.api = api
        volume = UserDefaults.standard.double(
            forKey: WatchPreferenceKey.volume
        )
        player.volume = Float(volume)
        restorePersistedSession()
        configureAudioSession()
        observePlayer()
        observeAudioSession()
    }

    func play(
        _ song: WatchSong,
        in songs: [WatchSong]? = nil
    ) async {
        if let songs, !songs.isEmpty {
            let index =
                songs.firstIndex(where: { $0.id == song.id }) ?? 0
            playbackQueue.replace(with: songs, startingAt: index)
        } else if let index = queue.firstIndex(where: { $0.id == song.id }) {
            playbackQueue.select(index: index)
        } else {
            playbackQueue.replace(with: [song], startingAt: 0)
        }
        currentSong = playbackQueue.currentSong
        await loadCurrentSong(
            autoplay: UserDefaults.standard.bool(
                forKey: WatchPreferenceKey.autoPlaySelection
            )
        )
    }

    func playQueueItem(at index: Int) async {
        guard playbackQueue.select(index: index) else { return }
        currentSong = playbackQueue.currentSong
        await loadCurrentSong(autoplay: true)
    }

    func togglePlayback() {
        guard currentSong != nil else { return }
        if !player.hasCurrentItem {
            let restoredPosition = progress
            Task {
                await loadCurrentSong(
                    autoplay: true,
                    restorePosition: restoredPosition
                )
            }
        } else if isPlaying {
            let pausedPosition = position(at: Date())
            player.pause()
            isPlaying = false
            progress = pausedPosition
            persistSession()
        } else {
            player.play()
            isPlaying = player.isPlaying
        }
    }

    func next() async {
        guard !queue.isEmpty else { return }
        guard playbackQueue.move(
            by: 1,
            wraps: repeatMode == .all
        ) else {
            player.pause()
            isPlaying = false
            persistSession()
            return
        }
        currentSong = playbackQueue.currentSong
        await loadCurrentSong(autoplay: true)
    }

    func previous() async {
        let behavior = WatchPreviousButtonBehavior(
            rawValue: UserDefaults.standard.string(
                forKey: WatchPreferenceKey.previousButtonBehavior
            ) ?? ""
        ) ?? .restartAfterFiveSeconds
        if behavior == .restartAfterFiveSeconds,
           position(at: Date()) > 5 {
            seek(to: 0)
            return
        }
        guard !queue.isEmpty else { return }
        guard playbackQueue.move(
            by: -1,
            wraps: repeatMode == .all
        ) else {
            return
        }
        currentSong = playbackQueue.currentSong
        await loadCurrentSong(autoplay: true)
    }

    func seek(to seconds: TimeInterval) {
        let target = max(0, min(seconds, duration))
        player.seek(to: target)
        progress = player.currentTime
        persistSession()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        persistSession()
    }

    func setRepeatMode(_ mode: WatchRepeatMode) {
        repeatMode = mode
        persistSession()
    }

    func toggleShuffle() {
        playbackQueue.setShuffleEnabled(!isShuffled)
        persistSession()
    }

    func setShuffleEnabled(_ isEnabled: Bool) {
        playbackQueue.setShuffleEnabled(isEnabled)
        persistSession()
    }

    func setPlaybackMode(
        isShuffled: Bool,
        repeatMode: WatchRepeatMode
    ) {
        playbackQueue.setShuffleEnabled(isShuffled)
        self.repeatMode = repeatMode
        persistSession()
    }

    func setVolume(_ value: Double) {
        volume = min(max(value, 0), 1)
        player.volume = Float(volume)
        UserDefaults.standard.set(
            volume,
            forKey: WatchPreferenceKey.volume
        )
    }

    func position(at date: Date) -> TimeInterval {
        player.hasCurrentItem ? player.currentTime : progress
    }

    func reloadForSelectedQuality() async {
        guard currentSong != nil else { return }
        let currentPosition = position(at: Date())
        let shouldResume = isPlaying
        await loadCurrentSong(
            autoplay: shouldResume,
            restorePosition: currentPosition
        )
    }

    func setRestoresLastSession(_ isEnabled: Bool) {
        if isEnabled {
            persistSession()
        } else {
            UserDefaults.standard.removeObject(
                forKey: WatchPersistedPlaybackSession.storageKey
            )
        }
    }

    private func loadCurrentSong(
        autoplay: Bool,
        restorePosition: TimeInterval? = nil
    ) async {
        guard let currentSong else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        isPlaying = false
        player.unload()
        errorMessage = nil
        effectiveStreamingQuality = nil

        do {
            let quality = WatchStreamingQuality(
                rawValue: UserDefaults.standard.string(
                    forKey: WatchPreferenceKey.streamingQuality
                ) ?? ""
            ) ?? .high
            let source = try await api.playbackSource(
                for: currentSong,
                quality: quality
            )
            guard generation == loadGeneration else { return }
            effectiveStreamingQuality = source.quality
            duration = currentSong.duration
            let targetPosition = min(max(restorePosition ?? 0, 0), max(duration, 0))
            progress = targetPosition
            try await player.load(source.url, startAt: targetPosition, autoplay: autoplay)
            guard generation == loadGeneration else { return }
            duration = player.duration
            progress = player.currentTime
            isLoading = false
            isPlaying = player.isPlaying
            persistSession()
        } catch {
            guard generation == loadGeneration else { return }
            isLoading = false
            isPlaying = false
            errorMessage = error.localizedDescription
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            if !session.supportsMultichannelContent {
                // Unsupported routes can still play a system-provided downmix.
                try? session.setSupportsMultichannelContent(true)
            }
            try session.setActive(true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        clockTask?.cancel()
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
    }

    private func observePlayer() {
        clockTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return }
                guard let self else { return }
                guard self.player.hasCurrentItem,
                      self.player.isPlaying || self.isPlaying else { continue }
                self.progress = self.player.currentTime
                self.duration = self.player.duration
                self.isPlaying = self.player.isPlaying
                if Date().timeIntervalSince(self.lastPersistenceDate) >= 5 { self.persistSession() }
            }
        }
        player.onEnded = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = false
                if self.repeatMode == .one {
                    self.seek(to: 0)
                    self.player.play()
                    self.isPlaying = self.player.isPlaying
                } else { await self.next() }
            }
        }
        player.onFailure = { [weak self] error in
            self?.isPlaying = false
            self?.isLoading = false
            self?.errorMessage = error.localizedDescription
        }
    }

    private func observeAudioSession() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            let rawType = notification.userInfo?[
                AVAudioSessionInterruptionTypeKey
            ] as? UInt
            let rawOptions = notification.userInfo?[
                AVAudioSessionInterruptionOptionKey
            ] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let rawType else { return }
                self?.handleAudioInterruption(
                    rawType: rawType,
                    rawOptions: rawOptions
                )
            }
        }
    }

    private func handleAudioInterruption(
        rawType: UInt,
        rawOptions: UInt
    ) {
        guard let type = AVAudioSession.InterruptionType(
            rawValue: rawType
        ) else {
            return
        }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            progress = position(at: Date())

            player.pause()
            isPlaying = false
        case .ended:
            let shouldResume = AVAudioSession.InterruptionOptions(
                rawValue: rawOptions
            )
            .contains(.shouldResume)
            if wasPlayingBeforeInterruption,
               shouldResume,
               UserDefaults.standard.bool(
                forKey: WatchPreferenceKey.resumesAfterInterruption
               ) {
                player.play()
                isPlaying = player.isPlaying

            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func restorePersistedSession() {
        guard UserDefaults.standard.bool(
            forKey: WatchPreferenceKey.restoresLastSession
        ),
        let data = UserDefaults.standard.data(
            forKey: WatchPersistedPlaybackSession.storageKey
        ),
        let session = try? JSONDecoder().decode(
            WatchPersistedPlaybackSession.self,
            from: data
        ),
        !session.queue.isEmpty else {
            return
        }

        playbackQueue.restore(
            songs: session.queue,
            currentIndex: session.currentIndex,
            isShuffled: session.isShuffled,
            shuffledOrder: session.shuffledOrder ?? []
        )
        currentSong = playbackQueue.currentSong
        duration = currentSong?.duration ?? 0
        progress = min(max(session.progress, 0), duration)

        repeatMode =
            WatchRepeatMode(rawValue: session.repeatMode) ?? .off
    }

    private func persistSession() {
        guard UserDefaults.standard.bool(
            forKey: WatchPreferenceKey.restoresLastSession
        ),
        !queue.isEmpty else {
            return
        }
        let session = WatchPersistedPlaybackSession(
            queue: queue,
            currentIndex: currentIndex,
            progress: position(at: Date()),
            repeatMode: repeatMode.rawValue,
            isShuffled: isShuffled,
            shuffledOrder: playbackQueue.shuffledOrder
        )
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(
            data,
            forKey: WatchPersistedPlaybackSession.storageKey
        )
        lastPersistenceDate = Date()
    }
}

private struct WatchPersistedPlaybackSession: Codable {
    static let storageKey = "melox.watch.playbackSession"

    let queue: [WatchSong]
    let currentIndex: Int
    let progress: TimeInterval
    let repeatMode: String
    let isShuffled: Bool
    let shuffledOrder: [Int]?
}
