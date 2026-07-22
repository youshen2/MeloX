import SwiftUI

struct SongCommentRepliesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let songID: Int
    let parentComment: SongComment

    var body: some View {
        NavigationStack {
            SongCommentRepliesView(songID: songID, parentComment: parentComment)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("关闭回复")
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}

struct SongCommentRepliesView: View {
    @Environment(NeteaseAPI.self) private var api

    let songID: Int
    let parentComment: SongComment

    @State private var ownerComment: SongComment?
    @State private var replies: [SongComment] = []
    @State private var totalCount = 0
    @State private var phase: LoadingPhase = .loading
    @State private var hasMore = false
    @State private var isLoadingMore = false
    @State private var paginationError: String?
    @State private var reloadToken = 0

    var body: some View {
        List {
            Section("原评论") {
                SongCommentRow(comment: ownerComment ?? parentComment)
            }

            Section {
                repliesContent

                if hasMore || paginationError != nil {
                    loadMoreRow
                }
            } header: {
                Text(totalCount > 0 ? "全部回复 · \(totalCount.formatted())" : "全部回复")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("评论回复")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadReplies()
        }
        .task(id: reloadToken) {
            await loadReplies()
        }
    }

    @ViewBuilder
    private var repliesContent: some View {
        switch phase {
        case .loading where replies.isEmpty:
            HStack {
                Spacer()
                ProgressView("正在载入回复")
                Spacer()
            }
        case .failed(let message) where replies.isEmpty:
            VStack(spacing: 12) {
                Label("回复加载失败", systemImage: "exclamationmark.bubble")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    reloadToken += 1
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        default:
            if replies.isEmpty {
                ContentUnavailableView("暂无回复", systemImage: "bubble.left")
            } else {
                ForEach(replies) { reply in
                    SongCommentRow(comment: reply)
                }
            }
        }
    }

    private var loadMoreRow: some View {
        Group {
            if let paginationError {
                Button {
                    Task { await loadMoreReplies() }
                } label: {
                    VStack(spacing: 4) {
                        Text("重新载入更多回复")
                        Text(paginationError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView("载入更多回复")
                    Spacer()
                }
                .task {
                    await loadMoreReplies()
                }
            }
        }
    }

    private func loadReplies() async {
        phase = .loading
        paginationError = nil

        do {
            let response = try await api.songCommentReplies(
                songID: songID,
                parentCommentID: parentComment.id
            )
            try Task.checkCancellation()
            ownerComment = response.data.ownerComment
            replies = response.data.comments
            totalCount = response.data.totalCount
            hasMore = response.data.hasMore && !response.data.comments.isEmpty
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadMoreReplies() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        paginationError = nil
        defer { isLoadingMore = false }

        do {
            let response = try await api.songCommentReplies(
                songID: songID,
                parentCommentID: parentComment.id,
                time: Int64(replies.last?.time ?? -1)
            )
            try Task.checkCancellation()
            let loadedIDs = Set(replies.map(\.id))
            let newReplies = response.data.comments.filter { !loadedIDs.contains($0.id) }
            replies.append(contentsOf: newReplies)
            totalCount = response.data.totalCount
            hasMore = response.data.hasMore && !newReplies.isEmpty
        } catch is CancellationError {
            return
        } catch {
            paginationError = error.localizedDescription
        }
    }
}
