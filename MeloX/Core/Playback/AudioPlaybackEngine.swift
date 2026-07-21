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
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var notificationObservers: [NSObjectProtocol] = []
    private var wantsPlayback = false
    private var pendingSeekTime: TimeInterval = 0
    private var didReportCurrentItemFailure = false

    var hasCurrentItem: Bool {
        player.currentItem != nil
    }

    init() {
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

    func load(_ source: PlaybackSource, startAt: TimeInterval = 0, autoplay: Bool) {
        wantsPlayback = autoplay
        pendingSeekTime = max(0, startAt)
        didReportCurrentItemFailure = false
        itemStatusObserver?.invalidate()

        let item = AVPlayerItem(url: source.url)
        item.preferredForwardBufferDuration = 8
        observeStatus(of: item)
        player.replaceCurrentItem(with: item)
        transition(to: .loading)

        if autoplay {
            play()
        }
    }

    func unload() {
        wantsPlayback = false
        pendingSeekTime = 0
        didReportCurrentItemFailure = false
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        transition(to: .idle)
    }

    func play() {
        guard player.currentItem != nil else { return }
        wantsPlayback = true
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
        updateStateFromPlayer()
    }

    func seek(to seconds: TimeInterval) {
        guard player.currentItem != nil else { return }
        let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        onProgressChanged?(max(0, seconds))
    }

    func setVolume(_ volume: Double) {
        player.volume = Float(min(max(volume, 0), 1))
    }

    private func installPlayerObservers() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite {
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
            [weak self] _, _ in
            guard let engine = self else { return }
            Task { @MainActor [engine] in
                engine.handleCurrentItemStatusChange()
            }
        }
    }

    private func handleCurrentItemStatusChange() {
        guard let item = player.currentItem else { return }
        switch item.status {
        case .unknown:
            transition(to: .loading)
        case .readyToPlay:
            publishDurationIfAvailable()
            if pendingSeekTime > 0 {
                let time = pendingSeekTime
                pendingSeekTime = 0
                seek(to: time)
            }
            if wantsPlayback {
                player.play()
            }
            updateStateFromPlayer()
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
