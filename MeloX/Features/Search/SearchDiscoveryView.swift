import SwiftUI
import UIKit

struct SearchDiscoveryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(NeteaseAPI.self) private var api
    @Environment(AppSettings.self) private var settings

    @State private var recommendations: [Playlist] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.adaptive(minimum: 270), spacing: 12)]
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [GridItem(.adaptive(minimum: 160), spacing: 12)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                recommendationSection

                VStack(alignment: .leading, spacing: 14) {
                    Text("ui.search.browse_categories")
                        .font(.title2.bold())

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visibleCategories) { category in
                            NavigationLink(value: category.route) {
                                SearchCategoryCard(category: category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            await loadRecommendations()
        }
        .task(id: reloadToken) {
            guard recommendations.isEmpty else { return }
            await loadRecommendations()
        }
    }

    private var visibleCategories: [SearchMusicCategory] {
        SearchMusicCategory.all.filter { category in
            guard let feature = category.requiredContentFeature else {
                return true
            }
            return settings.isContentFeatureEnabled(feature)
        }
    }

    @ViewBuilder
    private var recommendationSection: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("ui.search.popular_recommendations")
                    .font(.title2.bold())
                    .padding(.horizontal)

                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(recommendations) { playlist in
                            NavigationLink(value: MusicRoute.playlist(playlist)) {
                                MediaCardView(
                                    title: playlist.name,
                                    subtitle: playlist.copywriter ?? playlist.creator?.nickname,
                                    artworkURL: playlist.artworkURL,
                                    artworkSize: 172
                                )
                                .frame(width: 172)
                            }
                            .buttonStyle(.plain)
                            .musicMatchedTransitionSource(for: MusicRoute.playlist(playlist))
                        }
                    }
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollIndicators(.hidden)
            }
        } else if phase == .loading {
            HStack {
                Spacer()
                ProgressView("ui.search.loading_recommendations")
                Spacer()
            }
            .padding(.vertical, 24)
        } else if case .failed(let message) = phase {
            ContentUnavailableView {
                Label("ui.search.recommendations_failed", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("ui.common.retry") {
                    reloadToken += 1
                }
            }
        }
    }

    private func loadRecommendations() async {
        phase = .loading
        do {
            recommendations = try await api.recommendedPlaylists(limit: 10)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

private struct SearchCategoryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let category: SearchMusicCategory

    var body: some View {
        Text(category.localizedName)
            .font(.title3.bold())
            .foregroundStyle(.white)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .bottomLeading)
            .background {
                LinearGradient(
                    colors: category.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: category.systemImage)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(.white.opacity(0.22))
                        .rotationEffect(.degrees(-8))
                        .padding(14)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
    }
}

private struct SearchMusicCategory: Identifiable {
    let requestName: String
    let localizationKey: String
    let systemImage: String
    let colors: [Color]

    var id: String { requestName }

    var localizedName: String {
        L10n.string(localizationKey)
    }

    var requiredContentFeature: ContentFeature? {
        localizationKey == "ui.navigation.podcasts" ? .podcasts : nil
    }

    var route: MusicRoute {
        switch requestName {
        case "排行榜":
            .toplists
        case "播客":
            .podcasts
        default:
            .playlistCategory(requestName)
        }
    }

    static let all: [SearchMusicCategory] = [
        .init(requestName: "排行榜", localizationKey: "ui.category.toplists", systemImage: "chart.bar.fill", colors: [.orange, .red]),
        .init(requestName: "播客", localizationKey: "ui.navigation.podcasts", systemImage: "mic.fill", colors: [.purple, .indigo]),
        .init(requestName: "华语", localizationKey: "ui.category.chinese", systemImage: "character.book.closed.fill", colors: [.pink, .red]),
        .init(requestName: "欧美", localizationKey: "ui.category.europe_america", systemImage: "globe.americas.fill", colors: [.blue, .indigo]),
        .init(requestName: "日语", localizationKey: "ui.category.japanese", systemImage: "sun.max.fill", colors: [.orange, .pink]),
        .init(requestName: "韩语", localizationKey: "ui.category.korean", systemImage: "sparkles", colors: [.purple, .pink]),
        .init(requestName: "粤语", localizationKey: "ui.category.cantonese", systemImage: "waveform", colors: [.teal, .blue]),
        .init(requestName: "流行", localizationKey: "ui.category.pop", systemImage: "music.mic", colors: [.pink, .purple]),
        .init(requestName: "摇滚", localizationKey: "ui.category.rock", systemImage: "guitars.fill", colors: [.red, .black]),
        .init(requestName: "民谣", localizationKey: "ui.category.folk", systemImage: "music.note", colors: [.brown, .orange]),
        .init(requestName: "电子", localizationKey: "ui.category.electronic", systemImage: "waveform.path.ecg", colors: [.cyan, .blue]),
        .init(requestName: "说唱", localizationKey: "ui.category.hip_hop", systemImage: "mic.fill", colors: [.indigo, .black]),
        .init(requestName: "R&B/Soul", localizationKey: "ui.category.rnb_soul", systemImage: "heart.fill", colors: [.purple, .indigo]),
        .init(requestName: "古典", localizationKey: "ui.category.classical", systemImage: "pianokeys", colors: [.mint, .green]),
        .init(requestName: "ACG", localizationKey: "ui.category.acg", systemImage: "gamecontroller.fill", colors: [.pink, .blue]),
        .init(requestName: "影视原声", localizationKey: "ui.category.soundtrack", systemImage: "film.fill", colors: [.orange, .red]),
        .init(requestName: "学习", localizationKey: "ui.category.study", systemImage: "book.closed.fill", colors: [.green, .teal]),
        .init(requestName: "工作", localizationKey: "ui.category.work", systemImage: "laptopcomputer", colors: [.teal, .cyan]),
        .init(requestName: "放松", localizationKey: "ui.category.relax", systemImage: "leaf.fill", colors: [.mint, .blue]),
        .init(requestName: "夜晚", localizationKey: "ui.category.night", systemImage: "moon.stars.fill", colors: [.indigo, .purple]),
    ]
}
