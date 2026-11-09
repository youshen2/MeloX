// Background selection adapted from UIImageColors by Jathu Satkunarajah,
// based on Panic's ColorArt. MIT license, Copyright (c) 2015 Jathu Satkunarajah.
// Source: https://github.com/jathu/UIImageColors/blob/f064be8ee0b03158e61135e6c384aee18d7a5414/UIImageColors/Sources/UIImageColors.swift
// The full license is bundled in Resources/UIImageColors-LICENSE.txt.

nonisolated enum ArtworkBackgroundColor {
    private struct Bucket {
        var count = 0
        var sum = SIMD3<Double>.zero

        var color: SIMD3<Double> {
            sum / Double(count)
        }

        var isBlackOrWhite: Bool {
            let rgb = color
            return min(rgb.x, rgb.y, rgb.z) > 232.0 / 255
                || max(rgb.x, rgb.y, rgb.z) < 23.0 / 255
        }
    }

    static func dominant(inPremultipliedRGBA8 pixels: [UInt8]) -> SIMD3<Double>? {
        var buckets = [Bucket](repeating: Bucket(), count: 512)
        for offset in stride(from: 0, to: pixels.count - 3, by: 4) {
            let alpha = Double(pixels[offset + 3])
            guard alpha >= 127 else { continue }
            let color = SIMD3(
                min(Double(pixels[offset]) / alpha, 1),
                min(Double(pixels[offset + 1]) / alpha, 1),
                min(Double(pixels[offset + 2]) / alpha, 1)
            )

            // Group neighboring shades so JPEG noise doesn't split a large color region.
            let red = min(Int(color.x * 8), 7)
            let green = min(Int(color.y * 8), 7)
            let blue = min(Int(color.z * 8), 7)
            let index = red * 64 + green * 8 + blue
            buckets[index].count += 1
            buckets[index].sum += color
        }

        guard let dominant = buckets.max(by: { $0.count < $1.count }),
              dominant.count > 0 else { return nil }
        guard dominant.isBlackOrWhite else { return dominant.color }

        // UIImageColors keeps a black or white background unless a sufficiently
        // common alternative exists. A small logo shouldn't tint a whole page.
        let alternatives = buckets.lazy.filter {
            Double($0.count) > Double(dominant.count) * 0.30 && !$0.isBlackOrWhite
        }
        return alternatives.max(by: { $0.count < $1.count })?.color ?? dominant.color
    }
}
