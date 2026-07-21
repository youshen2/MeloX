import SwiftUI
import WebKit

struct NeteaseLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    @State private var page: WebPage

    init() {
        _page = State(initialValue: NeteaseWebCookieStore.makePage())
    }

    var body: some View {
        WebView(page)
            .webViewBackForwardNavigationGestures(.enabled)
            .overlay(alignment: .top) {
                if page.isLoading {
                    ProgressView(value: page.estimatedProgress)
                        .progressViewStyle(.linear)
                }
            }
            .navigationTitle("登录网易云音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .task {
                _ = page.load(URL(string: "https://music.163.com/#"))
                await waitForAuthenticatedCookie()
            }
    }

    private func waitForAuthenticatedCookie() async {
        while !Task.isCancelled {
            if let cookieHeader = await NeteaseWebCookieStore.authenticatedCookieHeader() {
                settings.cookie = cookieHeader
                await library.refresh(force: true)
                dismiss()
                return
            }

            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
        }
    }
}

@MainActor
enum NeteaseWebCookieStore {
    private static let dataStore = WKWebsiteDataStore.default()

    static func makePage() -> WebPage {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = dataStore
        configuration.defaultNavigationPreferences.preferredContentMode = .desktop
        return WebPage(configuration: configuration)
    }

    static func authenticatedCookieHeader() async -> String? {
        let cookies = await allCookies().filter(isUsableNeteaseCookie)
        guard cookies.contains(where: { $0.name == "MUSIC_U" && !$0.value.isEmpty }) else {
            return nil
        }

        let values = cookies.reduce(into: [String: String]()) { result, cookie in
            result[cookie.name] = cookie.value
        }
        return values.keys.sorted().map { "\($0)=\(values[$0] ?? "")" }.joined(separator: "; ")
    }

    static func clear() async {
        for cookie in await allCookies() where isNeteaseCookie(cookie) {
            await dataStore.httpCookieStore.deleteCookie(cookie)
        }
    }

    private static func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    private static func isUsableNeteaseCookie(_ cookie: HTTPCookie) -> Bool {
        isNeteaseCookie(cookie) && (cookie.expiresDate.map { $0 > Date() } ?? true)
    }

    private static func isNeteaseCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        return domain == "163.com" || domain.hasSuffix(".163.com")
    }
}
