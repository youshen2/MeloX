import Foundation
import XCTest
@testable import AudioStreaming

final class NetworkSessionDelegateTests: XCTestCase {
    func testLateCallbacksAfterTaskProviderIsReleased() {
        let delegate = NetworkSessionDelegate()
        var provider: EmptyTaskProvider? = EmptyTaskProvider()
        delegate.taskProvider = provider
        provider = nil
        XCTAssertNil(delegate.taskProvider)
        checkUntrackedCallbacks(delegate)
    }

    func testCallbacksForRemovedTask() {
        let delegate = NetworkSessionDelegate()
        let provider = EmptyTaskProvider()
        delegate.taskProvider = provider
        checkUntrackedCallbacks(delegate)
        withExtendedLifetime(provider) {}
    }

    private func checkUntrackedCallbacks(_ delegate: NetworkSessionDelegate) {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        // The task stays suspended: no real network access is needed.
        let task = session.dataTask(with: URL(string: "https://example.invalid/audio")!)
        let response = URLResponse(url: task.originalRequest!.url!, mimeType: nil,
                                   expectedContentLength: 0, textEncodingName: nil)
        var dispositions: [URLSession.ResponseDisposition] = []
        delegate.urlSession(session, dataTask: task, didReceive: response) {
            dispositions.append($0)
        }
        XCTAssertEqual(dispositions, [.cancel])
        delegate.urlSession(session, dataTask: task, didReceive: Data([0]))
        delegate.urlSession(session, task: task, didCompleteWithError: URLError(.cancelled))
    }
}

private final class EmptyTaskProvider: StreamTaskProvider {
    func dataStream(for request: URLSessionTask) -> NetworkDataStream? { nil }
}
