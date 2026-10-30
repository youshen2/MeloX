import SwiftUI

struct NowPlayingTabletPageSwitcher: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player

    @Binding var page: NowPlayingPage
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 0) {
            if player.currentSong?.isPodcastProgram != true {
                switchButton(.lyrics, systemImage: "quote.bubble", title: "ui.settings.lyrics.title")
            }

            switchButton(.queue, systemImage: "list.bullet", title: "ui.player.queue")
        }
        .padding(4)
        .glassEffect(.clear.interactive(), in: .capsule)
    }

    private func switchButton(
        _ destination: NowPlayingPage,
        systemImage: String,
        title: LocalizedStringKey
    ) -> some View {
        let isSelected = page == destination

        return Button {
            select(destination)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? .black.opacity(0.78) : .white)
                .frame(width: 44, height: 44)
                .background {
                    if isSelected {
                        Circle()
                            .fill(.white.opacity(0.88))
                            .frame(width: 36, height: 36)
                            .matchedGeometryEffect(id: "selected-page", in: selectionNamespace)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(
            isSelected
                ? L10n.string("ui.common.selected")
                : L10n.string("ui.common.not_selected")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ destination: NowPlayingPage) {
        let target = page == destination ? .artwork : destination
        withAnimation(
            accessibilityReduceMotion
                ? nil
                : NowPlayingPageTransition.selectionAnimation(from: page, to: target)
        ) {
            page = target
        }
    }
}
