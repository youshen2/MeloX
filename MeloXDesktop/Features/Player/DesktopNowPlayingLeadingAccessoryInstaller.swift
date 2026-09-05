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
        private let accessoryController: NSTitlebarAccessoryViewController
        private let hostingView: NSHostingView<DesktopNowPlayingLeadingAccessoryContent>

        init() {
            hostingView = NSHostingView(
                rootView: DesktopNowPlayingLeadingAccessoryContent(
                    isPresented: false,
                    close: {},
                    openMiniPlayer: {}
                )
            )
            hostingView.frame = NSRect(x: 0, y: 0, width: 74, height: 36)

            accessoryController = NSTitlebarAccessoryViewController()
            accessoryController.layoutAttribute = .left
            accessoryController.view = hostingView
        }

        func update(
            isPresented: Bool,
            close: @escaping () -> Void,
            openMiniPlayer: @escaping () -> Void
        ) {
            hostingView.rootView = DesktopNowPlayingLeadingAccessoryContent(
                isPresented: isPresented,
                close: close,
                openMiniPlayer: openMiniPlayer
            )
        }

        func attach(to window: NSWindow?) {
            guard let window else {
                detach()
                return
            }

            let isAlreadyInstalled = window.titlebarAccessoryViewControllers
                .contains { $0 === accessoryController }
            guard installedWindow !== window || !isAlreadyInstalled else {
                return
            }

            detach()
            window.addTitlebarAccessoryViewController(accessoryController)
            installedWindow = window
        }

        func detach() {
            accessoryController.removeFromParent()
            installedWindow = nil
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
    let isPresented: Bool
    let close: () -> Void
    let openMiniPlayer: () -> Void

    var body: some View {
        DesktopNowPlayingWindowControls(
            close: close,
            openMiniPlayer: openMiniPlayer
        )
        .frame(width: 74, height: 36)
        .environment(\.colorScheme, .dark)
        .opacity(isPresented ? 1 : 0)
        .allowsHitTesting(isPresented)
        .accessibilityHidden(!isPresented)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
