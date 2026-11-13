import SwiftUI

struct MusicShelfLayout {
    var containerWidth: CGFloat = 390

    private var isWide: Bool { containerWidth >= 600 }
    var horizontalPadding: CGFloat { isWide ? 28 : 16 }
    var spacing: CGFloat { isWide ? 20 : 14 }

    func artworkSize(compact: CGFloat) -> CGFloat {
        guard isWide else { return compact }
        let available = max(containerWidth - horizontalPadding * 2, 1)
        let columns = max(Int((available + spacing) / 200), 3)
        return min(max((available - CGFloat(columns - 1) * spacing) / CGFloat(columns), compact), 224)
    }
}

private struct MusicShelfLayoutKey: EnvironmentKey {
    static let defaultValue = MusicShelfLayout()
}

private struct MusicUsesSidebarKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var musicShelfLayout: MusicShelfLayout {
        get { self[MusicShelfLayoutKey.self] }
        set { self[MusicShelfLayoutKey.self] = newValue }
    }

    var musicUsesSidebar: Bool {
        get { self[MusicUsesSidebarKey.self] }
        set { self[MusicUsesSidebarKey.self] = newValue }
    }
}
