import SwiftUI

struct MusicCollectionPaginationFooter: View {
    let isLoading: Bool
    let failureMessage: String?
    let loadToken: Int
    let action: () async -> Void

    var body: some View {
        Group {
            if let failureMessage {
                VStack(spacing: 8) {
                    Text(failureMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("重新加载") {
                        Task {
                            await action()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在加载更多歌曲")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .task(id: loadToken) {
                    guard !isLoading else { return }
                    await action()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}
