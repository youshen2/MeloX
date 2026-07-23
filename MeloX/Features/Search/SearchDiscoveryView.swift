import SwiftUI

struct SearchDiscoveryView: View {
    @Environment(NeteaseAPI.self) private var api

    @State private var recommendations: [Playlist] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                recommendationSection

                VStack(alignment: .leading, spacing: 14) {
                    Text("浏览类别")
                        .font(.title2.bold())

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(SearchMusicCategory.all) { category in
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

    @ViewBuilder
    private var recommendationSection: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("热门推荐")
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
                ProgressView("正在载入推荐")
                Spacer()
            }
            .padding(.vertical, 24)
        } else if case .failed(let message) = phase {
            ContentUnavailableView {
                Label("推荐载入失败", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("重试") {
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
    let category: SearchMusicCategory

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: category.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: category.systemImage)
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(.white.opacity(0.22))
                .rotationEffect(.degrees(-8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(14)

            Text(category.name)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(14)
        }
        .aspectRatio(1.55, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

private struct SearchMusicCategory: Identifiable {
    let name: String
    let systemImage: String
    let colors: [Color]

    var id: String { name }

    var route: MusicRoute {
        name == "排行榜" ? .toplists : .playlistCategory(name)
    }

    static let all: [SearchMusicCategory] = [
        .init(name: "排行榜", systemImage: "chart.bar.fill", colors: [.orange, .red]),
        .init(name: "华语", systemImage: "character.book.closed.fill", colors: [.pink, .red]),
        .init(name: "欧美", systemImage: "globe.americas.fill", colors: [.blue, .indigo]),
        .init(name: "日语", systemImage: "sun.max.fill", colors: [.orange, .pink]),
        .init(name: "韩语", systemImage: "sparkles", colors: [.purple, .pink]),
        .init(name: "粤语", systemImage: "waveform", colors: [.teal, .blue]),
        .init(name: "流行", systemImage: "music.mic", colors: [.pink, .purple]),
        .init(name: "摇滚", systemImage: "guitars.fill", colors: [.red, .black]),
        .init(name: "民谣", systemImage: "music.note", colors: [.brown, .orange]),
        .init(name: "电子", systemImage: "waveform.path.ecg", colors: [.cyan, .blue]),
        .init(name: "说唱", systemImage: "mic.fill", colors: [.indigo, .black]),
        .init(name: "R&B/Soul", systemImage: "heart.fill", colors: [.purple, .indigo]),
        .init(name: "古典", systemImage: "pianokeys", colors: [.mint, .green]),
        .init(name: "ACG", systemImage: "gamecontroller.fill", colors: [.pink, .blue]),
        .init(name: "影视原声", systemImage: "film.fill", colors: [.orange, .red]),
        .init(name: "学习", systemImage: "book.closed.fill", colors: [.green, .teal]),
        .init(name: "工作", systemImage: "laptopcomputer", colors: [.teal, .cyan]),
        .init(name: "放松", systemImage: "leaf.fill", colors: [.mint, .blue]),
        .init(name: "夜晚", systemImage: "moon.stars.fill", colors: [.indigo, .purple]),
    ]
}
