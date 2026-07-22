import Foundation

enum LyricsStyle: String, CaseIterable, Identifiable {
    case appleMusic
    case eva
    case textPV

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .eva: "EVA"
        case .textPV: "文字PV"
        }
    }

    var systemImage: String {
        switch self {
        case .appleMusic: "quote.bubble"
        case .eva: "rectangle.split.3x1.fill"
        case .textPV: "textformat.size.larger"
        }
    }

    var description: String {
        switch self {
        case .appleMusic: "滚动歌词、距离模糊与逐字高亮"
        case .eva: "拐角排版、自适应标题卡与暖白辉光"
        case .textPV: "模板化动态排字、几何图层与后期效果"
        }
    }

    var usesMonochromePlayerBackground: Bool {
        switch self {
        case .eva, .textPV: true
        case .appleMusic: false
        }
    }
}
