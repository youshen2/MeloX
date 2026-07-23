import SwiftUI

struct ArtworkImage: View {
    let url: URL?
    var cornerRadius: CGFloat = 10
    var aspectRatio: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(
                url: url,
                transaction: Transaction(animation: imageLoadAnimation)
            ) { phase in
                content(for: phase)
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    }

    private var imageLoadAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeOut(duration: 0.18)
    }

    @ViewBuilder
    private func content(for phase: AsyncImagePhase) -> some View {
        switch phase {
        case .empty:
            ZStack {
                Color.secondary.opacity(0.12)
                ProgressView()
            }
        case .success(let image):
            image
                .resizable()
                .scaledToFill()
                .transition(.opacity)
        case .failure:
            placeholder
        @unknown default:
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
