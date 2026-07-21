import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

actor ArtworkAccentColorProvider {
    static let shared = ArtworkAccentColorProvider()
    nonisolated static let fallback = SIMD3<Double>(repeating: 0.86)

    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private var cache: [URL: SIMD3<Double>] = [:]

    func accentColor(for artworkURL: URL?) async -> SIMD3<Double> {
        guard let artworkURL else { return Self.fallback }
        if let cachedColor = cache[artworkURL] {
            return cachedColor
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: artworkURL)
            try Task.checkCancellation()
            guard let image = CIImage(
                data: data,
                options: [.applyOrientationProperty: true]
            ) else {
                return Self.fallback
            }

            let color = averageColor(of: image)
            cache[artworkURL] = color
            return color
        } catch {
            return Self.fallback
        }
    }

    private func averageColor(of image: CIImage) -> SIMD3<Double> {
        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = image.extent
        guard let outputImage = filter.outputImage else { return Self.fallback }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: colorSpace
        )

        return readableAccent(
            SIMD3<Double>(
                Double(pixel[0]) / 255,
                Double(pixel[1]) / 255,
                Double(pixel[2]) / 255
            )
        )
    }

    private func readableAccent(_ source: SIMD3<Double>) -> SIMD3<Double> {
        let sourcePeak = max(source.x, source.y, source.z)
        guard sourcePeak > 0.04 else { return Self.fallback }

        let luminance = source.x * 0.2126
            + source.y * 0.7152
            + source.z * 0.0722
        var accent = SIMD3<Double>(
            luminance + (source.x - luminance) * 1.35,
            luminance + (source.y - luminance) * 1.35,
            luminance + (source.z - luminance) * 1.35
        )

        let peak = max(accent.x, accent.y, accent.z)
        if peak < 0.76 {
            accent *= 0.76 / max(peak, 0.01)
        }

        let spread = max(accent.x, accent.y, accent.z)
            - min(accent.x, accent.y, accent.z)
        if spread < 0.08 {
            let neutral = min(max(luminance + 0.28, 0.74), 0.92)
            return SIMD3<Double>(repeating: neutral)
        }

        return SIMD3<Double>(
            min(max(accent.x, 0), 1),
            min(max(accent.y, 0), 1),
            min(max(accent.z, 0), 1)
        )
    }
}
