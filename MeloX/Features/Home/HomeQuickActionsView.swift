import SwiftUI

enum HomeQuickAction: String, CaseIterable, Identifiable {
    case dailySongs
    case hotSongs
    case heartMode
    case privateRadar
    case privateRoaming
    case similarSongs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailySongs:
            L10n.string("ui.home.action.daily_songs")
        case .hotSongs:
            L10n.string("ui.home.action.hot_songs")
        case .heartMode:
            L10n.string("ui.home.action.heart_mode")
        case .privateRadar:
            L10n.string("ui.home.action.private_radar")
        case .privateRoaming:
            L10n.string("ui.home.action.private_roaming")
        case .similarSongs:
            L10n.string("ui.home.action.similar_songs")
        }
    }

    var systemImage: String {
        switch self {
        case .dailySongs:
            "calendar"
        case .hotSongs:
            "flame.fill"
        case .heartMode:
            "heart.fill"
        case .privateRadar:
            "dot.radiowaves.left.and.right"
        case .privateRoaming:
            "figure.walk.motion"
        case .similarSongs:
            "music.note.list"
        }
    }

    var eyebrow: String {
        switch self {
        case .dailySongs:
            L10n.string("ui.home.action.daily_songs.eyebrow")
        case .hotSongs:
            L10n.string("ui.home.action.hot_songs.eyebrow")
        case .heartMode:
            L10n.string("ui.home.action.heart_mode.eyebrow")
        case .privateRadar:
            L10n.string("ui.home.action.private_radar.eyebrow")
        case .privateRoaming:
            L10n.string("ui.home.action.private_roaming.eyebrow")
        case .similarSongs:
            L10n.string("ui.home.action.similar_songs.eyebrow")
        }
    }

    var subtitle: String {
        switch self {
        case .dailySongs:
            L10n.string("ui.home.action.daily_songs.subtitle")
        case .hotSongs:
            L10n.string("ui.home.action.hot_songs.subtitle")
        case .heartMode:
            L10n.string("ui.home.action.heart_mode.subtitle")
        case .privateRadar:
            L10n.string("ui.home.action.private_radar.subtitle")
        case .privateRoaming:
            L10n.string("ui.home.action.private_roaming.subtitle")
        case .similarSongs:
            L10n.string("ui.home.action.similar_songs.subtitle")
        }
    }

    var colors: [Color] {
        switch self {
        case .dailySongs:
            [.pink, .red]
        case .hotSongs:
            [.orange, .red]
        case .heartMode:
            [.pink, .purple]
        case .privateRadar:
            [.indigo, .purple]
        case .privateRoaming:
            [.cyan, .blue]
        case .similarSongs:
            [.mint, .teal]
        }
    }
}

struct HomeQuickActionsView: View {
    let activeAction: HomeQuickAction?
    let perform: (HomeQuickAction) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(HomeQuickAction.allCases) { action in
                    Button {
                        perform(action)
                    } label: {
                        HomeEditorialCard(
                            eyebrow: action.eyebrow,
                            title: action.title,
                            subtitle: action.subtitle,
                            systemImage: action.systemImage,
                            colors: action.colors
                        )
                        .overlay {
                            if activeAction == action {
                                ProgressView()
                                    .controlSize(.large)
                                    .padding(22)
                                    .background(.regularMaterial)
                                    .clipShape(.circle)
                            }
                        }
                    }
                    .containerRelativeFrame(.horizontal) {
                        length, _ in
                        min(length * 0.86, 340)
                    }
                    .buttonStyle(.plain)
                    .disabled(activeAction != nil)
                    .accessibilityHint(accessibilityHint(for: action))
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
    }

    private func accessibilityHint(
        for action: HomeQuickAction
    ) -> String {
        switch action {
        case .dailySongs, .hotSongs, .privateRadar:
            L10n.format("ui.home.action.open_hint", action.title)
        case .heartMode, .privateRoaming, .similarSongs:
            L10n.format("ui.home.action.play_hint", action.title)
        }
    }
}
