import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Prepares and caches a small, edge-clamped artwork texture. The SwiftUI
/// background shader reuses it for all rotating layers and quality levels.
actor DesktopArtworkBackdropRenderer {
    static let shared = DesktopArtworkBackdropRenderer()

    /// Music.app 的封面纹理上限是短边 300px（`sub_101831D5B`）。
    nonisolated static let standardPixelSize = 300

    /// 低功耗模式下收紧到 180px，对应 Apple 按 `device.isLowPower`
    /// 切换处理阈值的行为。
    nonisolated static let lowPowerPixelSize = 180

    private nonisolated static let imageCache =
        DesktopArtworkBackdropImageCache()
    private let ciContext = CIContext(
        options: [.cacheIntermediates: false]
    )
    private let colorSpace = CGColorSpace(
        name: CGColorSpace.sRGB
    )!

    /// 把已下载的封面烘焙为短边 300px（低功耗 180px）的模糊纹理。
    /// 结果按 URL + 模糊半径缓存；URL 变化时旧缓存不受影响。
    func bakedImage(
        from sourceImage: NSImage,
        sourceURL: URL,
        blurRadius: Double
    ) -> NSImage? {
        let pixelSize =
            ProcessInfo.processInfo.isLowPowerModeEnabled
            ? Self.lowPowerPixelSize
            : Self.standardPixelSize
        let cacheKey = Self.cacheKey(
            sourceURL: sourceURL,
            pixelSize: pixelSize,
            blurRadius: blurRadius
        )
        if let cached = Self.imageCache.image(
            forKey: cacheKey
        ) {
            return cached
        }

        guard let cgImage = sourceImage.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else {
            return nil
        }

        var ciImage = CIImage(cgImage: cgImage)
        ciImage = downsampled(ciImage, pixelSize: pixelSize)
        guard let blurred = blurredBackdrop(
            ciImage,
            pixelSize: pixelSize,
            blurRadius: blurRadius
        ) else {
            return nil
        }

        let result = NSImage(
            cgImage: blurred,
            size: NSSize(
                width: blurred.width,
                height: blurred.height
            )
        )
        Self.imageCache.insert(result, forKey: cacheKey)
        return result
    }

    nonisolated static func clearCache() {
        imageCache.removeAll()
    }

    private func downsampled(
        _ image: CIImage,
        pixelSize: Int
    ) -> CIImage {
        let extent = image.extent
        guard !extent.isInfinite else { return image }

        let maximumDimension = max(
            extent.width,
            extent.height
        )
        guard maximumDimension > CGFloat(pixelSize) else {
            return image
        }

        let scale = CGFloat(pixelSize) / maximumDimension
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(scale)
        filter.aspectRatio = 1
        return filter.outputImage ?? image
    }

    private func blurredBackdrop(
        _ image: CIImage,
        pixelSize: Int,
        blurRadius: Double
    ) -> CGImage? {
        let extent = image.extent.integral
        guard !extent.isEmpty, !extent.isInfinite else {
            return nil
        }

        // 调用方传入的 radius 已经按
        // `blurSigma * sourcePixels / artworkSide` 折算过，
        // 这里与 Apple 一样把有效半径限制在可接受区间。
        let radius = min(max(blurRadius, 0), 48)
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = image.clampedToExtent()
        filter.radius = Float(radius)
        guard let outputImage = filter.outputImage?.cropped(
            to: extent
        ) else {
            return nil
        }

        return ciContext.createCGImage(
            outputImage,
            from: extent,
            format: .RGBA8,
            colorSpace: colorSpace
        )
    }

    nonisolated private static func cacheKey(
        sourceURL: URL,
        pixelSize: Int,
        blurRadius: Double
    ) -> String {
        [
            sourceURL.absoluteString,
            "p\(pixelSize)",
            "b\(Int((blurRadius * 2).rounded()))",
        ].joined(separator: "#")
    }
}

nonisolated private final class DesktopArtworkBackdropImageCache:
    NSObject, @unchecked Sendable {
    private let storage = NSCache<NSString, NSImage>()

    override init() {
        super.init()
        storage.countLimit = 16
        storage.totalCostLimit = 16 * 1_024 * 1_024
    }

    func image(forKey key: String) -> NSImage? {
        storage.object(forKey: key as NSString)
    }

    func insert(_ image: NSImage, forKey key: String) {
        let pixelCost = Int(
            image.size.width * image.size.height * 4
        )
        storage.setObject(
            image,
            forKey: key as NSString,
            cost: pixelCost
        )
    }

    func removeAll() {
        storage.removeAllObjects()
    }
}
