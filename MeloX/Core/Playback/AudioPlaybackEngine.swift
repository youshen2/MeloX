import AVFoundation
import Foundation

enum AudioPlaybackState: Equatable {
    case idle
    case loading
    case paused
    case playing
}

enum AudioPlaybackError: LocalizedError {
    case audioSession(Error)
    case itemFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .audioSession(let error):
            "无法启用音频播放：\(error.localizedDescription)"
        case .itemFailed(let error):
            if let error {
                "音源载入失败：\(error.localizedDescription)"
            } else {
                "音源载入失败，请稍后重试。"
            }
        }
    }
}

@MainActor
final class AudioPlaybackEngine {
    var onStateChanged: ((AudioPlaybackState) -> Void)?
    var onProgressChanged: ((TimeInterval) -> Void)?
    var onDurationChanged: ((TimeInterval) -> Void)?
    var onPlaybackEnded: (() -> Void)?
    var onFailure: ((Error) -> Void)?
    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((Bool) -> Void)?
    var onOutputDeviceDisconnected: (() -> Void)?

    private(set) var state: AudioPlaybackState = .idle

    private let player = AVPlayer()
    private let equalizerProcessor: AudioEqualizerProcessor
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var notificationObservers: [NSObjectProtocol] = []
    private var wantsPlayback = false
    private var pendingSeekTime: TimeInterval = 0
    private var seekGeneration = 0
    private var suppressesProgressUpdates = false
    private var didReportCurrentItemFailure = false
    private var loadGeneration = 0

    var hasCurrentItem: Bool {
        player.currentItem != nil
    }

    var nowPlayingPlayer: AVPlayer {
        player
    }

    init(equalizerConfiguration: AudioEqualizerConfiguration) {
        equalizerProcessor = AudioEqualizerProcessor(
            configuration: equalizerConfiguration
        )
        player.automaticallyWaitsToMinimizeStalling = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        installPlayerObservers()
        installAudioSessionObservers()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func load(
        _ source: PlaybackSource,
        startAt: TimeInterval = 0,
        autoplay: Bool
    ) async {
        loadGeneration += 1
        let generation = loadGeneration
        wantsPlayback = autoplay
        pendingSeekTime = max(0, startAt)
        seekGeneration += 1
        suppressesProgressUpdates = pendingSeekTime > 0
        didReportCurrentItemFailure = false
        itemStatusObserver?.invalidate()
        transition(to: .loading)

        let asset = AVURLAsset(url: source.url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 8

        do {
            if let audioTrack = try await asset.loadTracks(
                withMediaType: .audio
            ).first {
                item.audioMix = equalizerProcessor.makeAudioMix(
                    for: audioTrack
                )
            }
        } catch {
            // AVPlayerItem will surface an actionable source error if playback
            // also fails. A missing track here should not prevent playback.
        }

        guard generation == loadGeneration, !Task.isCancelled else { return }
        observeStatus(of: item)
        player.replaceCurrentItem(with: item)

        if autoplay {
            play()
        }
    }

    func unload() {
        loadGeneration += 1
        wantsPlayback = false
        pendingSeekTime = 0
        seekGeneration += 1
        suppressesProgressUpdates = false
        didReportCurrentItemFailure = false
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        transition(to: .idle)
    }

    func play() {
        guard let item = player.currentItem else { return }
        wantsPlayback = true
        guard item.status == .readyToPlay, !suppressesProgressUpdates else {
            transition(to: .loading)
            return
        }
        do {
            try activateAudioSession()
            player.play()
            updateStateFromPlayer()
        } catch {
            wantsPlayback = false
            onFailure?(AudioPlaybackError.audioSession(error))
        }
    }

    func pause() {
        wantsPlayback = false
        player.pause()
        publishProgressIfAvailable()
        updateStateFromPlayer()
    }

    func seek(to seconds: TimeInterval) {
        guard let item = player.currentItem else { return }
        let position = max(0, seconds)
        seekGeneration += 1
        if item.status != .readyToPlay {
            pendingSeekTime = position
            suppressesProgressUpdates = position > 0
            onProgressChanged?(position)
            return
        }

        pendingSeekTime = 0
        suppressesProgressUpdates = false
        let target = CMTime(seconds: position, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        onProgressChanged?(position)
    }

    func setVolume(_ volume: Double) {
        player.volume = Float(min(max(volume, 0), 1))
    }

    func setEqualizerConfiguration(
        _ configuration: AudioEqualizerConfiguration
    ) {
        equalizerProcessor.update(configuration: configuration)
    }

    private func installPlayerObservers() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite, !self.suppressesProgressUpdates {
                    self.onProgressChanged?(max(0, seconds))
                }
                self.publishDurationIfAvailable()
            }
        }

        timeControlObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) {
            [weak self] _, _ in
            guard let engine = self else { return }
            Task { @MainActor [engine] in
                engine.updateStateFromPlayer()
            }
        }

        let center = NotificationCenter.default
        notificationObservers.append(
            center.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self,
                          notification.object as? AVPlayerItem === self.player.currentItem else { return }
                    self.onPlaybackEnded?()
                }
            }
        )
        notificationObservers.append(
            center.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self,
                          notification.object as? AVPlayerItem === self.player.currentItem else { return }
                    let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]
                        as? Error
                    self.fail(with: error)
                }
            }
        )
    }

    private func observeStatus(of item: AVPlayerItem) {
        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) {
            [weak self, weak item] _, _ in
            guard let engine = self, let item else { return }
            Task { @MainActor [engine, item] in
                engine.handleCurrentItemStatusChange(for: item)
            }
        }
    }

    private func handleCurrentItemStatusChange(for item: AVPlayerItem) {
        guard player.currentItem === item else { return }
        switch item.status {
        case .unknown:
            transition(to: .loading)
        case .readyToPlay:
            publishDurationIfAvailable()
            if pendingSeekTime > 0 {
                let position = pendingSeekTime
                pendingSeekTime = 0
                applyInitialSeek(to: position, for: item)
                return
            }
            suppressesProgressUpdates = false
            resumePlaybackIfNeeded()
        case .failed:
            fail(with: item.error)
        @unknown default:
            fail(with: item.error)
        }
    }

    private func updateStateFromPlayer() {
        guard let item = player.currentItem else {
            transition(to: .idle)
            return
        }
        if item.status == .failed {
            fail(with: item.error)
            return
        }
        if suppressesProgressUpdates {
            transition(to: .loading)
            return
        }
        switch player.timeControlStatus {
        case .paused:
            transition(to: item.status == .unknown ? .loading : .paused)
        case .waitingToPlayAtSpecifiedRate:
            transition(to: .loading)
        case .playing:
            transition(to: .playing)
        @unknown default:
            transition(to: .paused)
        }
    }

    private func publishDurationIfAvailable() {
        guard let seconds = player.currentItem?.duration.seconds,
              seconds.isFinite,
              seconds > 0 else { return }
        onDurationChanged?(seconds)
    }

    private func publishProgressIfAvailable() {
        guard !suppressesProgressUpdates else { return }
        let seconds = player.currentTime().seconds
        guard seconds.isFinite else { return }
        onProgressChanged?(max(0, seconds))
    }

    private func applyInitialSeek(to position: TimeInterval, for item: AVPlayerItem) {
        seekGeneration += 1
        let generation = seekGeneration
        let target = CMTime(seconds: position, preferredTimescale: 600)
        player.seek(
            to: target,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            guard let self else { return }
            Task { @MainActor [self] in
                guard generation == self.seekGeneration,
                      self.player.currentItem === item else { return }
                self.suppressesProgressUpdates = false
                if finished {
                    self.onProgressChanged?(position)
                } else {
                    self.publishProgressIfAvailable()
                }
                self.resumePlaybackIfNeeded()
            }
        }
    }

    private func resumePlaybackIfNeeded() {
        if wantsPlayback {
            play()
        } else {
            updateStateFromPlayer()
        }
    }

    private func fail(with error: Error?) {
        guard !didReportCurrentItemFailure else { return }
        didReportCurrentItemFailure = true
        wantsPlayback = false
        player.pause()
        transition(to: .paused)
        onFailure?(AudioPlaybackError.itemFailed(error))
    }

    private func transition(to newState: AudioPlaybackState) {
        guard state != newState else { return }
        state = newState
        onStateChanged?(newState)
    }

    private func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func installAudioSessionObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleInterruption(notification)
                }
            }
        )
        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleRouteChange(notification)
                }
            }
        )
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            onInterruptionBegan?()
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                .contains(.shouldResume)
            onInterruptionEnded?(shouldResume)
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else {
            return
        }
        pause()
        onOutputDeviceDisconnected?()
    }
}
