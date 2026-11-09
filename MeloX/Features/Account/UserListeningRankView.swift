import SwiftUI

struct UserListeningRankView: View {
    let userID: Int

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player

    @State private var selectedPeriod = UserPlayRecordPeriod.week
    @State private var recordsByPeriod:
        [UserPlayRecordPeriod: [UserPlayRecord]] = [:]
    @State private var phasesByPeriod:
        [UserPlayRecordPeriod: LoadingPhase] = [:]
    @State private var refreshErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            FilterPicker(
                title: "ui.account.listening_rank.period",
                selection: $selectedPeriod,
                maximumWidth: 360
            ) {
                ForEach(UserPlayRecordPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, contentInset)
            .padding(.vertical, 16)

            content
        }
        .navigationTitle("ui.library.my_listening_rank")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPeriod) {
            await load(period: selectedPeriod)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await load(period: selectedPeriod, force: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(currentPhase == .loading)
                .accessibilityLabel("ui.account.listening_rank.refresh")
            }
        }
        .alert(
            "ui.account.listening_rank.refresh_failed",
            isPresented: Binding(
                get: { refreshErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        refreshErrorMessage = nil
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                refreshErrorMessage = nil
            }
        } message: {
            Text(refreshErrorMessage ?? L10n.string("ui.error.try_again_later"))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch currentPhase {
        case .loading:
            ProgressView("ui.account.listening_rank.loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ConnectionUnavailableView(message: message) {
                Task {
                    await load(period: selectedPeriod, force: true)
                }
            }
        case .loaded:
            loadedContent
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if currentRecords.isEmpty {
            ContentUnavailableView(
                "ui.account.listening_rank.empty",
                systemImage: "chart.bar.xaxis",
                description: Text(selectedPeriod.emptyDescription)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                rankActions
                    .listRowSeparator(.hidden)
                    .listRowInsets(rowInsets(top: 0, bottom: 14))

                ForEach(Array(currentRecords.enumerated()), id: \.element.song.id) {
                    index,
                    record in
                    Button {
                        Task {
                            await player.play(record.song, in: currentSongs)
                        }
                    } label: {
                        TrackRowView(
                            song: record.song,
                            index: index,
                            showsArtwork: true,
                            secondaryMetadata:
                                L10n.format("ui.common.play_count", record.playCount)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(rowInsets(top: 6, bottom: 6))
                }
            }
            .listStyle(.plain)
            .refreshable {
                await load(period: selectedPeriod, force: true)
            }
        }
    }

    private var rankActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                playAllButton
                periodDescription.fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: 10) {
                playAllButton
                periodDescription
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var playAllButton: some View {
        Button {
            Task { await player.playAll(currentSongs) }
        } label: {
            Label("ui.common.play_all", systemImage: "play.fill")
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    private var periodDescription: some View {
        Text(selectedPeriod.description)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var contentInset: CGFloat {
        horizontalSizeClass == .regular ? 32 : 20
    }

    private func rowInsets(top: CGFloat, bottom: CGFloat) -> EdgeInsets {
        EdgeInsets(top: top, leading: contentInset, bottom: bottom, trailing: contentInset)
    }

    private var currentRecords: [UserPlayRecord] {
        recordsByPeriod[selectedPeriod] ?? []
    }

    private var currentSongs: [Song] {
        currentRecords.map(\.song)
    }

    private var currentPhase: LoadingPhase {
        phasesByPeriod[selectedPeriod] ?? .loading
    }

    private func load(
        period: UserPlayRecordPeriod,
        force: Bool = false
    ) async {
        if !force, recordsByPeriod[period] != nil {
            phasesByPeriod[period] = .loaded
            return
        }

        let hasCachedRecords = recordsByPeriod[period] != nil
        if !hasCachedRecords {
            phasesByPeriod[period] = .loading
        }

        do {
            let records = try await api.userPlayRecords(
                userID: userID,
                period: period
            )
            try Task.checkCancellation()
            recordsByPeriod[period] = records
            phasesByPeriod[period] = .loaded
        } catch is CancellationError {
            return
        } catch {
            if hasCachedRecords {
                phasesByPeriod[period] = .loaded
                refreshErrorMessage = error.localizedDescription
            } else {
                phasesByPeriod[period] = .failed(
                    error.localizedDescription
                )
            }
        }
    }
}

private extension UserPlayRecordPeriod {
    var title: String {
        switch self {
        case .week:
            L10n.string("ui.account.listening_rank.week")
        case .allTime:
            L10n.string("ui.account.listening_rank.all_time")
        }
    }

    var description: String {
        switch self {
        case .week:
            L10n.string("ui.account.listening_rank.week.detail")
        case .allTime:
            L10n.string("ui.account.listening_rank.all_time.detail")
        }
    }

    var emptyDescription: String {
        switch self {
        case .week:
            L10n.string("ui.account.listening_rank.week.empty")
        case .allTime:
            L10n.string("ui.account.listening_rank.all_time.empty")
        }
    }
}
