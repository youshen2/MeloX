import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case explore
    case library
    case search
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "首页"
        case .explore: "发现"
        case .library: "音乐库"
        case .search: "搜索"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .explore: "safari"
        case .library: "music.note.list"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

enum LibraryPage: String, CaseIterable, Identifiable {
    case songs
    case playlists
    case downloads
    case cloud
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .songs: "歌曲"
        case .playlists: "歌单"
        case .downloads: "下载"
        case .cloud: "云盘"
        case .history: "历史"
        }
    }

    var systemImage: String {
        switch self {
        case .songs: "music.note"
        case .playlists: "music.note.list"
        case .downloads: "arrow.down.circle"
        case .cloud: "icloud"
        case .history: "clock"
        }
    }
}
