import SwiftUI

struct SongCommentsView: View {
    @Environment(NeteaseAPI.self) private var api

    let song: Song

    @State private var hotComments: [SongComment] = []
    @State private var comments: [SongComment] = []
    @State private var commentCount = 0
    @State private var phase: LoadingPhase = .loading
    @State private var hasMoreComments = false
    @State private var isLoadingMore = false
    @State private var paginationError: String?
    @State private var reloadToken = 0
    @State private var selectedParentComment: SongComment?

    var body: some View {
        List {
            songSummary

            if !hotComments.isEmpty {
                Section("热门评论") {
                    ForEach(hotComments) { comment in
                        commentRow(comment)
                    }
                }
            }

            latestCommentsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("评论")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadComments()
        }
        .task(id: reloadToken) {
            await loadComments()
        }
        .sheet(item: $selectedParentComment) { comment in
            SongCommentRepliesSheet(songID: song.id, parentComment: comment)
        }
    }

    private var songSummary: some View {
        Section {
            HStack(spacing: 12) {
                ArtworkImage(url: song.album?.artworkURL, cornerRadius: 8)
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(song.artistText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var latestCommentsSection: some View {
        Section {
            switch phase {
            case .loading where comments.isEmpty:
                HStack {
                    Spacer()
                    ProgressView("正在载入评论")
                    Spacer()
                }
            case .failed(let message) where comments.isEmpty:
                VStack(spacing: 12) {
                    Label("评论加载失败", systemImage: "exclamationmark.bubble")
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
                if comments.isEmpty {
                    ContentUnavailableView("暂无评论", systemImage: "bubble.left")
                } else {
                    ForEach(comments) { comment in
                        commentRow(comment)
                    }
                }
            }

            if hasMoreComments || paginationError != nil {
                loadMoreRow
            }
        } header: {
            Text(commentCount > 0 ? "最新评论 · \(commentCount.formatted())" : "最新评论")
        }
    }

    @ViewBuilder
    private func commentRow(_ comment: SongComment) -> some View {
        if comment.replyCount > 0 {
            Button {
                selectedParentComment = comment
            } label: {
                SongCommentRow(comment: comment)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开该评论的 \(comment.replyCount.formatted()) 条回复")
        } else {
            SongCommentRow(comment: comment)
        }
    }

    private var loadMoreRow: some View {
        Group {
            if let paginationError {
                Button {
                    Task { await loadMoreComments() }
                } label: {
                    VStack(spacing: 4) {
                        Text("重新载入更多评论")
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
                    ProgressView("载入更多评论")
                    Spacer()
                }
                .task {
                    await loadMoreComments()
                }
            }
        }
    }

    private func loadComments() async {
        phase = .loading
        paginationError = nil

        do {
            let response = try await api.songComments(id: song.id)
            try Task.checkCancellation()
            hotComments = response.hotComments
            comments = response.comments
            commentCount = response.total
            hasMoreComments = response.more && !response.comments.isEmpty
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadMoreComments() async {
        guard hasMoreComments, !isLoadingMore else { return }
        isLoadingMore = true
        paginationError = nil
        defer { isLoadingMore = false }

        do {
            let beforeTime = comments.count >= 5_000
                ? Int64(comments.last?.time ?? 0)
                : 0
            let response = try await api.songComments(
                id: song.id,
                offset: comments.count,
                beforeTime: beforeTime
            )
            try Task.checkCancellation()
            let loadedIDs = Set(comments.map(\.id))
            let newComments = response.comments.filter { !loadedIDs.contains($0.id) }
            comments.append(contentsOf: newComments)
            commentCount = response.total
            hasMoreComments = response.more && !newComments.isEmpty
        } catch is CancellationError {
            return
        } catch {
            paginationError = error.localizedDescription
        }
    }
}

struct SongCommentsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let song: Song

    var body: some View {
        NavigationStack {
            SongCommentsView(song: song)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("关闭评论")
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}
