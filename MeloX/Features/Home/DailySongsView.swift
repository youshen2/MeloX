import SwiftUI

struct DailySongsView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library

    @State private var songs: [Song] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var isRefreshing = false
    @State private var refreshErrorMessage: String?

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView("ui.home.daily_songs.loading")
            case .failed(let message):
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            case .loaded:
                List {
                    Section {
                        HStack {
                            Button {
                                Task { await player.playAll(songs) }
                            } label: {
                                Label("ui.common.play_all", systemImage: "play.fill")
                                    .font(.headline)
                            }
                            .buttonStyle(.plain)
                            .disabled(songs.isEmpty)

                            Spacer()

                            Button {
                                Task { await refresh() }
                            } label: {
                                HStack(spacing: 6) {
                                    if isRefreshing {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                    }

                                    Text(
                                        isRefreshing
                                            ? L10n.string("ui.home.daily_songs.refreshing")
                                            : L10n.string("ui.home.daily_songs.refresh")
                                    )
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRefreshing)
                            .accessibilityLabel(
                                isRefreshing
                                    ? L10n.string("ui.home.daily_songs.refreshing_accessibility")
                                    : L10n.string("ui.home.daily_songs.refresh_accessibility")
                            )
                            .accessibilityHint("ui.home.daily_songs.refresh_hint")
                        }
                    }
                    ForEach(songs) { song in
                        Button {
                            Task { await player.play(song, in: songs) }
                        } label: {
                            TrackRowView(song: song, showsArtwork: true)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button {
                                library.toggle(song: song)
                            } label: {
                                Label(
                                    library.contains(song: song)
                                        ? L10n.string("ui.common.unfavorite")
                                        : L10n.string("ui.common.favorite"),
                                    systemImage: library.contains(song: song) ? "heart.slash" : "heart"
                                )
                            }
                            .tint(.pink)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("ui.home.action.daily_songs")
        .task(id: reloadToken) {
            guard phase != .loaded else { return }
            await load()
        }
        .alert(
            "ui.home.daily_songs.refresh_failed",
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

    private func load() async {
        phase = .loading
        do {
            songs = try await api.dailySongs()
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let refreshedSongs = try await api.dailySongs(afresh: true)
            try Task.checkCancellation()
            songs = refreshedSongs
        } catch is CancellationError {
            return
        } catch {
            refreshErrorMessage = error.localizedDescription
        }
    }
}
