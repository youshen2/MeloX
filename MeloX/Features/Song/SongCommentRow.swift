import SwiftUI

struct SongCommentRow: View {
    let comment: SongComment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ArtworkImage(url: comment.user.artworkURL, cornerRadius: 1_000)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 8) {
                Text(comment.user.nickname)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(comment.content)
                    .font(.body)
                    .textSelection(.enabled)

                ForEach(Array(comment.replies.prefix(2).enumerated()), id: \.offset) { _, reply in
                    Text(replyText(reply))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.secondary.opacity(0.1), in: .rect(cornerRadius: 8))
                }

                HStack(spacing: 10) {
                    Text(commentDateText)

                    if let location = comment.ipLocation?.location, !location.isEmpty {
                        Text("IP 属地：\(location)")
                    }

                    Spacer(minLength: 8)

                    if comment.likedCount > 0 {
                        Label(
                            comment.likedCount.formatted(),
                            systemImage: comment.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(comment.user.nickname)：\(comment.content)")
    }

    private var commentDateText: String {
        if let description = comment.timeDescription, !description.isEmpty {
            return description
        }
        guard let time = comment.time else { return "" }
        return Date(timeIntervalSince1970: time / 1_000).formatted(
            .dateTime.year().month().day()
        )
    }

    private func replyText(_ reply: SongCommentReply) -> String {
        guard let nickname = reply.user?.nickname, !nickname.isEmpty else {
            return reply.content
        }
        return "@\(nickname)：\(reply.content)"
    }
}
