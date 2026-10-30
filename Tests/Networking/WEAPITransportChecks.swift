// Standalone macOS checks using the production client and an isolated URLProtocol.
// Run from the repository root:
// xcrun swiftc -parse-as-library MeloX/Core/Networking/NeteaseDirectClient.swift \
//   Tests/Networking/WEAPITransportChecks.swift -o /tmp/melox-weapi-checks && /tmp/melox-weapi-checks
// Stubs below supply unrelated app types; no network or account credentials are used.
import Foundation
import Synchronization

@MainActor final class AppSettings { var cookie = "MUSIC_U=fixture; __csrf=fixture" }
enum APIError: Error { case requestEncoding, invalidResponse, emptyResponse(statusCode: Int), server(statusCode: Int, message: String) }
enum CloudUploadError: Error { case noUploadServer }
struct NOSLBSResponse: Decodable { let upload: [String] }
enum L10n { static func format(_ key: String, _ args: CVarArg...) -> String { key } }
final class Stub: URLProtocol, @unchecked Sendable {
    static let state = Mutex((calls: 0, body: ""))
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let body = Self.state.withLock { $0.calls += 1; return $0.body }
        precondition(request.httpMethod == "POST")
        precondition(request.url?.path == "/weapi/playlist/subscribe")
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct Check {
    struct Status: Decodable { let code: Int }
    @MainActor static func main() async throws {
        let fields = ["params": "a+b/c==", "space key": "a b&c=d%中文", "empty": ""]
        let encoded = String(decoding: NeteaseDirectClient.formEncodedData(fields), as: UTF8.self)
        precondition(encoded.contains("a%2Bb%2Fc%3D%3D"))
        precondition(!encoded.contains("+"))
        var decoded: [String: String] = [:]
        for pair in encoded.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(parts[0]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding!
            let value = String(parts[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding!
            decoded[key] = value
        }
        precondition(decoded == fields)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Stub.self]
        let client = NeteaseDirectClient(settings: AppSettings(), session: URLSession(configuration: config))
        for retries in [false, true] {
            Stub.state.withLock { $0 = (0, "") }
            do {
                let _: Status = try await client.weapi("/api/playlist/subscribe", data: ["id": 7], retryEmptyResponse: retries)
                fatalError("Empty response accepted")
            } catch APIError.emptyResponse { }
            precondition(Stub.state.withLock { $0.calls } == (retries ? 3 : 1))
        }
        for code in [200, 405] {
            Stub.state.withLock { $0 = (0, "{\"code\":\(code)}") }
            let value: Status = try await client.weapi("/api/playlist/subscribe", data: ["id": 7], retryEmptyResponse: false)
            precondition(value.code == code)
            precondition(Stub.state.withLock { $0.calls } == 1)
        }
        print("PASS: form encoding round-trip + 4 production WEAPI transport checks")
    }
}
