import Foundation

final class DownloadStorage {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        self.directoryURL = directoryURL
            ?? applicationSupportURL
                .appending(path: "MeloX", directoryHint: .isDirectory)
                .appending(path: "Downloads", directoryHint: .isDirectory)
    }

    func installDownloadedFile(
        from temporaryURL: URL,
        songID: Int,
        format: String?,
        sourceURL: URL
    ) throws -> (fileName: String, byteCount: Int64) {
        try prepareDirectory()
        let fileName = "\(songID).\(fileExtension(format: format, sourceURL: sourceURL))"
        let destinationURL = fileURL(fileName: fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)

        let values = try destinationURL.resourceValues(forKeys: [.fileSizeKey])
        let byteCount = Int64(values.fileSize ?? 0)
        guard byteCount > 0 else {
            try? fileManager.removeItem(at: destinationURL)
            throw DownloadError.emptyFile
        }
        return (fileName, byteCount)
    }

    func removeFile(named fileName: String) throws {
        let url = fileURL(fileName: fileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func removeAllFiles() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
    }

    func containsFile(named fileName: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(fileName: fileName).path)
    }

    func fileURL(fileName: String) -> URL {
        directoryURL.appending(path: fileName, directoryHint: .notDirectory)
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDirectoryURL = directoryURL
        try? mutableDirectoryURL.setResourceValues(resourceValues)
    }

    private func fileExtension(format: String?, sourceURL: URL) -> String {
        let proposed = format?.lowercased() ?? sourceURL.pathExtension.lowercased()
        let allowed = CharacterSet.alphanumerics
        let normalized = proposed.unicodeScalars.filter(allowed.contains).map(String.init).joined()
        return normalized.isEmpty ? "audio" : String(normalized.prefix(10))
    }
}

enum DownloadError: LocalizedError {
    case invalidResponse
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "歌曲下载服务返回了无效响应。"
        case .emptyFile:
            "下载完成的歌曲文件为空。"
        }
    }
}
