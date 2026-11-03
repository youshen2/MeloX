import SwiftUI

/// Renders the player bar across the bottom of the content column.
/// The column already ends before the lyrics or queue panel.
struct DesktopTabBottomPlayer: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        if model.player.currentSong != nil {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                DesktopBottomPlayer()
                    .frame(maxWidth: DesktopBottomPlayerMetrics.outerWidth)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 24)
            .padding(.trailing, 24)
            .padding(.bottom, 10)
        }
    }
}

/// Reserves content space for the player bar mounted on the main window.
struct DesktopTabBottomPlayerInset: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        if model.player.currentSong != nil {
            Color.clear
                .frame(height: insetHeight)
                .accessibilityHidden(true)
        }
    }

    private var insetHeight: CGFloat {
        model.player.playbackIssue == nil
            ? DesktopBottomPlayerMetrics.regularGlobalInsetHeight
            : DesktopBottomPlayerMetrics.issueGlobalInsetHeight
    }
}

extension View {
    /// Keeps scrollable page content clear of the main-window player bar.
    /// Applied to sidebar roots and pushed routes alike. Content may draw
    /// underneath the bar while scrolling.
    func desktopBottomPlayerInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            DesktopTabBottomPlayerInset()
        }
    }
}

struct DesktopBottomPlayer: View {
    @Environment(DesktopAppModel.self) private var model
    @State private var isVolumeExpanded = false

    var body: some View {
        surfacedPlayer
            .shadow(color: .black.opacity(0.10), radius: 14, y: 7)
    }

    @ViewBuilder
    private var surfacedPlayer: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                playerContent
                    .glassEffect(
                        .regular,
                        in: .rect(cornerRadius: 27)
                    )
            }
        } else {
            playerContent
                .background(
                    .regularMaterial,
                    in: .rect(cornerRadius: 27, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .stroke(.white.opacity(0.42), lineWidth: 0.65)
                }
        }
    }

    private var playerContent: some View {
        VStack(spacing: 0) {
            if let issue = model.player.playbackIssue {
                HStack {
                    Label(issue.message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                    Spacer()
                    Button("ui.common.retry") { Task { await model.player.retry() } }
                    Button {
                        model.player.dismissPlaybackIssue()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }

            HStack(spacing: 0) {
                DesktopPlaybackControls()
                    .frame(width: DesktopBottomPlayerMetrics.transportWidth)

                Color.clear
                    .frame(width: DesktopBottomPlayerMetrics.clusterSpacing)

                if let song = model.player.currentSong {
                    DesktopBottomMetadataSlot(song: song) {
                        model.ui.isNowPlayingPresented = true
                    }
                    .frame(maxWidth: .infinity)
                }

                Color.clear
                    .frame(width: DesktopBottomPlayerMetrics.clusterSpacing)

                if !isVolumeExpanded {
                    inspectorButton(
                        .lyrics,
                        systemImage: "quote.bubble",
                        title: L10n.string("ui.desktop.commands.show_lyrics")
                    )

                    Color.clear.frame(
                        width: DesktopBottomPlayerMetrics
                            .trailingControlSpacing
                    )

                    inspectorButton(
                        .queue,
                        systemImage: "list.bullet",
                        title: L10n.string("ui.desktop.commands.show_queue")
                    )

                    Color.clear.frame(
                        width: DesktopBottomPlayerMetrics
                            .trailingControlSpacing
                    )
                }

                DesktopVolumeControl(isExpanded: $isVolumeExpanded)
            }
            .padding(.horizontal, DesktopBottomPlayerMetrics.horizontalInset)
            .frame(
                maxWidth: .infinity,
                minHeight: DesktopBottomPlayerMetrics.outerHeight,
                maxHeight: DesktopBottomPlayerMetrics.outerHeight
            )
        }
    }

    private func inspectorButton(
        _ destination: DesktopInspector,
        systemImage: String,
        title: String
    ) -> some View {
        let isSelected = model.ui.inspector == destination

        return Button {
            model.ui.toggleInspector(destination)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Color.red : Color.primary)
                .frame(width: 36, height: 36)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue(
            isSelected
                ? L10n.string("ui.common.selected")
                : L10n.string("ui.common.not_selected")
        )
    }
}
