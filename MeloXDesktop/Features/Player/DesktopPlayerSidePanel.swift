import SwiftUI

/// The lyrics or queue column beside the page. Closing it collapses the
/// column instead of sliding a cover across the page. The glass fills only
/// this column.
struct DesktopPlayerSidePanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var renderingSelection: DesktopInspector?

    let selection: DesktopInspector
    let isPresented: Bool

    var body: some View {
        surfacedPanel
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .top)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(selection.accessibilityTitle)
            .task(id: renderingRequest) {
                await updateRenderingSelection()
            }
    }

    @ViewBuilder
    private var surfacedPanel: some View {
        if isPresented || renderingSelection != nil {
            if #available(macOS 26.0, *) {
                crossfadingContent
                    .background {
                        Color.clear
                            .glassEffect(
                                .regular,
                                in: .rect(cornerRadius: 0)
                            )
                    }
            } else {
                crossfadingContent
                    .background {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                    }
            }
        } else {
            Color.clear
        }
    }

    private var crossfadingContent: some View {
        ZStack {
            if renderingSelection != nil {
                DesktopPlayerInspector(
                    kind: selection,
                    isActive: isPresented && renderingSelection == selection
                )
                .id(selection)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(
            reduceMotion
                ? nil
                : DesktopMainWindowMetrics.presentationAnimation,
            value: selection
        )
        .clipped()
    }

    private var renderingRequest: RenderingRequest {
        RenderingRequest(
            selection: selection,
            isPresented: isPresented
        )
    }

    private func updateRenderingSelection() async {
        guard isPresented else {
            if !reduceMotion {
                do {
                    try await Task.sleep(
                        for: .seconds(
                            DesktopMainWindowMetrics.presentationDuration
                        )
                    )
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            commitRenderingSelection(nil)
            return
        }

        commitRenderingSelection(selection)
    }

    private func commitRenderingSelection(
        _ selection: DesktopInspector?
    ) {
        guard renderingSelection != selection else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            renderingSelection = selection
        }
    }
}

private struct RenderingRequest: Hashable {
    let selection: DesktopInspector
    let isPresented: Bool
}

private extension DesktopInspector {
    var accessibilityTitle: String {
        switch self {
        case .lyrics:
            L10n.string("ui.common.lyrics")
        case .queue:
            L10n.string("ui.player.queue")
        }
    }
}
