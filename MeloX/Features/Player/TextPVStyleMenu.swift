import SwiftUI

struct TextPVStyleMenu: View {
    @Environment(AppSettings.self) private var settings

    @Binding var page: NowPlayingPage

    var body: some View {
        Menu {
            ForEach(TextPVStyleMenuGroup.allCases) { group in
                Menu {
                    ForEach(group.styles) { style in
                        Button {
                            select(style)
                        } label: {
                            Label(
                                style.title,
                                systemImage: style == settings.textPV.style
                                    ? "checkmark"
                                    : style.systemImage
                            )
                        }
                    }
                } label: {
                    Label(group.title, systemImage: group.systemImage)
                }
            }
        } label: {
            Label("文字PV", systemImage: LyricsStyle.textPV.systemImage)
        }
        .accessibilityLabel("文字PV风格")
        .accessibilityValue(settings.textPV.style.title)
    }

    private func select(_ style: TextPVStyle) {
        settings.textPV.style = style
        settings.lyricsStyle = .textPV
        withAnimation(.smooth(duration: 0.3)) {
            page = .lyrics
        }
    }
}

private enum TextPVStyleMenuGroup: String, CaseIterable, Identifiable {
    case foundation
    case dramatic
    case themed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundation: "基础构成"
        case .dramatic: "氛围与故障"
        case .themed: "主题与像素"
        }
    }

    var systemImage: String {
        switch self {
        case .foundation: "square.3.layers.3d"
        case .dramatic: "waveform.path.ecg"
        case .themed: "sparkles"
        }
    }

    var styles: ArraySlice<TextPVStyle> {
        switch self {
        case .foundation: TextPVStyle.allCases[0..<6]
        case .dramatic: TextPVStyle.allCases[6..<12]
        case .themed: TextPVStyle.allCases[12..<18]
        }
    }
}
