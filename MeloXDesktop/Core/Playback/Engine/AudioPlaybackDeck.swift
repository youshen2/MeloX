@preconcurrency import AVFoundation
@preconcurrency import AudioStreaming

@MainActor
final class AudioPlaybackDeck: NSObject, @preconcurrency AudioPlayerDelegate {
    var onStateChanged: (() -> Void)?
    var onSeekCompleted: (() -> Void)?
    var onEnded: (() -> Void)?
    var onFailure: ((Error) -> Void)?

    private(set) var state: AudioPlaybackState = .idle
    private(set) var itemIdentifier: Int?
    private(set) var itemID: UUID?
    private(set) var error: Error?
    private(set) var channelCount: AVAudioChannelCount = 2
    private var player: AudioStreaming.AudioPlayer?
    private var loadContinuation: CheckedContinuation<Bool, Never>?
    private var source: PlaybackSource?
    private var finishedPosition: TimeInterval?
    private var currentEntryID: AudioEntryId?
    private var initialSeek: TimeInterval?
    private var isSeeking = false
    private var wantsPlayback = false
    private var playbackRate: Float = 1
    private var outputVolume: Float = 1
    private let equalizer: AudioEqualizerProcessor

    #if os(iOS)
    private let spectrum = SharedPlaybackAudioSpectrum()
    var spectrumSnapshot: PlaybackAudioSpectrumSnapshot { spectrum.snapshot() }
    #endif

    init(equalizerConfiguration: AudioEqualizerConfiguration) {
        equalizer = AudioEqualizerProcessor(configuration: equalizerConfiguration)
    }

    var hasCurrentItem: Bool { itemID != nil }
    var isReady: Bool { state == .playing || state == .paused }
    var currentPlaybackTime: TimeInterval? {
        guard let player, !isSeeking, initialSeek == nil else { return nil }
        return finishedPosition ?? max(player.progress, 0)
    }
    var playbackDuration: TimeInterval? {
        guard let duration = player?.duration, duration > 0 else { return nil }
        return duration
    }
    var rate: Float {
        get { state == .playing ? playbackRate : 0 }
        set {
            if newValue == 0 { pause() }
            else {
                playbackRate = newValue
                player?.rate = newValue
                play()
            }
        }
    }
    var volume: Float {
        get { outputVolume }
        set {
            outputVolume = newValue
            if isReady { player?.volume = newValue }
        }
    }

    func load(_ source: PlaybackSource, identifier: Int? = nil,
              startAt: TimeInterval = 0, autoplay: Bool = false) async -> Bool {
        clear()
        let id = UUID()
        itemID = id
        itemIdentifier = identifier
        self.source = source
        wantsPlayback = autoplay
        initialSeek = max(startAt, 0)
        isSeeking = true
        transition(to: .loading)
        let format = await AudioPlaybackFormat.load(from: source.url)
        guard itemID == id, !Task.isCancelled else { return false }
        let player = AudioStreaming.AudioPlayer(
            configuration: AudioPlayerConfiguration(
                bufferSizeInSeconds: max(source.preferredForwardBufferDuration, 8),
                secondsRequiredToStartPlaying: 0.3, gracePeriodAfterSeekInSeconds: 0.1),
            outputFormat: format)
        self.player = player
        channelCount = format?.channelCount ?? 2
        player.volume = 0
        player.delegate = self
        equalizer.attach(to: player)
        #if os(iOS)
        let analyzer = PlaybackAudioSpectrumAnalyzer(sharedSpectrum: spectrum)
        player.frameFiltering.add(entry: "melox.spectrum") { buffer, _ in
            analyzer.process(buffer: buffer)
        }
        #endif
        return await withCheckedContinuation { continuation in
            loadContinuation = continuation
            player.play(url: source.url)
        }
    }

    func play() {
        wantsPlayback = true
        if player?.state == .stopped { seek(to: 0) }
        player?.resume()
        if isReady { transition(to: .playing) }
    }

    func play(atRate rate: Float) { self.rate = rate }

    func pause() {
        wantsPlayback = false
        // A muted seek keeps decoding until it can settle at the requested sample.
        if !isSeeking {
            player?.pause()
            if hasCurrentItem { transition(to: .paused) }
        }
    }

    func seek(to seconds: TimeInterval) {
        guard let player else { initialSeek = max(seconds, 0); return }
        isSeeking = true
        finishedPosition = nil
        player.volume = 0
        transition(to: .loading)
        if player.state == .stopped, let source {
            initialSeek = max(seconds, 0)
            currentEntryID = nil
            player.play(url: source.url)
            return
        }
        player.seek(to: max(seconds, 0))
        player.resume()
    }

    func setEqualizerConfiguration(_ configuration: AudioEqualizerConfiguration) {
        equalizer.update(configuration: configuration)
    }
    func setAutoMixEqualizer(lowGain: Float, midGain: Float, highGain: Float) {
        equalizer.setAutoMixGains(low: lowGain, mid: midGain, high: highGain)
    }
    func resetAutoMixEqualizer() { setAutoMixEqualizer(lowGain: 0, midGain: 0, highGain: 0) }
    func setSpatializationEnabled(_ isEnabled: Bool) {
        player?.renderingAlgorithm = isEnabled ? .auto : .equalPowerPanning
    }

    func clear() {
        itemID = nil
        itemIdentifier = nil
        source = nil
        finishedPosition = nil
        currentEntryID = nil
        player?.delegate = nil
        player?.stop()
        player = nil
        initialSeek = nil
        isSeeking = false
        wantsPlayback = false
        playbackRate = 1
        error = nil
        resetAutoMixEqualizer()
        loadContinuation?.resume(returning: false)
        loadContinuation = nil
        transition(to: .idle)
    }

    private func transition(to newState: AudioPlaybackState) {
        guard state != newState else { return }
        state = newState
        onStateChanged?()
    }

    func audioPlayerDidStartPlaying(player: AudioStreaming.AudioPlayer, with entryId: AudioEntryId) {
        guard player === self.player else { return }
        currentEntryID = entryId
        guard let target = initialSeek else { return }
        initialSeek = nil
        player.seek(to: target)
    }

    func audioPlayerStateChanged(player: AudioStreaming.AudioPlayer,
                                 with newState: AudioPlayerState, previous: AudioPlayerState) {
        guard player === self.player else { return }
        switch newState {
        case .playing:
            guard initialSeek == nil, !player.isSeeking, player.state == .playing else { return }
            let completedSeek = isSeeking
            isSeeking = false
            if !wantsPlayback { player.pause() }
            player.volume = outputVolume
            transition(to: wantsPlayback ? .playing : .paused)
            loadContinuation?.resume(returning: true)
            loadContinuation = nil
            if completedSeek { onSeekCompleted?() }
        case .bufferring, .running:
            transition(to: .loading)
        case .paused:
            if !isSeeking { transition(to: .paused) }
        case .ready, .stopped, .error, .disposed:
            break
        }
    }

    func audioPlayerDidFinishPlaying(player: AudioStreaming.AudioPlayer, entryId: AudioEntryId,
                                     stopReason: AudioPlayerStopReason, progress: Double, duration: Double) {
        guard player === self.player, currentEntryID == entryId, stopReason == .eof else { return }
        finishedPosition = progress
        isSeeking = false
        wantsPlayback = false
        loadContinuation?.resume(returning: false)
        loadContinuation = nil
        transition(to: .paused)
        onEnded?()
    }
    func audioPlayerUnexpectedError(player: AudioStreaming.AudioPlayer, error: AudioPlayerError) {
        guard player === self.player else { return }
        self.error = error
        isSeeking = false
        wantsPlayback = false
        transition(to: .paused)
        loadContinuation?.resume(returning: false)
        loadContinuation = nil
        onFailure?(error)
    }
    func audioPlayerDidFinishBuffering(player: AudioStreaming.AudioPlayer, with entryId: AudioEntryId) {}
    func audioPlayerDidCancel(player: AudioStreaming.AudioPlayer, queuedItems: [AudioEntryId]) {}
    func audioPlayerDidReadMetadata(player: AudioStreaming.AudioPlayer, metadata: [String: String]) {}
}
