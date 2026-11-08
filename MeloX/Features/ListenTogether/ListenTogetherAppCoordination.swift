import SwiftUI

struct ListenTogetherAppCoordinationModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player
    @Environment(ListenTogetherStore.self) private var listenTogether

    func body(content: Content) -> some View {
        content
            .task(id: settings.cookie) {
                await listenTogether.accountDidChange(
                    hasCredentials: hasCredentials
                )
            }
            .onChange(of: player.currentSong?.id) {
                previousSongID,
                currentSongID in
                listenTogether.playerSongDidChange(
                    from: previousSongID,
                    to: currentSongID
                )
            }
            .onChange(of: player.isPlaying) { _, isPlaying in
                listenTogether.playerPlaybackDidChange(
                    isPlaying: isPlaying
                )
            }
            .onChange(of: player.seekRevision) {
                listenTogether.playerDidSeek()
            }
            .onChange(of: player.queue.map(\.id)) {
                listenTogether.playerQueueDidChange()
            }
            // Local shuffle is not a playlist change. The next track is
            // reported when currentSong changes.
            .alert(
                "ui.listen_together.title",
                isPresented: noticePresented
            ) {
                Button("ui.common.ok", role: .cancel) {
                    listenTogether.dismissNotice()
                }
            } message: {
                Text(
                    listenTogether.noticeMessage
                        ?? L10n.string("ui.listen_together.status_updated")
                )
            }
    }

    private var hasCredentials: Bool {
        !settings.cookie
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private var noticePresented: Binding<Bool> {
        Binding(
            get: { listenTogether.noticeMessage != nil },
            set: { isPresented in
                if !isPresented {
                    listenTogether.dismissNotice()
                }
            }
        )
    }
}

extension View {
    func coordinateListenTogether() -> some View {
        modifier(ListenTogetherAppCoordinationModifier())
    }
}
