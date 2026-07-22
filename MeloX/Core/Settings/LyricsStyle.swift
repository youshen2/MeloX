import Foundation

enum LyricsStyle: String, CaseIterable, Identifiable {
    case appleMusic
    case eva
    case textPV1

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .eva: "EVA"
        case .textPV1: "文字PV1"
        }
    }

    var systemImage: String {
        switch self {
        case .appleMusic: "quote.bubble"
        case .eva: "rectangle.split.3x1.fill"
        case .textPV1: "textformat.size.larger"
        }
    }

    var description: String {
        switch self {
        case .appleMusic: "滚动歌词、距离模糊与逐字高亮"
        case .eva: "拐角排版、自适应标题卡与暖白辉光"
        case .textPV1: "八组黑白构图、动态排字与几何冲击镜头"
        }
    }

    var usesMonochromePlayerBackground: Bool {
        switch self {
        case .eva, .textPV1: true
        case .appleMusic: false
        }
    }
}
