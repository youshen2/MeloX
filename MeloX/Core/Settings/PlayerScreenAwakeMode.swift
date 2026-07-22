import Foundation

enum PlayerScreenAwakeMode: String, CaseIterable, Identifiable {
    case disabled
    case player
    case lyrics
    case hiddenLyricsInterface

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled:
            "关闭"
        case .player:
            "播放器常亮"
        case .lyrics:
            "歌词页常亮"
        case .hiddenLyricsInterface:
            "歌词页隐藏 UI 后常亮"
        }
    }
}
