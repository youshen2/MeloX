import Observation

@MainActor
final class DesktopLyricsSynchronizer {
    private let player: PlayerStore
    private let settings: AppSettings
    private let lyrics: LyricsStore
    private var currentRequest: Request?
    private var synchronizationTask: Task<Void, Never>?

    init(player: PlayerStore, settings: AppSettings, lyrics: LyricsStore) {
        self.player = player
        self.settings = settings
        self.lyrics = lyrics
        observeChanges()
    }

    deinit {
        synchronizationTask?.cancel()
    }

    private func observeChanges() {
        let request = withObservationTracking {
            Request(
                songID: player.currentSong?.id,
                sourcePreference: settings.lyricsSourcePreference
            )
        } onChange: { [weak self] in
            // Re-arm after the observed property has finished changing.
            Task { @MainActor [weak self] in
                self?.observeChanges()
            }
        }

        guard request != currentRequest else { return }
        currentRequest = request
        synchronizationTask?.cancel()

        let song = player.currentSong
        let lyricSong = song?.isPodcastProgram == true ? nil : song
        let lyrics = lyrics
        let player = player
        synchronizationTask = Task {
            guard !Task.isCancelled else { return }
            await lyrics.load(for: lyricSong)
            guard !Task.isCancelled else { return }
            player.setNowPlayingLyrics(lyrics.lyrics, for: lyricSong?.id)
        }
    }

    private struct Request: Equatable {
        let songID: Int?
        let sourcePreference: LyricSourcePreference
    }
}
