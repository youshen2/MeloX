import CommonCrypto
import CryptoKit
import Foundation
import Security

@MainActor
final class NeteaseDirectClient {
    private let settings: AppSettings
    private let session: URLSession
    private let syntheticDeviceID: String
    private let syntheticWNMCID: String

    init(settings: AppSettings, session: URLSession) {
        self.settings = settings
        self.session = session
        syntheticDeviceID = Self.randomString(length: 52, characters: "0123456789ABCDEF")
        syntheticWNMCID = "\(Self.randomString(length: 6, characters: "abcdefghijklmnopqrstuvwxyz")).\(Self.timestampMilliseconds).01.0"
    }

    func eapi<Response: Decodable>(
        _ uri: String,
        data: [String: Any] = [:],
        requiresCheckToken: Bool = false,
        authenticated: Bool = false,
        domain: String = "https://interface.music.163.com",
        cookieOS: String? = nil
    ) async throws -> Response {
        var requestData = data
        let header = eapiHeader(
            requiresCheckToken: requiresCheckToken,
            authenticated: authenticated,
            cookieOS: cookieOS
        )
        requestData["header"] = header
        requestData["e_r"] = false
        let json = try jsonString(requestData)
        let message = "nobody\(uri)use\(json)md5forencrypt"
        let digest = Insecure.MD5.hash(data: Data(message.utf8)).map { String(format: "%02x", $0) }.joined()
        let payload = "\(uri)-36cd479b6b5-\(json)-36cd479b6b5-\(digest)"
        let params = try aesECB(Data(payload.utf8), key: "e82ckenh8dichen8")
            .map { String(format: "%02X", $0) }
            .joined()
        let path = uri.replacingOccurrences(of: "/api/", with: "/eapi/")
        guard let url = URL(string: "\(domain)\(path)") else {
            throw APIError.requestEncoding
        }
        return try await send(
            url: url,
            form: ["params": params],
            userAgent: authenticated
                ? "NeteaseMusic 9.0.90/5038 (iPhone; iOS 16.2; zh_CN)"
                : "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
            cookieHeaderOverride: authenticated ? encodedCookieHeader(header) : nil
        )
    }

    func weapi<Response: Decodable>(
        _ uri: String,
        data: [String: Any] = [:]
    ) async throws -> Response {
        let path = uri.replacingOccurrences(of: "/api/", with: "/weapi/")
        guard let url = URL(string: "https://music.163.com\(path)") else {
            throw APIError.requestEncoding
        }

        for attempt in 0..<3 {
            var requestData = data
            requestData["csrf_token"] = csrfToken
            let json = try jsonString(requestData)
            let secretKey = makeWeapiSecretKey()
            let firstPass = try aesCBC(Data(json.utf8), key: "0CoJUm6Qyw8W8jud")
                .base64EncodedString()
            let params = try aesCBC(Data(firstPass.utf8), key: secretKey)
                .base64EncodedString()
            let encSecKey = try rsaEncryptWeapiSecret(secretKey)

            do {
                return try await send(
                    url: url,
                    form: ["params": params, "encSecKey": encSecKey],
                    userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0",
                    referer: "https://music.163.com",
                    cookieHeaderOverride: processedWeapiCookieHeader(for: uri)
                )
            } catch APIError.emptyResponse(let statusCode) {
                guard attempt < 2 else {
                    throw APIError.emptyResponse(statusCode: statusCode)
                }
                try await Task.sleep(for: .milliseconds(180 * (attempt + 1)))
            }
        }

        throw APIError.invalidResponse
    }

    func uploadToNOS(
        fileURL: URL,
        bucket: String,
        objectKey: String,
        token: String,
        md5: String,
        fileSize: Int64
    ) async throws {
        var lbsComponents = URLComponents(string: "https://wanproxy.127.net/lbs")
        lbsComponents?.queryItems = [
            URLQueryItem(name: "version", value: "1.0"),
            URLQueryItem(name: "bucketname", value: bucket),
        ]
        guard let lbsURL = lbsComponents?.url else {
            throw APIError.requestEncoding
        }

        let (lbsData, lbsResponse) = try await session.data(from: lbsURL)
        guard let lbsHTTPResponse = lbsResponse as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(lbsHTTPResponse.statusCode) else {
            throw APIError.server(
                statusCode: lbsHTTPResponse.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: lbsHTTPResponse.statusCode)
            )
        }
        let lbs = try JSONDecoder().decode(NOSLBSResponse.self, from: lbsData)
        guard let uploadHost = lbs.upload.first else {
            throw CloudUploadError.noUploadServer
        }

        var objectKeyAllowed = CharacterSet.urlPathAllowed
        objectKeyAllowed.remove(charactersIn: "/?#")
        guard let encodedObjectKey = objectKey.addingPercentEncoding(withAllowedCharacters: objectKeyAllowed),
              let uploadURL = URL(
                string: "\(uploadHost.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/\(bucket)/\(encodedObjectKey)?offset=0&complete=true&version=1.0"
              ) else {
            throw APIError.requestEncoding
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 200
        request.setValue(token, forHTTPHeaderField: "x-nos-token")
        request.setValue(md5, forHTTPHeaderField: "Content-MD5")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(String(fileSize), forHTTPHeaderField: "Content-Length")

        let (data, response) = try await session.upload(for: request, fromFile: fileURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.server(
                statusCode: httpResponse.statusCode,
                message: data.isEmpty
                    ? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    : responseDescription(data, decodingError: APIError.invalidResponse)
            )
        }
    }

    private func send<Response: Decodable>(
        url: URL,
        form: [String: String],
        userAgent: String = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
        referer: String? = nil,
        cookieOS: String = "ios",
        appVersion: String = "9.0.90",
        cookieHeaderOverride: String? = nil
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue(
            cookieHeaderOverride ?? cookieHeader(os: cookieOS, appVersion: appVersion),
            forHTTPHeaderField: "Cookie"
        )
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.server(
                statusCode: httpResponse.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
        guard !data.isEmpty else {
            throw APIError.emptyResponse(statusCode: httpResponse.statusCode)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            let payload = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            let code = payload?["code"] as? Int ?? httpResponse.statusCode
            let message = payload?["message"] as? String
                ?? payload?["msg"] as? String
                ?? responseDescription(data, decodingError: error)
            throw APIError.server(statusCode: code, message: message)
        }
    }

    private func responseDescription(_ data: Data, decodingError: Error) -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            let hex = data.prefix(32).map { String(format: "%02X", $0) }.joined()
            return "数据解析失败（\(data.count) 字节，\(hex)）：\(decodingError.localizedDescription)"
        }
        let compact = text.replacingOccurrences(of: "\n", with: " ")
        return "数据解析失败（\(data.count) 字节）：\(String(compact.prefix(180)))；\(decodingError.localizedDescription)"
    }

    private var csrfToken: String {
        cookieValues["__csrf"] ?? ""
    }

    private func cookieHeader(os: String, appVersion: String) -> String {
        var values = cookieValues
        values["os"] = values["os"] ?? os
        values["appver"] = values["appver"] ?? appVersion
        values["__remember_me"] = "true"
        return values.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    /// Mirrors `processCookieObject` and `cookieObjToString` from
    /// `@neteaseapireborn/api/util/request.js`. The web endpoints return an
    /// HTTP 200 with an empty body when some of these browser/device cookies
    /// are missing, so forwarding only MUSIC_U is not sufficient.
    private func processedWeapiCookieHeader(for uri: String) -> String {
        var values = cookieValues
        let profile = Self.weapiCookieProfile(for: values["os"])
        let generatedNuid = Self.randomHex(byteCount: 32)

        values["__remember_me"] = "true"
        values["ntes_kaola_ad"] = "1"
        setDefault("_ntes_nuid", value: generatedNuid, in: &values)
        setDefault("_ntes_nnid", value: "\(generatedNuid),\(Self.timestampMilliseconds)", in: &values)
        setDefault("WNMCID", value: syntheticWNMCID, in: &values)
        setDefault("WEVNSM", value: "1.0.0", in: &values)
        setDefault("osver", value: profile.osVersion, in: &values)
        setDefault("deviceId", value: syntheticDeviceID, in: &values)
        setDefault("os", value: profile.os, in: &values)
        setDefault("channel", value: profile.channel, in: &values)
        setDefault("appver", value: profile.appVersion, in: &values)

        if !uri.contains("login") {
            values["NMTID"] = Self.randomHex(byteCount: 16)
        }

        return values.keys.sorted().map { key in
            "\(Self.encodeURIComponent(key))=\(Self.encodeURIComponent(values[key] ?? ""))"
        }.joined(separator: "; ")
    }

    private func setDefault(
        _ key: String,
        value: String,
        in values: inout [String: String]
    ) {
        if nonEmpty(values[key]) == nil {
            values[key] = value
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private var cookieValues: [String: String] {
        let raw = settings.cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [:] }
        if !raw.contains("=") {
            return ["MUSIC_U": raw]
        }
        return raw.split(separator: ";").reduce(into: [:]) { result, pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                result[parts[0].trimmingCharacters(in: .whitespaces)] =
                    parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
    }

    private static func weapiCookieProfile(for os: String?) -> WeapiCookieProfile {
        switch os {
        case "linux":
            WeapiCookieProfile(
                os: "linux",
                appVersion: "1.2.1.0428",
                osVersion: "Deepin 20.9",
                channel: "netease"
            )
        case "android":
            WeapiCookieProfile(
                os: "android",
                appVersion: "8.20.20.231215173437",
                osVersion: "14",
                channel: "xiaomi"
            )
        case "iphone":
            WeapiCookieProfile(
                os: "iPhone OS",
                appVersion: "9.0.90",
                osVersion: "16.2",
                channel: "distribution"
            )
        default:
            WeapiCookieProfile(
                os: "pc",
                appVersion: "3.1.17.204416",
                osVersion: "Microsoft-Windows-10-Professional-build-19045-64bit",
                channel: "netease"
            )
        }
    }

    private static func randomString(length: Int, characters: String) -> String {
        let characters = Array(characters)
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).compactMap { _ in
            characters.randomElement(using: &generator)
        })
    }

    private static func randomHex(byteCount: Int) -> String {
        randomString(length: byteCount * 2, characters: "0123456789abcdef")
    }

    private static func randomDigits(length: Int) -> String {
        randomString(length: length, characters: "0123456789")
    }

    private static func encodeURIComponent(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.!~*'()")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static var timestampMilliseconds: Int64 {
        Int64(Date().timeIntervalSince1970 * 1_000)
    }

    private func eapiHeader(
        requiresCheckToken: Bool,
        authenticated: Bool,
        cookieOS: String?
    ) -> [String: String] {
        var header: [String: String]
        if authenticated {
            let values = cookieValues
            let profile = Self.weapiCookieProfile(for: cookieOS ?? values["os"])
            header = [
                "osver": nonEmpty(values["osver"]) ?? profile.osVersion,
                "deviceId": nonEmpty(values["deviceId"]) ?? syntheticDeviceID,
                "os": cookieOS ?? nonEmpty(values["os"]) ?? profile.os,
                "appver": nonEmpty(values["appver"]) ?? profile.appVersion,
                "versioncode": nonEmpty(values["versioncode"]) ?? "140",
                "mobilename": nonEmpty(values["mobilename"]) ?? "",
                "buildver": nonEmpty(values["buildver"])
                    ?? String(Int(Date().timeIntervalSince1970)),
                "resolution": nonEmpty(values["resolution"]) ?? "1920x1080",
                "__csrf": csrfToken,
                "channel": nonEmpty(values["channel"]) ?? profile.channel,
                "requestId": "\(Self.timestampMilliseconds)_\(Self.randomDigits(length: 4))",
            ]
        } else {
            header = [
                "os": "ios",
                "appver": "9.0.90",
                "osver": "18.0",
                "buildver": String(Int(Date().timeIntervalSince1970)),
                "channel": "distribution",
                "requestId": "\(Self.timestampMilliseconds)_0000",
                "__csrf": csrfToken,
            ]
        }

        if let musicU = cookieValues["MUSIC_U"] {
            header["MUSIC_U"] = musicU
        }
        if requiresCheckToken {
            header["X-antiCheatToken"] = Self.checkToken
        }
        return header
    }

    private func encodedCookieHeader(_ values: [String: String]) -> String {
        values.keys.sorted().map { key in
            "\(Self.encodeURIComponent(key))=\(Self.encodeURIComponent(values[key] ?? ""))"
        }.joined(separator: "; ")
    }

    private func jsonString(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let string = String(data: data, encoding: .utf8) else {
            throw APIError.requestEncoding
        }
        return string
    }

    private func aesECB(_ data: Data, key: String) throws -> Data {
        var output = Data(count: data.count + kCCBlockSizeAES128)
        let outputCapacity = output.count
        var outputLength = 0
        let status = output.withUnsafeMutableBytes { outputBytes in
            data.withUnsafeBytes { dataBytes in
                key.withCString { keyBytes in
                    return CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding) | CCOptions(kCCOptionECBMode),
                        keyBytes,
                        kCCKeySizeAES128,
                        nil,
                        dataBytes.baseAddress,
                        data.count,
                        outputBytes.baseAddress,
                        outputCapacity,
                        &outputLength
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw APIError.requestEncoding
        }
        output.removeSubrange(outputLength..<output.count)
        return output
    }

    private func aesCBC(_ data: Data, key: String) throws -> Data {
        let iv = "0102030405060708"
        var output = Data(count: data.count + kCCBlockSizeAES128)
        let outputCapacity = output.count
        var outputLength = 0
        let status = output.withUnsafeMutableBytes { outputBytes in
            data.withUnsafeBytes { dataBytes in
                key.withCString { keyBytes in
                    iv.withCString { ivBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes,
                            kCCKeySizeAES128,
                            ivBytes,
                            dataBytes.baseAddress,
                            data.count,
                            outputBytes.baseAddress,
                            outputCapacity,
                            &outputLength
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else {
            throw APIError.requestEncoding
        }
        output.removeSubrange(outputLength..<output.count)
        return output
    }

    private func makeWeapiSecretKey() -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var generator = SystemRandomNumberGenerator()
        return String((0..<16).compactMap { _ in
            characters.randomElement(using: &generator)
        })
    }

    private func rsaEncryptWeapiSecret(_ secret: String) throws -> String {
        guard let subjectPublicKeyInfo = Data(base64Encoded: Self.weapiPublicKey),
              subjectPublicKeyInfo.count > 22 else {
            throw APIError.requestEncoding
        }
        let pkcs1Key = subjectPublicKeyInfo.dropFirst(22)
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: 1_024,
        ]
        var keyError: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(
            Data(pkcs1Key) as CFData,
            attributes as CFDictionary,
            &keyError
        ) else {
            if let error = keyError?.takeRetainedValue() {
                throw error
            }
            throw APIError.requestEncoding
        }

        let message = Data(String(secret.reversed()).utf8)
        let blockSize = SecKeyGetBlockSize(publicKey)
        guard message.count <= blockSize else { throw APIError.requestEncoding }
        var paddedMessage = Data(repeating: 0, count: blockSize)
        paddedMessage.replaceSubrange(
            (blockSize - message.count)..<blockSize,
            with: message
        )

        var encryptionError: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(
            publicKey,
            .rsaEncryptionRaw,
            paddedMessage as CFData,
            &encryptionError
        ) as Data? else {
            if let error = encryptionError?.takeRetainedValue() {
                throw error
            }
            throw APIError.requestEncoding
        }
        return encrypted.map { String(format: "%02x", $0) }.joined()
    }

    private static let weapiPublicKey = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgtQn2JZ34ZC28NWYpAUd98iZ37BUrX/aKzmFbt7clFSs6sXqHauqKWqdtLkF2KexO40H1YTX8z2lSgBBOAxLsvaklV8k4cBFK9snQXE9/DDaFt6Rr7iVZMldczhC0JNgTz+SHXT6CBHuX3e9SdB1Ua44oncaTWz7OBGLbCiK45wIDAQAB"

    static let checkToken = "9ca17ae2e6ffcda170e2e6ee8af14fbabdb988f225b3868eb2c15a879b9a83d274a790ac8ff54a97b889d5d42af0feaec3b92af58cff99c470a7eafd88f75e839a9ea7c14e909da883e83fb692a3abdb6b92adee9e"
}

private struct WeapiCookieProfile {
    let os: String
    let appVersion: String
    let osVersion: String
    let channel: String
}
