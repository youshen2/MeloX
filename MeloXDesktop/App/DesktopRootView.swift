import SwiftUI

struct DesktopRootView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isNowPlayingLayerMounted = false
    @State private var isNowPlayingRenderingActive = false

    var body: some View {
        @Bindable var ui = model.ui

        ZStack {
            DesktopSidebar()

            GeometryReader { proxy in
                if ui.isNowPlayingPresented
                    || isNowPlayingLayerMounted {
                    nowPlayingLayer(
                        isPresented: ui.isNowPlayingPresented,
                        isRenderingActive: isNowPlayingRenderingActive
                    )
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
                    .offset(
                        y: ui.isNowPlayingPresented
                            ? 0
                            : proxy.size.height
                    )
                    .allowsHitTesting(ui.isNowPlayingPresented)
                    .accessibilityHidden(!ui.isNowPlayingPresented)
                    .transition(.move(edge: .bottom))
                }
            }
            .zIndex(1)
            .animation(
                reduceMotion
                    ? nil
                    : DesktopPlayerMotion.nowPlayingPresentation,
                value: ui.isNowPlayingPresented
            )
        }
        .toolbar(removing: .sidebarToggle)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .background {
            ZStack {
                DesktopMainWindowConfiguration(
                    isPlayerSidePanelPresented: ui.inspector != nil
                )

                DesktopNowPlayingLeadingAccessoryInstaller(
                    isPresented: ui.isNowPlayingPresented,
                    close: {
                        model.ui.isNowPlayingPresented = false
                    },
                    openMiniPlayer: {
                        model.ui.isNowPlayingPresented = false
                        Task { @MainActor in
                            await Task.yield()
                            openWindow(id: "mini-player")
                            await DesktopMiniPlayerWindowCoordinator
                                .bringToFrontAfterOpening()
                        }
                    }
                )

                DesktopNowPlayingTrailingAccessoryInstaller(
                    isPresented: ui.isNowPlayingPresented
                        && model.playbackVolume.isControlVisible,
                    model: model
                )
            }
            .allowsHitTesting(false)
        }
        .containerBackground(for: .window) {
            Color(nsColor: .windowBackgroundColor)
        }
        .tint(.red)
        .desktopLaunchExperience()
        .task { await model.bootstrap() }
        .task(id: ui.isNowPlayingPresented) {
            await updateNowPlayingLifecycle(
                isPresented: ui.isNowPlayingPresented
            )
        }
        .task(id: model.player.currentSong?.id) {
            await model.synchronizeLyrics()
        }
        .onChange(of: model.settings.lyricsSourcePreference) { _, _ in
            Task { await model.synchronizeLyrics() }
        }
        .sheet(item: $ui.sheet) { sheet in
            DesktopSheetView(sheet: sheet)
                .environment(model)
        }
        .alert(
            L10n.string("ui.error.operation_failed.title"),
            isPresented: Binding(
                get: { model.library.operationErrorMessage != nil },
                set: {
                    if !$0 {
                        model.library.clearOperationError()
                    }
                }
            )
        ) {
            Button("ui.common.ok") { model.library.clearOperationError() }
        } message: {
            Text(
                model.library.operationErrorMessage
                    ?? L10n.string("ui.error.netease_operation_incomplete")
            )
        }
        .alert(
            L10n.string("ui.error.heart_mode_launch.title"),
            isPresented: Binding(
                get: { model.launchErrorMessage != nil },
                set: { if !$0 { model.clearLaunchError() } }
            )
        ) {
            Button("ui.common.ok") { model.clearLaunchError() }
        } message: {
            Text(model.launchErrorMessage ?? L10n.string("ui.error.try_again_later"))
        }
        .onExitCommand {
            if ui.isNowPlayingPresented {
                ui.isNowPlayingPresented = false
            }
        }
    }

    private func nowPlayingLayer(
        isPresented: Bool,
        isRenderingActive: Bool
    ) -> some View {
        ZStack {
            DesktopNowPlayingBackdrop(
                artworkURL: model.player.currentSong?.album?.artworkURL,
                player: model.player,
                settings: model.settings,
                isActive: isRenderingActive
            )
            .ignoresSafeArea()

            DesktopNowPlayingWindow(
                isActive: isPresented,
                isRenderingActive: isRenderingActive
            )
        }
        // The backdrop is a sibling of the white player content, so both
        // must inherit the player's dark appearance from their common root.
        .environment(\.colorScheme, .dark)
    }

    private func updateNowPlayingLifecycle(
        isPresented: Bool
    ) async {
        if isPresented {
            commitNowPlayingLayerMounted(true)
            guard await waitForNowPlayingTransition() else { return }
            guard model.ui.isNowPlayingPresented else { return }
            commitNowPlayingRenderingActivity(true)
            return
        }

        // Stop display-linked and geometry-driven work before the page starts
        // moving. The mounted layer stays around only to draw the exit frame.
        commitNowPlayingRenderingActivity(false)
        guard isNowPlayingLayerMounted else { return }
        guard await waitForNowPlayingTransition() else { return }
        guard !model.ui.isNowPlayingPresented else { return }
        commitNowPlayingLayerMounted(false)
    }

    private func waitForNowPlayingTransition() async -> Bool {
        if reduceMotion {
            await Task.yield()
        } else {
            do {
                try await Task.sleep(
                    for: DesktopPlayerMotion.nowPlayingContentDelay
                )
            } catch {
                return false
            }
        }
        return !Task.isCancelled
    }

    private func commitNowPlayingLayerMounted(_ isMounted: Bool) {
        guard isNowPlayingLayerMounted != isMounted else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isNowPlayingLayerMounted = isMounted
        }
    }

    private func commitNowPlayingRenderingActivity(_ isActive: Bool) {
        guard isNowPlayingRenderingActive != isActive else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isNowPlayingRenderingActive = isActive
        }
    }
}

struct DesktopTabPage: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let section: DesktopSection

    var body: some View {
        @Bindable var ui = model.ui
        let isInspectorPresented = ui.inspector != nil

        let pageContent = NavigationStack(path: $ui.path) {
            DesktopSectionContentView(section: section)
                .navigationDestination(for: DesktopRoute.self) { route in
                    DesktopRouteView(route: route)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(removing: .sidebarToggle)
        .onPreferenceChange(
            DesktopLoadingStatusPreferenceKey.self
        ) { message in
            model.ui.setContextualLoadingMessage(message, for: section)
        }

        ZStack(alignment: .trailing) {
            pageContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    DesktopTabBottomPlayerInset()
                }

            DesktopPlayerSidePanel(
                selection: ui.retainedInspector,
                isPresented: isInspectorPresented
            )
            .frame(
                width: DesktopMainWindowMetrics.playerSidePanelWidth
            )
            .offset(
                x: isInspectorPresented
                    ? 0
                    : DesktopMainWindowMetrics.playerSidePanelWidth
            )
            .opacity(isInspectorPresented ? 1 : 0)
            .allowsHitTesting(isInspectorPresented)
            .accessibilityHidden(!isInspectorPresented)
            .zIndex(2)
            .animation(
                reduceMotion
                    ? nil
                    : DesktopMainWindowMetrics.presentationAnimation,
                value: isInspectorPresented
            )

            if section == ui.selection {
                DesktopTabBottomPlayer()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottom
                    )
                    .zIndex(3)
            }
        }
    }
}

private struct DesktopSheetView: View {
    let sheet: DesktopSheet

    var body: some View {
        switch sheet {
        case .onboarding:
            DesktopOnboardingDialog()
        case .account:
            DesktopAccountView()
        case .login:
            DesktopLoginView()
        case .recognition:
            DesktopSongRecognitionView()
        case .listenTogether:
            DesktopListenTogetherView()
        case .listenTogetherInvitation(let invitation):
            DesktopListenTogetherView(
                invitationText: invitation.invitationText
            )
        case .sleepTimer:
            DesktopSleepTimerView()
        case .beatNetDebug:
            DesktopBeatNetDebugView()
        }
    }
}

struct DesktopSectionContentView: View {
    let section: DesktopSection

    var body: some View {
        switch section {
        case .search:
            DesktopSearchView()
        case .home:
            DesktopHomeView()
        case .discovery:
            DesktopDiscoveryView()
        case .radio:
            DesktopRadioView()
        case .recent,
             .songs,
             .playlists,
             .albums,
             .podcasts,
             .downloads,
             .cloud:
            DesktopLibraryView(section: section)
        case .messages:
            DesktopMessagesView()
        }
    }
}
