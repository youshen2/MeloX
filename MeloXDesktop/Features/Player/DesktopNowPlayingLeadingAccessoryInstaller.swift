import AppKit
import SwiftUI

/// Places the player window controls directly after the traffic lights.
///
/// SwiftUI's `.navigation` toolbar placement is laid out after the sidebar
/// tracking separator. A left titlebar accessory is the AppKit-supported slot
/// immediately adjacent to the window controls, while leaving the window's
/// `NSToolbar` fully owned by SwiftUI.
struct DesktopNowPlayingLeadingAccessoryInstaller: NSViewRepresentable {
    let isPresented: Bool
    let close: () -> Void
    let openMiniPlayer: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> DesktopNowPlayingAccessoryWindowProbe {
        let probe = DesktopNowPlayingAccessoryWindowProbe()
        probe.windowDidChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.update(
            isPresented: isPresented,
            close: close,
            openMiniPlayer: openMiniPlayer
        )
        return probe
    }

    func updateNSView(
        _ nsView: DesktopNowPlayingAccessoryWindowProbe,
        context: Context
    ) {
        context.coordinator.update(
            isPresented: isPresented,
            close: close,
            openMiniPlayer: openMiniPlayer
        )
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(
        _ nsView: DesktopNowPlayingAccessoryWindowProbe,
        coordinator: Coordinator
    ) {
        nsView.windowDidChange = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private weak var installedWindow: NSWindow?
        private var isPresented = false
        private var accessoryController: NSTitlebarAccessoryViewController?
        private let hostingView: NSHostingView<DesktopNowPlayingLeadingAccessoryContent>

        init() {
            hostingView = NSHostingView(
                rootView: DesktopNowPlayingLeadingAccessoryContent(
                    close: {},
                    openMiniPlayer: {}
                )
            )
            hostingView.frame = NSRect(x: 0, y: 0, width: 74, height: 36)
        }

        func update(
            isPresented: Bool,
            close: @escaping () -> Void,
            openMiniPlayer: @escaping () -> Void
        ) {
            self.isPresented = isPresented
            hostingView.rootView = DesktopNowPlayingLeadingAccessoryContent(
                close: close,
                openMiniPlayer: openMiniPlayer
            )
            reconcileInstallation()
        }

        func attach(to window: NSWindow?) {
            guard installedWindow !== window else {
                reconcileInstallation()
                return
            }
            detach()
            installedWindow = window
            reconcileInstallation()
        }

        func detach() {
            accessoryController?.removeFromParent()
            accessoryController = nil
            installedWindow = nil
        }

        private func reconcileInstallation() {
            guard let window = installedWindow else { return }
            let isInstalled = accessoryController.map { controller in
                window.titlebarAccessoryViewControllers.contains { $0 === controller }
            } ?? false

            if isPresented, !isInstalled {
                let controller = NSTitlebarAccessoryViewController()
                controller.layoutAttribute = .left
                controller.view = hostingView
                window.addTitlebarAccessoryViewController(controller)
                accessoryController = controller
            } else if !isPresented {
                accessoryController?.removeFromParent()
                accessoryController = nil
            }
        }
    }
}

final class DesktopNowPlayingAccessoryWindowProbe: NSView {
    var windowDidChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowDidChange?(window)
    }
}

private struct DesktopNowPlayingLeadingAccessoryContent: View {
    let close: () -> Void
    let openMiniPlayer: () -> Void

    var body: some View {
        DesktopNowPlayingWindowControls(
            close: close,
            openMiniPlayer: openMiniPlayer
        )
        .frame(width: 74, height: 36)
        .environment(\.colorScheme, .dark)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
