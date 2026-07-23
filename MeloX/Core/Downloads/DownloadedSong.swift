import Foundation

struct DownloadedSong: Codable, Hashable, Identifiable {
    let song: Song
    let fileName: String
    let byteCount: Int64
    let bitrate: Int?
    let format: String?
    let quality: MusicQuality
    let downloadedAt: Date

    var id: Int { song.id }
}

struct ActiveSongDownload: Identifiable, Hashable {
    let song: Song
    let quality: MusicQuality
    var receivedByteCount: Int64
    var expectedByteCount: Int64?

    var id: Int { song.id }

    var fractionCompleted: Double? {
        guard let expectedByteCount, expectedByteCount > 0 else { return nil }
        return min(max(Double(receivedByteCount) / Double(expectedByteCount), 0), 1)
    }
}
