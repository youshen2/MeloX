import Foundation

struct DownloadTransferProgress: Sendable {
    let receivedByteCount: Int64
    let expectedByteCount: Int64?

    var fractionCompleted: Double? {
        guard let expectedByteCount, expectedByteCount > 0 else { return nil }
        return min(max(Double(receivedByteCount) / Double(expectedByteCount), 0), 1)
    }
}

struct DownloadTransferResult: Sendable {
    let temporaryURL: URL
    let response: URLResponse
}

@MainActor
final class DownloadTransferClient: NSObject, @preconcurrency URLSessionDownloadDelegate {
    typealias ProgressHandler = @MainActor (DownloadTransferProgress) -> Void

    private struct Transfer {
        let continuation: CheckedContinuation<DownloadTransferResult, Error>
        let progressHandler: ProgressHandler
        var stagedURL: URL?
    }

    private var transfers: [Int: Transfer] = [:]
    private lazy var session = URLSession(
        configuration: configuration,
        delegate: self,
        delegateQueue: .main
    )
    private let configuration: URLSessionConfiguration

    init(configuration: URLSessionConfiguration = .default) {
        self.configuration = configuration
        super.init()
    }

    func download(
        from url: URL,
        onProgress: @escaping ProgressHandler
    ) async throws -> DownloadTransferResult {
        let task = session.downloadTask(with: url)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                transfers[task.taskIdentifier] = Transfer(
                    continuation: continuation,
                    progressHandler: onProgress,
                    stagedURL: nil
                )
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let transfer = transfers[downloadTask.taskIdentifier] else { return }
        transfer.progressHandler(
            DownloadTransferProgress(
                receivedByteCount: totalBytesWritten,
                expectedByteCount: totalBytesExpectedToWrite > 0
                    ? totalBytesExpectedToWrite
                    : nil
            )
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard var transfer = transfers[downloadTask.taskIdentifier] else { return }
        let stagedURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .notDirectory)
        do {
            try FileManager.default.moveItem(at: location, to: stagedURL)
            transfer.stagedURL = stagedURL
            transfers[downloadTask.taskIdentifier] = transfer
        } catch {
            transfers.removeValue(forKey: downloadTask.taskIdentifier)?
                .continuation.resume(throwing: error)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let transfer = transfers.removeValue(forKey: task.taskIdentifier) else { return }
        if let error {
            if let stagedURL = transfer.stagedURL {
                try? FileManager.default.removeItem(at: stagedURL)
            }
            transfer.continuation.resume(throwing: error)
            return
        }
        guard let stagedURL = transfer.stagedURL,
              let response = task.response else {
            transfer.continuation.resume(throwing: DownloadError.invalidResponse)
            return
        }
        transfer.continuation.resume(
            returning: DownloadTransferResult(
                temporaryURL: stagedURL,
                response: response
            )
        )
    }
}
