import AppKit
import OSLog
import SwiftUI

private let appleMusicBackdropLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "MeloX",
    category: "AppleMusicBackdrop"
)

/// Identifies one cached artwork variant. Baking the blur into the artwork
/// keeps the 60Hz timeline free of the per-frame full-pass Gaussian blur.
private struct DesktopBackdropArtworkKey: Hashable {
    let url: URL?
    /// Blur baked into the cached artwork, in source pixels.
    let blurRadius: Double?
}

/// Owns artwork downloads independently of the 60Hz backdrop TimelineView.
/// A SwiftUI `.task(id:)` on a view inside that timeline can be cancelled by
/// high-frequency invalidation; the unstructured Task stored here keeps the
/// download alive until it finishes, and later view passes simply await the
/// same in-flight task.
@MainActor
private final class DesktopAppleMusicBackdropArtworkCache {
    static let shared = DesktopAppleMusicBackdropArtworkCache()

    private var images: [DesktopBackdropArtworkKey: NSImage] = [:]
    private var tasks:
        [DesktopBackdropArtworkKey: Task<NSImage?, Never>] = [:]

    func image(
        for sourceURL: URL,
        blurRadius: Double?
    ) async -> NSImage? {
        let key = DesktopBackdropArtworkKey(
            url: sourceURL,
            blurRadius: blurRadius
        )
        if let image = images[key] {
            return image
        }
        if let task = tasks[key] {
            return await task.value
        }

        let task = Task<NSImage?, Never> { [weak self] in
            let image = await Self.download(
                from: sourceURL,
                blurRadius: blurRadius
            )
            guard let self else { return image }
            if let image {
                self.images[key] = image
                while self.images.count > 8 {
                    self.images.remove(
                        at: self.images.startIndex
                    )
                }
            }
            return image
        }
        tasks[key] = task
        let image = await task.value
        tasks[key] = nil
        return image
    }

    @MainActor
    private static func download(
        from sourceURL: URL,
        blurRadius: Double?
    ) async -> NSImage? {
        let optimizedURL = optimizedArtworkURL(for: sourceURL)

        if let image = await downloadWithURLSession(from: optimizedURL) {
            return await baked(
                image,
                sourceURL: sourceURL,
                blurRadius: blurRadius
            )
        }

        // Some App Sandbox / cache configurations reject URLSession tasks
        // even with the network-client entitlement. Fall back to Foundation's
        // synchronous loader on a detached thread; a 300pt NetEase JPEG is
        // only tens of kilobytes.
        if let image = await downloadWithData(from: optimizedURL) {
            appleMusicBackdropLogger.warning(
                "Used Data(contentsOf:) fallback for \(sourceURL, privacy: .public)"
            )
            return await baked(
                image,
                sourceURL: sourceURL,
                blurRadius: blurRadius
            )
        }
        if optimizedURL != sourceURL,
           let image = await downloadWithData(from: sourceURL) {
            appleMusicBackdropLogger.warning(
                "Used original-URL Data fallback for \(sourceURL, privacy: .public)"
            )
            return await baked(
                image,
                sourceURL: sourceURL,
                blurRadius: blurRadius
            )
        }

        // ArtworkAccentColorProvider already downloads a 160pt copy for the
        // page palette. Its blurred backdrop keeps the background colorful
        // instead of falling back to #4D4D4D when both direct loads fail.
        let assets = await ArtworkAccentColorProvider.shared.detailAssets(
            for: sourceURL
        )
        if let blurred = assets.blurredBackdropImage {
            appleMusicBackdropLogger.warning(
                "Used palette blurred fallback for \(sourceURL, privacy: .public)"
            )
            return NSImage(
                cgImage: blurred,
                size: NSSize(
                    width: blurred.width,
                    height: blurred.height
                )
            )
        }

        appleMusicBackdropLogger.error(
            "All artwork load paths failed for \(sourceURL, privacy: .public)"
        )
        return nil
    }

    @MainActor
    private static func baked(
        _ image: NSImage,
        sourceURL: URL,
        blurRadius: Double?
    ) async -> NSImage {
        guard let blurRadius, blurRadius > 0 else {
            return image
        }
        return await DesktopArtworkBackdropRenderer.shared.bakedImage(
            from: image,
            sourceURL: sourceURL,
            blurRadius: blurRadius
        ) ?? image
    }

    @MainActor
    private static func downloadWithURLSession(
        from url: URL
    ) async -> NSImage? {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            // Artwork URLs are content-addressed per song/album, so normal
            // HTTP cache handling avoids re-downloading the same 300pt JPEG
            // on every backdrop remount.
            request.cachePolicy = .useProtocolCachePolicy
            request.setValue("MeloX/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(
                for: request
            )
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                appleMusicBackdropLogger.error(
                    "Artwork request failed with HTTP \(httpResponse.statusCode) for \(url, privacy: .public)"
                )
                return nil
            }
            guard let image = NSImage(data: data) else {
                appleMusicBackdropLogger.error(
                    "Artwork data could not be decoded for \(url, privacy: .public)"
                )
                return nil
            }
            return image
        } catch {
            appleMusicBackdropLogger.error(
                "URLSession artwork download failed for \(url, privacy: .public): \(error, privacy: .public)"
            )
            return nil
        }
    }

    @MainActor
    private static func downloadWithData(
        from url: URL
    ) async -> NSImage? {
        let data = await Task.detached(priority: .userInitiated) {
            () -> Data? in
            try? Data(contentsOf: url, options: [.mappedIfSafe])
        }.value
        guard let data else { return nil }
        return NSImage(data: data)
    }

    nonisolated private static func optimizedArtworkURL(
        for url: URL
    ) -> URL {
        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            return url
        }

        if components.scheme?.lowercased() == "http" {
            components.scheme = "https"
        }

        guard components.host?.hasSuffix(".music.126.net") == true else {
            return components.url ?? url
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll {
            $0.name.caseInsensitiveCompare("param") == .orderedSame
        }
        queryItems.append(
            URLQueryItem(name: "param", value: "300y300")
        )
        components.queryItems = queryItems
        return components.url ?? url
    }
}

/// Keeps Music's previous artwork texture alive until the replacement has
/// loaded, then linearly blends the two textures for the recovered 0.5-second
/// crossfade interval. At most two decoded artwork images are mounted.
struct DesktopAppleMusicBackdropArtwork<ArtworkContent: View>: View {
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion

    let artworkURL: URL?
    /// Blur baked into the cached artwork, in source pixels.
    let blurRadius: Double?
    private let artworkContent: (NSImage) -> ArtworkContent

    @State private var displayedURL: URL?
    @State private var displayedBlurRadius: Double?
    @State private var displayedImage: NSImage?
    @State private var outgoingImage: NSImage?
    @State private var hasOutgoingSource = false
    @State private var incomingOpacity = 1.0
    @State private var transitionGeneration: UInt = 0

    init(
        artworkURL: URL?,
        blurRadius: Double?,
        @ViewBuilder artworkContent: @escaping (NSImage) -> ArtworkContent
    ) {
        self.artworkURL = artworkURL
        self.blurRadius = blurRadius
        self.artworkContent = artworkContent
    }

    var body: some View {
        ZStack {
            // Keep the incoming surface's identity when it becomes outgoing.
            // Its completed frame and producer survive the next artwork load.
            ForEach(artworkLayers) { layer in
                artworkContent(layer.image)
                    .opacity(layer.opacity)
            }
            if artworkLayers.isEmpty {
                Color(white: 0.30)
            }
        }
        .task(id: artworkTaskID) {
            await loadCurrentArtwork()
        }
    }

    private var artworkLayers: [ArtworkLayer] {
        var layers: [ArtworkLayer] = []
        if hasOutgoingSource, let outgoingImage {
            layers.append(ArtworkLayer(image: outgoingImage, opacity: 1))
        }
        if let displayedImage {
            layers.append(ArtworkLayer(
                image: displayedImage,
                opacity: hasOutgoingSource ? incomingOpacity : 1
            ))
        }
        return layers
    }

    private struct ArtworkLayer: Identifiable {
        let image: NSImage
        let opacity: Double

        var id: ObjectIdentifier { ObjectIdentifier(image) }
    }

    private var artworkTaskID: DesktopBackdropArtworkKey {
        DesktopBackdropArtworkKey(
            url: artworkURL,
            blurRadius: blurRadius
        )
    }

    @MainActor
    private func loadCurrentArtwork() async {
        let newURL = artworkURL
        if newURL == displayedURL,
           blurRadius == displayedBlurRadius {
            if hasOutgoingSource, incomingOpacity < 1 {
                startCrossfade(for: newURL)
            }
            // `displayedURL` is no longer seeded from the initializer, so this
            // only happens when an earlier attempt finished without an image.
            // Retry the same URL instead of leaving the solid fallback stuck.
            guard newURL != nil,
                  displayedImage == nil,
                  !hasOutgoingSource else {
                return
            }
        }

        transitionGeneration &+= 1
        let generation = transitionGeneration
        outgoingImage = displayedImage
        hasOutgoingSource = displayedImage != nil
        displayedURL = newURL
        displayedBlurRadius = blurRadius
        displayedImage = nil
        incomingOpacity = 0

        guard let newURL else { return }

        let image = await DesktopAppleMusicBackdropArtworkCache.shared
            .image(
                for: newURL,
                blurRadius: blurRadius
            )
        guard generation == transitionGeneration,
              displayedURL == newURL,
              displayedBlurRadius == blurRadius else {
            return
        }
        guard let image else {
            // Keep the previous texture visible while the replacement is
            // unavailable. The solid fallback only appears when there is no
            // outgoing artwork at all.
            return
        }

        displayedImage = image
        startCrossfade(for: newURL)
    }

    private func startCrossfade(for readyURL: URL?) {
        guard hasOutgoingSource,
              readyURL == displayedURL,
              incomingOpacity < 1 else {
            return
        }

        let generation = transitionGeneration
        withAnimation(
            accessibilityReduceMotion
                ? nil
                : .linear(duration: 0.5)
        ) {
            incomingOpacity = 1
        }

        Task { @MainActor in
            if !accessibilityReduceMotion {
                do {
                    try await Task.sleep(for: .seconds(0.5))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled,
                  generation == transitionGeneration,
                  readyURL == displayedURL else {
                return
            }

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                outgoingImage = nil
                hasOutgoingSource = false
            }
        }
    }
}
