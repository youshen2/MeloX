import SwiftUI

struct NowPlayingBackground: View {
    @Environment(AppSettings.self) private var settings

    let artworkURL: URL?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                AsyncImage(url: artworkURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .scaleEffect(1.35)
                            .blur(radius: CGFloat(settings.playerBackgroundBlur))
                            .saturation(settings.playerBackgroundSaturation)
                    }
                }

                Color.black.opacity(0.16)

                LinearGradient(
                    colors: [
                        .black.opacity(0.04),
                        .black.opacity(0.12),
                        .black.opacity(0.48),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
