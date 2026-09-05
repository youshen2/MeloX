import SwiftUI

struct DesktopCollectionPaginationFooter: View {
    let isLoading: Bool
    let failureMessage: String?
    var loadToken: Int? = nil
    var loadingTitle = L10n.string("ui.common.loading_more_songs")
    let action: () async -> Void

    @State private var lastAutoLoadToken: Int?

    var body: some View {
        Group {
            if let failureMessage {
                VStack(spacing: 8) {
                    Text(failureMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("ui.common.retry") {
                        Task {
                            await action()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(loadingTitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("ui.common.loading_more", systemImage: "arrow.down.circle") {
                    Task {
                        await action()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .onAppear {
            triggerAutoLoad(for: loadToken)
        }
        .onChange(of: loadToken) { _, newToken in
            triggerAutoLoad(for: newToken)
        }
    }

    private func triggerAutoLoad(for token: Int?) {
        guard let token,
              lastAutoLoadToken != token,
              !isLoading,
              failureMessage == nil else { return }
        lastAutoLoadToken = token
        Task { await action() }
    }
}
