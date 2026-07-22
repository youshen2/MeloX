import Foundation

enum LyricsStyle: String, CaseIterable, Identifiable {
    case appleMusic
    case eva

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .eva: "EVA"
        }
    }

    var systemImage: String {
        switch self {
        case .appleMusic: "quote.bubble"
        case .eva: "rectangle.split.3x1.fill"
        }
    }

    var description: String {
        switch self {
        case .appleMusic: "滚动歌词、距离模糊与逐字高亮"
        case .eva: "拐角排版、自适应标题卡与暖白辉光"
        }
    }
}
