import AppKit
import SwiftUI

/// Pins the lyrics column and the player bar to the detail column.
///
/// Pushed pages are hosted over the tab content, so a SwiftUI overlay there
/// disappears. These two views sit above that host, in the column they belong
/// to, and follow the sidebar divider while it moves.
struct DesktopColumnChrome<Panel: View, Player: View>: NSViewRepresentable {
    var panelWidth: CGFloat
    var panel: Panel
    var player: Player

    func makeCoordinator() -> Coordinator {
        Coordinator(panel: panel, player: player)
    }

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onWindow = { [weak coordinator = context.coordinator] _ in
            coordinator?.attach(to: view)
        }
        return view
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        context.coordinator.panelWidth = panelWidth
        context.coordinator.panelHost.rootView = panel
        context.coordinator.playerHost.rootView = player
        context.coordinator.attach(to: nsView)
        context.coordinator.place()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class ProbeView: NSView {
        var onWindow: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }

    @MainActor
    final class Coordinator {
        var panelWidth: CGFloat
        let panelHost: NSHostingView<Panel>
        let playerHost: NSHostingView<Player>
        private weak var installedWindow: NSWindow?
        private weak var observedDetailView: NSView?
        private var windowUpdateObserver: NSObjectProtocol?
        private var frameObserver: NSObjectProtocol?
        private var isPlacing = false

        init(panel: Panel, player: Player) {
            panelWidth = 0
            let panelHost = NSHostingView(rootView: panel)
            panelHost.sizingOptions = []
            self.panelHost = panelHost
            let playerHost = NSHostingView(rootView: player)
            playerHost.sizingOptions = [.intrinsicContentSize]
            self.playerHost = playerHost
        }

        func attach(to probe: NSView) {
            guard let window = probe.window else { return }
            guard installedWindow !== window else { return }

            detach()
            installedWindow = window
            windowUpdateObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didUpdateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.place()
                }
            }
            place()
        }

        func detach() {
            if let windowUpdateObserver {
                NotificationCenter.default.removeObserver(windowUpdateObserver)
            }
            windowUpdateObserver = nil
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
            }
            frameObserver = nil
            observedDetailView = nil
            installedWindow = nil
            panelHost.removeFromSuperview()
            playerHost.removeFromSuperview()
        }

        func place() {
            guard !isPlacing else { return }
            guard let content = installedWindow?.contentView,
                  let pair = Self.columnItems(below: content) else {
                return
            }
            let sidebar = pair.sidebar
            let detail = pair.detail

            isPlacing = true
            defer { isPlacing = false }

            let detailView = detail.viewController.view
            guard let container = detailView.superview else { return }
            observeFrame(of: detailView)

            let resolvedPanelWidth = min(
                max(panelWidth, 0),
                container.bounds.width
            )
            var detailFrame = detailView.frame
            let contentWidth = max(
                container.bounds.width - resolvedPanelWidth,
                0
            )
            if abs(detailFrame.size.width - contentWidth) > 0.5 {
                detailFrame.size.width = contentWidth
                detailView.frame = detailFrame
            }
            detailView.clipsToBounds = true

            if panelHost.superview !== container {
                container.addSubview(panelHost, positioned: .above, relativeTo: detailView)
            }
            panelHost.frame = NSRect(
                x: container.bounds.width - resolvedPanelWidth,
                y: container.bounds.minY,
                width: resolvedPanelWidth,
                height: container.bounds.height
            )
            panelHost.isHidden = resolvedPanelWidth < 1

            let sidebarFrame = sidebar.viewController.view.convert(
                sidebar.viewController.view.bounds,
                to: container
            )
            let visibleMinX = max(detailView.frame.minX, sidebarFrame.maxX)
            let visibleWidth = max(detailView.frame.maxX - visibleMinX, 0)
            playerHost.frame.size.width = visibleWidth
            playerHost.layoutSubtreeIfNeeded()
            let playerHeight = max(playerHost.intrinsicContentSize.height, 0)
            let playerY = container.isFlipped
                ? container.bounds.maxY - playerHeight
                : container.bounds.minY
            playerHost.frame = NSRect(
                x: visibleMinX,
                y: playerY,
                width: visibleWidth,
                height: playerHeight
            )
            playerHost.isHidden = playerHeight < 1 || visibleWidth < 1
            if playerHost.superview !== container {
                container.addSubview(playerHost, positioned: .above, relativeTo: nil)
            } else if container.subviews.last !== playerHost {
                container.addSubview(playerHost, positioned: .above, relativeTo: nil)
            }
        }

        private func observeFrame(of detailView: NSView) {
            guard observedDetailView !== detailView else { return }
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
            }
            detailView.postsFrameChangedNotifications = true
            observedDetailView = detailView
            frameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: detailView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.place()
                }
            }
        }

        private static func columnItems(
            below view: NSView
        ) -> (sidebar: NSSplitViewItem, detail: NSSplitViewItem)? {
            if let split = view as? NSSplitView,
               let controller = split.delegate as? NSSplitViewController {
                let sidebar = controller.splitViewItems.first {
                    $0.behavior == .sidebar
                }
                let detail = controller.splitViewItems.first {
                    $0.behavior != .sidebar && !$0.isCollapsed
                }
                if let sidebar, let detail {
                    return (sidebar, detail)
                }
            }
            for subview in view.subviews {
                if let found = columnItems(below: subview) { return found }
            }
            return nil
        }
    }
}
