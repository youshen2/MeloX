import Foundation
import CoreGraphics
import ImageIO

// GPL-3.0: lladlam/MeloX-Android 9f496319 / ArtworkDynamicPalette.kt.
nonisolated struct DesktopAndroidFlowPalette: Sendable {
    var values: [Float] // Nine row-major RGB cells followed by the average RGB.
    static let fallback: Self = {
        let hexes: [Int] = [0x101E3D, 0x2E1A57, 0x0F3B4D, 0x38143D, 0x24476B,
                           0x4D1F4D, 0x0D2E42, 0x291A4D, 0x121C33, 0x171D32]
        var result: [Float] = []
        for hex in hexes {
            result.append(Float((hex >> 16) & 255) / 255)
            result.append(Float((hex >> 8) & 255) / 255)
            result.append(Float(hex & 255) / 255)
        }
        return Self(values: result)
    }()

    func blended(to target: Self, amount: Double) -> Self {
        let t = Float(min(max(amount, 0), 1))
        return Self(values: zip(values, target.values).map { $0 + ($1 - $0) * t })
    }

    static func decode(_ data: Data) -> Self? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let side = 160
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        func average(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, boost: Float) -> [Float] {
            var sum = [Float](repeating: 0, count: 3)
            var count: Float = 0
            for y in stride(from: y0, to: y1, by: 2) {
                for x in stride(from: x0, to: x1, by: 2) {
                    let offset = (y * side + x) * 4
                    let alpha = Float(pixels[offset + 3])
                    for c in 0..<3 {
                        sum[c] += alpha > 0 ? min(Float(pixels[offset + c]) / alpha, 1) : 0
                    }
                    count += 1
                }
            }
            let rgb = sum.map { ($0 / count * 255).rounded() / 255 }
            let low = rgb.min()!, high = rgb.max()!, lightness = (low + high) / 2
            let delta = high - low
            let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
            guard saturation >= 0.08 else { return rgb }
            let ratio = min(saturation * boost, 1) / saturation
            return rgb.map { (min(max(lightness + ($0 - lightness) * ratio, 0), 1) * 255).rounded() / 255 }
        }
        var colors: [Float] = []
        for y in 0..<3 {
            for x in 0..<3 {
                colors += average(x * 53, y * 53, x == 2 ? 160 : (x + 1) * 53,
                                  y == 2 ? 160 : (y + 1) * 53, boost: 1.2)
            }
        }
        colors += average(0, 0, 160, 160, boost: 1.1)
        return Self(values: colors)
    }
}

actor DesktopAndroidFlowPaletteStore {
    static let shared = DesktopAndroidFlowPaletteStore()
    private var cache: [URL: DesktopAndroidFlowPalette] = [:]
    private var order: [URL] = []

    func palette(for url: URL?) async -> DesktopAndroidFlowPalette {
        guard let url else { return .fallback }
        if let palette = cache[url] { return palette }
        guard let data = try? await ArtworkDataLoader.data(from: url, preferredPixelSize: 160),
              let palette = DesktopAndroidFlowPalette.decode(data) else { return .fallback }
        if cache[url] == nil { order.append(url) }
        cache[url] = palette
        if order.count > 48 { cache[order.removeFirst()] = nil }
        return palette
    }
}
