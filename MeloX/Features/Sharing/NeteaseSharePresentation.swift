import SwiftUI

enum NeteaseShareMode: String, Hashable {
    case privateMessage
    case timeline
}

struct NeteaseSharePresentation: Identifiable, Hashable {
    let resource: NeteaseShareResource
    let mode: NeteaseShareMode

    var id: String {
        "\(mode.rawValue)-\(resource.id)"
    }
}

struct OpenNeteaseShareAction {
    private let action: (NeteaseSharePresentation) -> Void

    init(action: @escaping (NeteaseSharePresentation) -> Void = { _ in }) {
        self.action = action
    }

    func callAsFunction(
        _ resource: NeteaseShareResource,
        mode: NeteaseShareMode
    ) {
        action(NeteaseSharePresentation(resource: resource, mode: mode))
    }
}

private struct OpenNeteaseShareActionKey: EnvironmentKey {
    static let defaultValue = OpenNeteaseShareAction()
}

extension EnvironmentValues {
    var openNeteaseShare: OpenNeteaseShareAction {
        get { self[OpenNeteaseShareActionKey.self] }
        set { self[OpenNeteaseShareActionKey.self] = newValue }
    }
}

struct NeteaseShareMenuContent: View {
    let resource: NeteaseShareResource

    @Environment(\.openNeteaseShare) private var openNeteaseShare

    var body: some View {
        Button {
            openNeteaseShare(resource, mode: .privateMessage)
        } label: {
            Label("网易云私信", systemImage: "paperplane")
        }

        if resource.supportsTimelineSharing {
            Button {
                openNeteaseShare(resource, mode: .timeline)
            } label: {
                Label("转发到动态", systemImage: "arrowshape.turn.up.right")
            }
        }

        ShareLink(item: resource.webURL) {
            Label("系统分享", systemImage: "square.and.arrow.up")
        }
    }
}
