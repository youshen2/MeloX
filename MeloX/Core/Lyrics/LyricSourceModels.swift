import Foundation

enum LyricSource: String, Hashable, Sendable {
    case amll
    case netease
    case qqMusic

    var title: String {
        switch self {
        case .amll: L10n.string("ui.lyrics.source.amll")
        case .netease: L10n.string("ui.lyrics.source.netease")
        case .qqMusic: L10n.string("ui.lyrics.source.qq_music")
        }
    }
}

enum LyricSourcePreference: String, CaseIterable, Identifiable, Hashable, Sendable {
    case automatic
    case amll
    case netease
    case qqMusic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: L10n.string("ui.lyrics.source.automatic")
        case .amll: L10n.string("ui.lyrics.source.amll_ttml")
        case .netease: L10n.string("ui.lyrics.source.netease")
        case .qqMusic: L10n.string("ui.lyrics.source.qq_music")
        }
    }

    var source: LyricSource? {
        switch self {
        case .automatic: nil
        case .amll: .amll
        case .netease: .netease
        case .qqMusic: .qqMusic
        }
    }
}

struct ResolvedLyrics: Hashable, Sendable {
    let source: LyricSource
    let quality: LyricQuality
    let lines: [LyricLine]
    let isPureMusic: Bool

    init(
        source: LyricSource,
        quality: LyricQuality,
        lines: [LyricLine],
        isPureMusic: Bool
    ) {
        self.source = source
        self.quality = quality
        // Every lyrics view keys its rows by line id, so two identical
        // lines at the same timestamp must never share one.
        self.lines = lines.withUniqueIDs()
        self.isPureMusic = isPureMusic
    }
}

enum LyricQuality: Int, Hashable, Sendable {
    case fallback
    case qqMusicLineSynchronized
    case neteaseLineSynchronized
    case qqMusicVerbatim
    case neteaseVerbatim
    case amllTTML
}

struct LyricsSongMetadata: Hashable, Sendable {
    let id: Int
    let title: String
    let album: String
    let artist: String
    let durationSeconds: Int

    init(song: Song) {
        id = song.id
        title = song.name
        album = song.album?.name ?? ""
        artist = song.artists.map(\.name).joined(separator: ",")
        durationSeconds = max(song.durationMS / 1_000, 0)
    }
}

struct NeteaseLyricPayload: Sendable {
    let yrc: String?
    let lrc: String?
    let translatedYRC: String?
    let translatedLRC: String?
    let romanizedYRC: String?
    let romanizedLRC: String?
    let isPureMusic: Bool
}

struct QQLyricPayload: Sendable {
    let verbatim: String?
    let lineSynchronized: String?
    let translation: String?
    let romanization: String?
}

enum LyricSourceError: LocalizedError {
    case invalidResponse
    case noLyrics

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            L10n.string("ui.error.lyrics.invalid_response")
        case .noLyrics:
            L10n.string("ui.error.lyrics.unavailable")
        }
    }
}
