import SwiftUI

private enum OnboardingRoute: Hashable {
    case neteaseAccount
}

private enum OnboardingSheet: String, Identifiable {
    case licenses
    case neteaseLogin

    var id: String { rawValue }
}

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    @State private var path: [OnboardingRoute]
    @State private var presentedSheet: OnboardingSheet?

    init(startsAtAccount: Bool = false) {
        _path = State(
            initialValue: startsAtAccount ? [.neteaseAccount] : []
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingWelcomeView(
                continueAction: {
                    path.append(.neteaseAccount)
                },
                showLicenses: {
                    presentedSheet = .licenses
                }
            )
            .navigationDestination(for: OnboardingRoute.self) { route in
                switch route {
                case .neteaseAccount:
                    OnboardingAccountView(
                        profile: library.profile,
                        isLoggedIn: library.isLoggedIn,
                        login: {
                            presentedSheet = .neteaseLogin
                        },
                        finish: {
                            settings.completeOnboarding()
                        }
                    )
                }
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .licenses:
                NavigationStack {
                    ProjectLicensesView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("完成") {
                                    presentedSheet = nil
                                }
                            }
                        }
                }
            case .neteaseLogin:
                NavigationStack {
                    NeteaseLoginView()
                }
            }
        }
    }
}

#Preview("欢迎") {
    OnboardingPreview(startsAtAccount: false)
}

#Preview("网易云登录") {
    OnboardingPreview(startsAtAccount: true)
}

private struct OnboardingPreview: View {
    let startsAtAccount: Bool
    let settings: AppSettings
    let library: LibraryStore

    init(startsAtAccount: Bool) {
        let suiteName = "MeloX.OnboardingPreview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let settings = AppSettings(defaults: defaults)

        self.startsAtAccount = startsAtAccount
        self.settings = settings
        library = LibraryStore(
            api: NeteaseAPI(settings: settings),
            settings: settings
        )
    }

    var body: some View {
        OnboardingView(startsAtAccount: startsAtAccount)
            .environment(settings)
            .environment(library)
            .tint(.red)
    }
}
