import AppKit

@MainActor
final class DesktopPlayerToolbarController {
    private weak var window: NSWindow?
    private var transparentToolbarWindows: [ToolbarWindowAppearance] = []
    private var windowUpdateObserver: NSObjectProtocol?
    private var isPlayerPresented = false
    private var isApplyingChange = false

    func update(isPlayerPresented: Bool) {
        self.isPlayerPresented = isPlayerPresented
        synchronize()
    }

    func attach(to window: NSWindow?) {
        guard self.window !== window else {
            synchronize()
            return
        }
        detach()
        self.window = window
        guard window != nil else { return }
        windowUpdateObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, let window = self.window,
                      let updatedWindow = notification.object as? NSWindow,
                      updatedWindow === window || updatedWindow.parent === window else {
                    return
                }
                self.synchronize()
            }
        }
        synchronize()
    }

    func detach() {
        if let windowUpdateObserver {
            NotificationCenter.default.removeObserver(windowUpdateObserver)
        }
        windowUpdateObserver = nil
        restoreToolbarWindows()
        window = nil
    }

    private func synchronize() {
        guard let window, !isApplyingChange else { return }
        isApplyingChange = true
        defer { isApplyingChange = false }

        if isPlayerPresented, window.styleMask.contains(.fullScreen) {
            makeToolbarWindowsTransparent(in: window)
        } else {
            restoreToolbarWindows()
        }
    }

    private func makeToolbarWindowsTransparent(in window: NSWindow) {
        // The native full-screen titlebar is a full-width, borderless child
        // at the screen's top edge. Its internal background can still draw
        // over a transparent window background. Keep its content transparent
        // while AppKit animates the child window's own opacity on hover.
        let topInset = NSStatusBar.system.thickness
        for child in window.childWindows ?? [] {
            let frame = child.frame
            guard child.styleMask.isEmpty,
                  abs(frame.minX - window.frame.minX) < 1,
                  abs(frame.width - window.frame.width) < 1,
                  frame.height <= topInset * 3,
                  abs(frame.maxY - window.frame.maxY) <= topInset * 2,
                  let contentView = child.contentView else {
                continue
            }
            if !transparentToolbarWindows.contains(where: { $0.window === child }) {
                transparentToolbarWindows.append(ToolbarWindowAppearance(
                    window: child,
                    contentView: contentView,
                    contentAlphaValue: contentView.alphaValue,
                    ignoresMouseEvents: child.ignoresMouseEvents
                ))
            }
            if contentView.alphaValue != 0 {
                contentView.alphaValue = 0
            }
            if !child.ignoresMouseEvents {
                child.ignoresMouseEvents = true
            }
        }
    }

    private func restoreToolbarWindows() {
        for appearance in transparentToolbarWindows {
            appearance.contentView?.alphaValue = appearance.contentAlphaValue
            appearance.window?.ignoresMouseEvents = appearance.ignoresMouseEvents
        }
        transparentToolbarWindows.removeAll()
    }

    private struct ToolbarWindowAppearance {
        weak var window: NSWindow?
        weak var contentView: NSView?
        let contentAlphaValue: CGFloat
        let ignoresMouseEvents: Bool
    }
}
