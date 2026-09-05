import Foundation
import Observation

enum DesktopSection: String, CaseIterable, Identifiable, Hashable {
    case search
    case home
    case discovery
    case radio
    case recent
    case songs
    case playlists
    case albums
    case podcasts
    case downloads
    case cloud
    case messages

    var id: Self { self }

    var title: String {
        switch self {
        case .search: L10n.string("ui.navigation.search")
        case .home: L10n.string("ui.navigation.home")
        case .discovery: L10n.string("ui.navigation.explore")
        case .radio: L10n.string("ui.navigation.podcasts")
        case .recent: L10n.string("ui.navigation.library.history")
        case .songs: L10n.string("ui.navigation.library.liked_songs")
        case .playlists: L10n.string("ui.navigation.library.liked_playlists")
        case .albums: L10n.string("ui.navigation.library.liked_albums")
        case .podcasts: L10n.string("ui.navigation.library.podcasts")
        case .downloads: L10n.string("ui.navigation.downloads")
        case .cloud: L10n.string("ui.navigation.cloud")
        case .messages: L10n.string("ui.messages.private.title")
        }
    }

    var systemImage: String {
        switch self {
        case .search: "magnifyingglass"
        case .home: "house"
        case .discovery: "square.grid.2x2"
        case .radio: "dot.radiowaves.left.and.right"
        case .recent: "clock"
        case .songs: "heart"
        case .playlists: "music.note.list"
        case .albums: "square.stack"
        case .podcasts: "mic"
        case .downloads: "arrow.down.circle"
        case .cloud: "icloud"
        case .messages: "bubble.left.and.bubble.right"
        }
    }

    var requiredContentFeature: ContentFeature? {
        switch self {
        case .radio, .podcasts:
            .podcasts
        case .downloads:
            .downloads
        case .cloud:
            .cloudMusic
        case .recent:
            .listeningHistory
        case .search,
             .home,
             .discovery,
             .songs,
             .playlists,
             .albums,
             .messages:
            nil
        }
    }
}

enum DesktopRoute: Hashable {
    case album(Int)
    case artist(Int)
    case dailySongs
    case privateRoaming
    case playlist(Int)
    case podcast(Int)
    case podcastCategory(id: Int, title: String)
    case section(DesktopSection)
    case similarSongs(Int)
    case song(Int)
}

enum DesktopInspector: String, CaseIterable, Identifiable, Hashable {
    case lyrics
    case queue

    var id: Self { self }
}

enum DesktopSheet: Identifiable {
    case onboarding
    case account
    case login
    case recognition
    case listenTogether
    case listenTogetherInvitation(NeteaseListenTogetherLink)
    case sleepTimer
    case beatNetDebug

    var id: String {
        switch self {
        case .onboarding: "onboarding"
        case .account: "account"
        case .login: "login"
        case .recognition: "recognition"
        case .listenTogether: "listen-together"
        case .listenTogetherInvitation(let invitation):
            "listen-together-\(invitation.id)"
        case .sleepTimer: "sleep-timer"
        case .beatNetDebug: "beatnet-debug"
        }
    }
}

@MainActor
@Observable
final class DesktopUIState {
    var selection: DesktopSection = .home {
        didSet { path.removeAll() }
    }
    var path: [DesktopRoute] = []
    var inspector: DesktopInspector?
    private(set) var retainedInspector: DesktopInspector = .lyrics
    var sheet: DesktopSheet?
    var isSearchPresented = false
    var isPlayerHovered = false
    var isPlayerProgressHovered = false
    var isNowPlayingPresented = false
    private(set) var contextualLoadingMessages: [DesktopSection: String] = [:]
    private(set) var presentedLoadingMessage: String?

    var contextualLoadingMessage: String? {
        contextualLoadingMessages[selection]
    }

    func navigate(to route: DesktopRoute) {
        path.append(route)
    }

    func toggleInspector(_ requested: DesktopInspector) {
        if inspector == requested {
            inspector = nil
        } else {
            retainedInspector = requested
            inspector = requested
        }
    }

    func setContextualLoadingMessage(
        _ message: String?,
        for section: DesktopSection
    ) {
        if let message {
            contextualLoadingMessages[section] = message
        } else {
            contextualLoadingMessages.removeValue(forKey: section)
        }
    }

    func setPresentedLoadingMessage(_ message: String?) {
        presentedLoadingMessage = message
    }

    func clearPresentedLoadingMessage(ifMatching message: String) {
        guard presentedLoadingMessage == message else { return }
        presentedLoadingMessage = nil
    }
}
