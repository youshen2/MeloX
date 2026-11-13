import AppKit
import SwiftUI

struct DesktopFloatingLyricsWindowConfiguration: NSViewRepresentable {
    let isPositionLocked: Bool
    var onHoverChanged: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = DesktopFloatingLyricsWindowConfigurationView()
        view.isPositionLocked = isPositionLocked
        view.onHoverChanged = onHoverChanged
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? DesktopFloatingLyricsWindowConfigurationView else { return }
        view.isPositionLocked = isPositionLocked
        view.onHoverChanged = onHoverChanged
        view.configureWindow()
    }
}

enum DesktopFloatingLyricsWindowMetrics {
    static let defaultWidth: CGFloat = 420
    static let defaultHeight: CGFloat = 96
    static let minimumWidth: CGFloat = 300
    static let minimumHeight: CGFloat = 72
}

private final class DesktopFloatingLyricsWindowConfigurationView: NSView {
    var isPositionLocked = false
    var onHoverChanged: ((Bool) -> Void)?
    private var pointerTimer: Timer?
    private var lastHovered = false
    private weak var configuredWindow: NSWindow?
    private var isRestoring = false
    private static let frameKey = "floatingLyrics.savedWindowFrame"
    private static let sizingVersion = 1
    private static let sizingVersionKey = "floatingLyrics.windowSizingVersion"

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            pointerTimer?.invalidate()
            pointerTimer = nil
        }
        configureWindow()
    }

    func configureWindow() {
        guard let window else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        updateMouseRouting()
        window.acceptsMouseMovedEvents = true
        window.isMovable = !isPositionLocked
        window.isMovableByWindowBackground = !isPositionLocked
        if isPositionLocked {
            window.styleMask.remove(.resizable)
        } else {
            window.styleMask.insert(.resizable)
        }
        window.minSize = NSSize(
            width: DesktopFloatingLyricsWindowMetrics.minimumWidth,
            height: DesktopFloatingLyricsWindowMetrics.minimumHeight
        )
        window.collectionBehavior.formUnion([
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
        ])
        applyDefaultSizeIfNeeded(to: window)
        window.invalidateShadow()
        if configuredWindow !== window {
            NotificationCenter.default.removeObserver(self)
            configuredWindow = window
            pointerTimer?.invalidate()
            let timer = Timer(timeInterval: 0.04, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateMouseRouting() }
            }
            pointerTimer = timer
            RunLoop.main.add(timer, forMode: .common)
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.willCloseNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(saveFrame), name: name, object: window)
            }
            NotificationCenter.default.addObserver(self, selector: #selector(restoreVisibleFrame),
                name: NSApplication.didChangeScreenParametersNotification, object: nil)
            // Wait for SwiftUI's initial window placement before restoring ours.
            isRestoring = true
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window, self.configuredWindow === window else { return }
                if let value = UserDefaults.standard.string(forKey: Self.frameKey) {
                    let frame = NSRectFromString(value)
                    if frame.width.isFinite && frame.height.isFinite && frame.origin.x.isFinite && frame.origin.y.isFinite
                        && frame.width >= DesktopFloatingLyricsWindowMetrics.minimumWidth
                        && frame.height >= DesktopFloatingLyricsWindowMetrics.minimumHeight {
                        window.setFrame(Self.visibleFrame(frame), display: true)
                    }
                }
                self.isRestoring = false
                self.saveFrame()
            }
        }
    }

    private func updateMouseRouting() {
        guard let window else { return }
        let point = NSEvent.mouseLocation
        let hovered = window.isVisible && !window.isMiniaturized && window.frame.contains(point)
        if hovered != lastHovered {
            lastHovered = hovered
            // This also reveals controls while the window ignores mouse events.
            let callback = onHoverChanged
            DispatchQueue.main.async { callback?(hovered) }
        }
        let controlView = window.contentView.flatMap { Self.controlRegion(in: $0) }
        let controlFrame = controlView.map { window.convertToScreen($0.convert($0.bounds, to: nil)) }
        let overControls = hovered && (controlFrame?.contains(point) ?? false)
        window.ignoresMouseEvents = isPositionLocked && !overControls
    }

    private static func controlRegion(in view: NSView) -> DesktopFloatingLyricsControlRegionView? {
        if let region = view as? DesktopFloatingLyricsControlRegionView { return region }
        for child in view.subviews {
            if let region = controlRegion(in: child) { return region }
        }
        return nil
    }

    @objc private func saveFrame() {
        guard !isRestoring, let window = configuredWindow else { return }
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Self.frameKey)
    }

    @objc private func restoreVisibleFrame() {
        guard let window = configuredWindow else { return }
        window.setFrame(Self.visibleFrame(window.frame), display: true)
        saveFrame()
    }

    /// Keep the entire window reachable after a monitor is unplugged.
    private static func visibleFrame(_ frame: NSRect) -> NSRect {
        guard let screen = NSScreen.screens.max(by: {
            $0.visibleFrame.intersection(frame).area < $1.visibleFrame.intersection(frame).area
        }) else { return frame }
        let bounds = screen.visibleFrame
        var result = frame
        result.size.width = min(result.width, bounds.width)
        result.size.height = min(result.height, bounds.height)
        result.origin.x = min(max(result.minX, bounds.minX), bounds.maxX - result.width)
        result.origin.y = min(max(result.minY, bounds.minY), bounds.maxY - result.height)
        return result
    }

    private func applyDefaultSizeIfNeeded(to window: NSWindow) {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: Self.sizingVersionKey)
            < Self.sizingVersion else {
            return
        }

        window.setContentSize(
            NSSize(
                width: DesktopFloatingLyricsWindowMetrics.defaultWidth,
                height: DesktopFloatingLyricsWindowMetrics.defaultHeight
            )
        )
        defaults.set(Self.sizingVersion, forKey: Self.sizingVersionKey)
    }
}

private extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

/// Transparent SwiftUI text does not consistently participate in AppKit's
/// background dragging. Handle native dragging over the full lyrics rectangle.
struct DesktopFloatingLyricsDragSurface: NSViewRepresentable {
    let isPositionLocked: Bool
    func makeNSView(context: Context) -> DesktopFloatingLyricsDragView {
        let view = DesktopFloatingLyricsDragView()
        view.isPositionLocked = isPositionLocked
        return view
    }
    func updateNSView(_ view: DesktopFloatingLyricsDragView, context: Context) {
        view.isPositionLocked = isPositionLocked
    }
}

final class DesktopFloatingLyricsDragView: NSView {
    var isPositionLocked = false
    override var mouseDownCanMoveWindow: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        // A nearly transparent fill lets the window server hit-test empty space.
        NSColor.black.withAlphaComponent(0.01).setFill()
        dirtyRect.fill()
    }
    override func mouseDown(with event: NSEvent) {
        guard !isPositionLocked else { return }
        window?.performDrag(with: event)
    }
}

/// Native geometry of the buttons; only this rectangle captures clicks when locked.
struct DesktopFloatingLyricsControlRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> DesktopFloatingLyricsControlRegionView {
        DesktopFloatingLyricsControlRegionView()
    }
    func updateNSView(_ view: DesktopFloatingLyricsControlRegionView, context: Context) {}
}
final class DesktopFloatingLyricsControlRegionView: NSView {}
