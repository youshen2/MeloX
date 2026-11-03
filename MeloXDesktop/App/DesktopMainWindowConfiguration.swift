import AppKit
import SwiftUI

enum DesktopMainWindowMetrics {
    static let minimumContentWidth: CGFloat = 980
    static let minimumContentHeight: CGFloat = 540
    /// The lyrics or queue column takes this width from the current window.
    static let playerSidePanelWidth: CGFloat = 258
    /// The navigation sidebar cannot be dragged wider than this.
    static let maximumSidebarWidth: CGFloat = 280
    static let presentationDuration: TimeInterval = 0.28
    static let presentationAnimation: Animation = .easeInOut(
        duration: presentationDuration
    )
}

/// Reports full-screen transitions and keeps the main window's minimum size.
/// The lyrics or queue column is laid out inside the current window.
struct DesktopMainWindowConfiguration: NSViewRepresentable {
    let isPlayerPresented: Bool
    @Binding var isFullScreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isFullScreen: $isFullScreen)
    }

    func makeNSView(context: Context) -> DesktopMainWindowProbe {
        let probe = DesktopMainWindowProbe()
        probe.windowDidChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.update(isPlayerPresented: isPlayerPresented)
        return probe
    }

    func updateNSView(
        _ nsView: DesktopMainWindowProbe,
        context: Context
    ) {
        context.coordinator.update(isPlayerPresented: isPlayerPresented)
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(
        _ nsView: DesktopMainWindowProbe,
        coordinator: Coordinator
    ) {
        nsView.windowDidChange = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private weak var installedWindow: NSWindow?
        private var isFullScreen: Binding<Bool>
        private var fullScreenObservers: [NSObjectProtocol] = []
        private let playerToolbar = DesktopPlayerToolbarController()

        init(isFullScreen: Binding<Bool>) {
            self.isFullScreen = isFullScreen
        }

        func update(isPlayerPresented: Bool) {
            playerToolbar.update(isPlayerPresented: isPlayerPresented)
        }

        func attach(to window: NSWindow?) {
            guard installedWindow !== window else { return }

            detach()
            installedWindow = window
            playerToolbar.attach(to: window)
            observeFullScreenChanges()
            applyMinimumContentSize()
        }

        func detach() {
            playerToolbar.detach()
            for observer in fullScreenObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            fullScreenObservers.removeAll()
            installedWindow = nil
        }

        private func observeFullScreenChanges() {
            guard let window = installedWindow else { return }
            fullScreenObservers = [
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
            ].map { name in
                NotificationCenter.default.addObserver(
                    forName: name,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.publishFullScreenState()
                    }
                }
            }
            publishFullScreenState()
        }

        private func publishFullScreenState() {
            // The initial attachment can occur inside a SwiftUI view update.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isFullScreen.wrappedValue =
                    self.installedWindow?.styleMask.contains(.fullScreen) == true
            }
        }

        private func applyMinimumContentSize() {
            guard let window = installedWindow else { return }

            let minimumContentSize = NSSize(
                width: DesktopMainWindowMetrics.minimumContentWidth,
                height: DesktopMainWindowMetrics.minimumContentHeight
            )
            guard window.contentMinSize != minimumContentSize else { return }
            window.contentMinSize = minimumContentSize
        }

    }
}

final class DesktopMainWindowProbe: NSView {
    var windowDidChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowDidChange?(window)
    }
}
