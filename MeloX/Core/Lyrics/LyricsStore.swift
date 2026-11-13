import Foundation
import Observation

@MainActor
@Observable
final class LyricsStore {
    private(set) var songID: Int?
    private(set) var lyrics: [LyricLine] = []
    private(set) var source: LyricSource?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private let service: LyricsService

    @ObservationIgnored
    private var loadGeneration = 0

    init(service: LyricsService) {
        self.service = service
    }

    func load(for song: Song?) async {
        loadGeneration += 1
        let generation = loadGeneration

        songID = song?.id
        lyrics = []
        source = nil
        errorMessage = nil
        isLoading = song != nil

        guard let song else { return }

        #if DEBUG && targetEnvironment(simulator)
        if MeloXDesignPreview.isEnabled {
            lyrics = MeloXDesignPreview.lyricLines
            isLoading = false
            return
        }
        #endif

        do {
            let loaded = try await service.load(
                for: LyricsSongMetadata(song: song)
            ) { [weak self] update in
                guard let self, generation == self.loadGeneration else {
                    return
                }
                self.lyrics = update.lines
                self.source = update.source
                self.errorMessage = nil
                self.isLoading = false
            }
            try Task.checkCancellation()
            guard generation == loadGeneration else { return }

            lyrics = loaded.lines
            source = loaded.source
            errorMessage = loaded.lines.isEmpty
                ? L10n.string("ui.error.lyrics.unavailable")
                : nil
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func fetch(for song: Song) async throws -> [LyricLine] {
        let resolved = try await service.load(
            for: LyricsSongMetadata(song: song),
            onUpdate: { _ in }
        )
        return resolved.lines
    }
}
