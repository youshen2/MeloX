import SwiftUI

struct DesktopQueueView: View {
    @Environment(DesktopAppModel.self) private var model
    var presentation: DesktopQueuePresentation = .inspector

    private let continueHeaderID = "apple-music-continue-header"

    private var metrics: DesktopQueueMetrics {
        DesktopQueueMetrics(presentation: presentation)
    }

    private var historyEntries: [DesktopQueueEntry] {
        model.player.historyQueueEntries.map {
            DesktopQueueEntry(
                section: .history,
                queueIndex: $0.queueIndex,
                song: $0.song
            )
        }
    }

    private var upcomingEntries: [DesktopQueueEntry] {
        model.player.upcomingQueueEntries.map {
            DesktopQueueEntry(
                section: .upcoming,
                queueIndex: $0.queueIndex,
                song: $0.song
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            modeControlRow
                .padding(.horizontal, metrics.modeHorizontalPadding)
                .padding(.top, metrics.modeTopPadding)

            queueList
                .padding(.bottom, metrics.bottomInset)
        }
    }

    private var queueList: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !historyEntries.isEmpty {
                            queueHeader(
                                title: L10n.string("ui.common.history"),
                                actionTitle: L10n.string("ui.common.clear"),
                                isActionDisabled: historyEntries.count <= 1,
                                action: {
                                    model.player.clearPlaybackHistory()
                                }
                            )
                            queueRows(historyEntries)
                        }

                        queueHeader(
                            title: L10n.string("ui.desktop.player.continue_playing"),
                            actionTitle: L10n.string("ui.common.clear"),
                            isActionDisabled: upcomingEntries.isEmpty,
                            action: {
                                model.player.clearUpcomingQueue()
                            }
                        )
                        .id(continueHeaderID)

                        if upcomingEntries.isEmpty {
                            Text("ui.player.queue_empty")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.secondary)
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: max(
                                        geometry.size.height
                                            - metrics.headerHeight,
                                        55
                                    )
                                )
                        } else {
                            queueRows(upcomingEntries)
                        }
                    }
                    // Let the last row scroll completely above the fade mask.
                    .padding(.bottom, metrics.bottomFadeHeight)
                }
                .scrollContentBackground(.hidden)
                .mask(alignment: .top) {
                    VStack(spacing: 0) {
                        Color.black
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: metrics.bottomFadeHeight)
                    }
                }
                .task(id: initialScrollRequestID) {
                    await Task.yield()
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(continueHeaderID, anchor: .top)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func queueRows(
        _ entries: [DesktopQueueEntry]
    ) -> some View {
        ForEach(entries) { entry in
            DesktopQueueRow(
                entry: entry,
                presentation: presentation,
                metrics: metrics
            )
            .padding(
                EdgeInsets(
                    top: metrics.rowVerticalInset,
                    leading: metrics.rowLeadingInset,
                    bottom: metrics.rowVerticalInset,
                    trailing: metrics.rowTrailingInset
                )
            )
            .background(Color.clear)

            if entry.id != entries.last?.id {
                Divider()
                    .overlay(rowSeparatorColor)
                    .padding(.leading, metrics.rowLeadingInset)
            }
        }
    }

    private func queueHeader(
        title: String,
        actionTitle: String,
        isActionDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(.plain)
                .font(metrics.clearFont)
                .foregroundStyle(.red)
                .disabled(isActionDisabled)
        }
        .padding(.horizontal, metrics.headerHorizontalPadding)
        .frame(height: metrics.headerHeight)
        .textCase(nil)
    }

    private var modeControlRow: some View {
        HStack(spacing: metrics.modeSpacing) {
            modeButton(
                L10n.string("ui.desktop.player.autoplay"),
                iconWeight: .semibold,
                isSelected: model.player.isAutoplayEnabled
            ) {
                model.player.toggleAutoplay()
            }
            modeButton(
                L10n.string("ui.settings.automix.title"),
                iconWeight: .black,
                isSelected: model.player.isAutoMixEnabled
            ) {
                model.player.setAutoMixEnabled(
                    !model.player.isAutoMixEnabled
                )
            }
        }
    }

    private func modeButton(
        _ title: String,
        iconWeight: Font.Weight,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "infinity")
                .font(.system(size: 16, weight: iconWeight))
                .foregroundStyle(modeForeground(isSelected: isSelected))
                .frame(maxWidth: .infinity)
                .frame(height: metrics.modeHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .background(
            modeBackground(isSelected: isSelected),
            in: .capsule
        )
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.07), lineWidth: 0.5)
        }
        .accessibilityLabel(title)
        .accessibilityValue(
            isSelected
                ? L10n.string("ui.common.on")
                : L10n.string("ui.common.off")
        )
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private func modeForeground(isSelected: Bool) -> Color {
        guard metrics.usesProminentSelection else { return .primary }
        return isSelected ? .white : .primary.opacity(0.88)
    }

    private func modeBackground(isSelected: Bool) -> Color {
        guard metrics.usesProminentSelection else {
            return .primary.opacity(isSelected ? 0.15 : 0.07)
        }
        return isSelected ? .red : .primary.opacity(0.10)
    }

    private var rowSeparatorColor: Color {
        switch presentation {
        case .nowPlaying:
            .white.opacity(0.13)
        case .inspector, .miniPlayer:
            .primary.opacity(0.10)
        }
    }

    private var initialScrollRequestID: String {
        "\(presentation)-\(model.player.currentSong?.id ?? 0)"
    }
}
