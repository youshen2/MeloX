import AVFoundation
import CryptoKit
import Foundation

struct CloudUploadFile: Sendable {
    let url: URL
    let filename: String
    let fileExtension: String
    let normalizedStem: String
    let size: Int64
    let md5: String
    let songName: String
    let artist: String
    let album: String

    static func prepare(from url: URL) async throws -> CloudUploadFile {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let fileSize = values.fileSize, fileSize > 0 else {
            throw CloudUploadError.invalidFile
        }

        let metadata = await audioMetadata(for: url)
        let filename = url.lastPathComponent
        let fallbackName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension.isEmpty ? "mp3" : url.pathExtension.lowercased()
        let normalizedStem = fallbackName
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .replacingOccurrences(of: ".", with: "_")

        let md5 = try await Task.detached(priority: .userInitiated) {
            try CloudFileHasher.md5Hex(of: url)
        }.value

        return CloudUploadFile(
            url: url,
            filename: filename,
            fileExtension: fileExtension,
            normalizedStem: normalizedStem.isEmpty ? "music" : normalizedStem,
            size: Int64(fileSize),
            md5: md5,
            songName: metadata.title ?? fallbackName,
            artist: metadata.artist ?? "未知艺术家",
            album: metadata.album ?? "未知专辑"
        )
    }

    private static func audioMetadata(for url: URL) async -> AudioMetadata {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else {
            return AudioMetadata()
        }

        var metadata = AudioMetadata()
        for item in items {
            guard let value = try? await item.load(.stringValue), !value.isEmpty else { continue }
            switch item.commonKey {
            case .commonKeyTitle:
                metadata.title = value
            case .commonKeyArtist:
                metadata.artist = value
            case .commonKeyAlbumName:
                metadata.album = value
            default:
                continue
            }
        }
        return metadata
    }
}

enum CloudUploadError: LocalizedError {
    case invalidFile
    case noUploadServer

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            "所选文件不是可上传的音频文件。"
        case .noUploadServer:
            "网易云音乐暂时没有返回可用的上传服务器。"
        }
    }
}

private struct AudioMetadata {
    var title: String?
    var artist: String?
    var album: String?
}

private enum CloudFileHasher {
    nonisolated static func md5Hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = Insecure.MD5()
        while true {
            guard let data = try handle.read(upToCount: 1_048_576), !data.isEmpty else { break }
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
