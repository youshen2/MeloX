import AppKit
import AVFoundation
import MediaPlayer

@MainActor
final class NowPlayingSession {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onSeek: ((TimeInterval) -> Void)?

    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var nowPlayingInfo: [String: Any] = [:]
    private var artworkTask: Task<Void, Never>?
    private var representedSongID: Int?

    private var nowPlayingCenter: MPNowPlayingInfoCenter {
        .default()
    }

    private var commandCenter: MPRemoteCommandCenter {
        .shared()
    }

    init(players: [AVPlayer]) {
        installRemoteCommands()
    }

    deinit {
        artworkTask?.cancel()
        for (command, target) in commandTargets {
            command.removeTarget(target)
        }
    }

    func setSong(
        _ song: Song,
        duration: TimeInterval,
        queueIndex: Int,
        queueCount: Int,
        lyricsDisplaySettings: NowPlayingLyricsDisplaySettings
    ) {
        representedSongID = song.id
        setPlaybackCommandsEnabled(true)
        artworkTask?.cancel()
        let metadata = NowPlayingLyricsFormatter.metadata(
            songTitle: song.name,
            songArtist: song.artistText,
            currentLyric: nil,
            settings: lyricsDisplaySettings
        )
        nowPlayingInfo = [
            MPMediaItemPropertyTitle: metadata.title,
            MPMediaItemPropertyArtist: metadata.subtitle,
            MPMediaItemPropertyAlbumTitle:
                song.podcastMetadata?.radioName
                ?? song.album?.name
                ?? "",
            MPMediaItemPropertyPersistentID: NSNumber(value: UInt64(max(song.id, 0))),
            MPMediaItemPropertyPlaybackDuration: max(duration, 0),
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyExternalContentIdentifier:
                song.podcastMetadata.map {
                    "netease:djprogram:\($0.programID)"
                } ?? "netease:song:\(song.id)",
            MPNowPlayingInfoPropertyServiceIdentifier: "netease-cloud-music",
            MPNowPlayingInfoPropertyPlaybackQueueIndex: max(queueIndex, 0),
            MPNowPlayingInfoPropertyPlaybackQueueCount: max(queueCount, 1),
        ]
        if let podcast = song.podcastMetadata {
            nowPlayingInfo[MPMediaItemPropertyPodcastTitle] =
                podcast.radioName
            nowPlayingInfo[MPNowPlayingInfoCollectionIdentifier] =
                "netease:djradio:\(podcast.radioID)"
        } else if let albumID = song.album?.id {
            nowPlayingInfo[MPNowPlayingInfoCollectionIdentifier] = "netease:album:\(albumID)"
        }
        nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
        loadArtwork(from: song.album?.artworkURL, songID: song.id)
    }

    func updateCurrentLyric(
        _ lyric: String?,
        for song: Song,
        lyricsDisplaySettings: NowPlayingLyricsDisplaySettings
    ) {
        guard representedSongID == song.id else { return }

        let metadata = NowPlayingLyricsFormatter.metadata(
            songTitle: song.name,
            songArtist: song.artistText,
            currentLyric: lyric,
            settings: lyricsDisplaySettings
        )
        guard nowPlayingInfo[MPMediaItemPropertyTitle] as? String
                != metadata.title
                || nowPlayingInfo[MPMediaItemPropertyArtist] as? String
                    != metadata.subtitle else {
            return
        }

        nowPlayingInfo[MPMediaItemPropertyTitle] = metadata.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = metadata.subtitle
        nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
    }

    func updatePlayback(
        position: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool
    ) {
        guard representedSongID != nil else { return }
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = max(duration, 0)
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(position, 0)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
        nowPlayingCenter.playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        representedSongID = nil
        artworkTask?.cancel()
        artworkTask = nil
        nowPlayingInfo = [:]
        nowPlayingCenter.nowPlayingInfo = nil
        nowPlayingCenter.playbackState = .stopped
        setPlaybackCommandsEnabled(false)
    }

    private func installRemoteCommands() {
        setPlaybackCommandsEnabled(false)
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
        commandCenter.changePlaybackRateCommand.isEnabled = false
        commandCenter.changeRepeatModeCommand.isEnabled = false
        commandCenter.changeShuffleModeCommand.isEnabled = false

        addTarget(to: commandCenter.playCommand) { [weak self] _ in
            Task { @MainActor in self?.onPlay?() }
            return .success
        }
        addTarget(to: commandCenter.pauseCommand) { [weak self] _ in
            Task { @MainActor in self?.onPause?() }
            return .success
        }
        addTarget(to: commandCenter.togglePlayPauseCommand) { [weak self] _ in
            Task { @MainActor in self?.onTogglePlayPause?() }
            return .success
        }
        addTarget(to: commandCenter.nextTrackCommand) { [weak self] _ in
            Task { @MainActor in self?.onNext?() }
            return .success
        }
        addTarget(to: commandCenter.previousTrackCommand) { [weak self] _ in
            Task { @MainActor in self?.onPrevious?() }
            return .success
        }
        addTarget(to: commandCenter.changePlaybackPositionCommand) { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor in self?.onSeek?(position) }
            return .success
        }
    }

    private func setPlaybackCommandsEnabled(_ isEnabled: Bool) {
        // Availability describes supported actions. The current transport
        // state is published separately through MPNowPlayingInfoCenter.
        commandCenter.playCommand.isEnabled = isEnabled
        commandCenter.pauseCommand.isEnabled = isEnabled
        commandCenter.togglePlayPauseCommand.isEnabled = isEnabled
    }

    private func addTarget(
        to command: MPRemoteCommand,
        handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
    ) {
        let target = command.addTarget(handler: handler)
        commandTargets.append((command, target))
    }

    private func loadArtwork(from url: URL?, songID: Int) {
        guard let url else { return }
        artworkTask = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try Task.checkCancellation()
                guard let image = NSImage(data: data),
                      let self,
                      self.representedSongID == songID else { return }
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                self.nowPlayingCenter.nowPlayingInfo = self.nowPlayingInfo
            } catch {
                // Artwork is optional; metadata and controls remain usable without it.
            }
        }
    }
}
