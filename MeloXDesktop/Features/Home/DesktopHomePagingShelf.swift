import SwiftUI

/// A native horizontal shelf that advances by the items currently visible in
/// its viewport. The cards remain one real scrollable sequence; the button is
/// only a paging affordance for that sequence.
struct DesktopHomePagingShelf<Item: Identifiable, Card: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct ScrollState: Equatable {
        let leadingIndex: Int
        let visibleItemCount: Int
        let canRetreat: Bool
        let canAdvance: Bool
    }

    let items: [Item]
    let cardWidth: CGFloat
    let spacing: CGFloat
    let visibleItemCount: Int
    private let card: (Item) -> Card

    @State private var leadingIndex = 0
    @State private var isShelfHovered = false
    @State private var scrollState: ScrollState?

    init(
        items: [Item],
        cardWidth: CGFloat,
        spacing: CGFloat,
        visibleItemCount: Int,
        @ViewBuilder card: @escaping (Item) -> Card
    ) {
        self.items = items
        self.cardWidth = cardWidth
        self.spacing = spacing
        self.visibleItemCount = visibleItemCount
        self.card = card
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: spacing) {
                        ForEach(items) { item in
                            card(item)
                                .frame(width: cardWidth)
                                .clipped()
                                .id(item.id)
                        }
                    }
                }
                .clipped()
                .onScrollGeometryChange(for: ScrollState.self) { geometry in
                    scrollState(for: geometry)
                } action: { _, newState in
                    scrollState = newState
                    leadingIndex = newState.leadingIndex
                }
                .onChange(of: items.map(\.id), initial: true) { _, _ in
                    let clampedIndex = min(leadingIndex, lastPageStart)
                    guard clampedIndex != leadingIndex else { return }
                    leadingIndex = clampedIndex
                }

                HStack(spacing: 0) {
                    pageButton(
                        systemImage: "chevron.left",
                        title: L10n.string("ui.desktop.pagination.previous"),
                        isAvailable: canRetreat
                    ) {
                        page(-1, proxy: proxy)
                    }
                    .padding(.leading, 8)

                    Spacer(minLength: 0)

                    pageButton(
                        systemImage: "chevron.right",
                        title: L10n.string("ui.desktop.pagination.next"),
                        isAvailable: canAdvance
                    ) {
                        page(1, proxy: proxy)
                    }
                    .padding(.trailing, 8)
                }
            }
            .contentShape(.rect)
            .onHover { isShelfHovered = $0 }
        }
    }

    private func pageButton(
        systemImage: String,
        title: String,
        isAvailable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isVisible = isShelfHovered && isAvailable

        return Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 44)
                .background(.regularMaterial, in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.34), lineWidth: 0.7)
                }
                .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .disabled(!isAvailable)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isAvailable)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: isVisible
        )
    }

    private var canAdvance: Bool {
        scrollState?.canAdvance ?? (leadingIndex < lastPageStart)
    }

    private var canRetreat: Bool {
        scrollState?.canRetreat ?? (leadingIndex > 0)
    }

    private var pageSize: Int {
        max(scrollState?.visibleItemCount ?? visibleItemCount, 1)
    }

    private var lastPageStart: Int {
        max(items.count - pageSize, 0)
    }

    private func scrollState(for geometry: ScrollGeometry) -> ScrollState {
        let containerWidth = max(geometry.containerSize.width, 0)
        let viewportWidth = containerWidth
        let maximumOffset = max(
            geometry.contentSize.width - containerWidth,
            0
        )
        let offset = min(
            max(geometry.contentOffset.x, 0),
            maximumOffset
        )
        let itemStride = cardWidth + spacing
        let actualVisibleItemCount = itemStride > 0
            ? max(Int((viewportWidth + spacing) / itemStride), 1)
            : 1
        let actualLeadingIndex = if !items.isEmpty, itemStride > 0 {
            min(
                max(Int((offset / itemStride).rounded()), 0),
                items.count - 1
            )
        } else {
            0
        }
        let edgeTolerance: CGFloat = 1

        return ScrollState(
            leadingIndex: actualLeadingIndex,
            visibleItemCount: actualVisibleItemCount,
            canRetreat: offset > edgeTolerance,
            canAdvance: offset < maximumOffset - edgeTolerance
        )
    }

    private func page(_ direction: Int, proxy: ScrollViewProxy) {
        guard !items.isEmpty else { return }

        let targetIndex: Int
        if direction < 0 {
            targetIndex = max(
                ((max(leadingIndex - 1, 0)) / pageSize) * pageSize,
                0
            )
        } else {
            targetIndex = min(
                ((leadingIndex / pageSize) + 1) * pageSize,
                lastPageStart
            )
        }

        withAnimation(
            reduceMotion
                ? nil
                : DesktopMainWindowMetrics.presentationAnimation
        ) {
            leadingIndex = targetIndex
            proxy.scrollTo(items[targetIndex].id, anchor: .leading)
        }
    }
}
