import Foundation

struct AppUpdateResult: Equatable, Sendable {
    let currentVersion: String
    let latestVersion: String
    let releaseName: String
    let releaseURL: URL
    let publishedAt: Date?

    var hasUpdate: Bool {
        Self.compareVersion(latestVersion, to: currentVersion) == .orderedDescending
    }

    private static func compareVersion(_ lhs: String, to rhs: String) -> ComparisonResult {
        let lhsParts = normalizedVersionParts(lhs)
        let rhsParts = normalizedVersionParts(rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let lhsValue = index < lhsParts.count ? lhsParts[index] : 0
            let rhsValue = index < rhsParts.count ? rhsParts[index] : 0

            if lhsValue < rhsValue { return .orderedAscending }
            if lhsValue > rhsValue { return .orderedDescending }
        }

        return .orderedSame
    }

    private static func normalizedVersionParts(_ version: String) -> [Int] {
        version
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split { !$0.isNumber }
            .compactMap { Int($0) }
    }
}

enum AppUpdateService {
    nonisolated static let repositoryURL = URL(string: "https://github.com/youshen2/MeloX")!
    private nonisolated static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/youshen2/MeloX/releases/latest"
    )!

    nonisolated static func checkLatestRelease(currentVersion: String) async throws -> AppUpdateResult {
        var request = URLRequest(
            url: latestReleaseURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MeloX", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode != 404 else {
            throw AppUpdateError.noRelease
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let release = try decoder.decode(GitHubRelease.self, from: data)
        let latestVersion = release.tagName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !latestVersion.isEmpty,
              let releaseURL = URL(string: release.htmlURL) else {
            throw AppUpdateError.invalidRelease
        }
        let releaseName = (release.name?.isEmpty == false ? release.name : nil) ?? latestVersion

        return AppUpdateResult(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseName: releaseName,
            releaseURL: releaseURL,
            publishedAt: release.publishedAt
        )
    }
}

enum AppUpdateError: LocalizedError {
    case noRelease
    case invalidRelease

    var errorDescription: String? {
        switch self {
        case .noRelease:
            "当前仓库还没有发布版本。"
        case .invalidRelease:
            "发布信息格式不完整。"
        }
    }
}

private nonisolated struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: String
    let publishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case publishedAt = "published_at"
    }
}
