// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Ported to native SwiftUI under the PV Tool Non-Commercial License.

import SwiftUI

enum TextPVTextResources {
    static let formulae = [
        "iℏ ∂/∂t Ψ = [-ℏ²/2m ∇² + V] Ψ",
        "ρ(∂v/∂t + v·∇v) = -∇p + μ∇²v + f",
        "∇·E = ρ/ε₀", "∇·B = 0", "∇×E = -∂B/∂t",
        "∇×B = μ₀(J + ε₀ ∂E/∂t)",
        "G_μν + Λg_μν = (8πG/c⁴) T_μν",
        "F(k) = ∫f(x) e^(-2πikx) dx",
        "E² = (pc)² + (mc²)²", "Δx·Δp ≥ ℏ/2",
        "∂²u/∂t² = c²∇²u", "S = k_B ln Ω", "dS/dt ≥ 0",
        "H = Σ pq̇ - L", "∮ E·dl = -dΦ_B/dt",
    ]
    static let formulaGlyphs = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ΣΔΩΨΦπλαβγ")
    static let noiseGlyphs = Array("01/#%&$<>[]{}SYSTEM_NULL_ERROR")
    static let monospacedFamilies: Set<String> = ["mono", "SF Mono", "Courier New"]
    static let serifFamilies: Set<String> = ["Noto Serif JP"]
    static let strokeDirections: [CGPoint] = (0..<12).map { index in
        let angle = CGFloat(index) / 12 * 2 * .pi
        return CGPoint(x: cos(angle), y: sin(angle))
    }
}

enum TextPVFontFactory {
    static func font(
        size: CGFloat,
        family: String = "",
        weight: Font.Weight = .bold,
        monospaced: Bool = false
    ) -> Font {
        if monospaced || TextPVTextResources.monospacedFamilies.contains(family) {
            return .system(size: size, weight: weight, design: .monospaced)
        }
        if TextPVTextResources.serifFamilies.contains(family) {
            return .custom(LyricsTypography.heavySerifFontName, size: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
}

extension TextPVEffectPainter {
    func color(
        _ key: String,
        in config: TextPVEffectConfig,
        default fallback: String
    ) -> Color {
        palette.resolve(config.string(key, default: fallback), fallback: fallback)
    }

    func point(x: CGFloat, y: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }

    func random(_ index: Int, salt: UInt64 = 0) -> CGFloat {
        TextPVSeed.unit(seed, index, salt: salt)
    }

    func signedRandom(_ index: Int, salt: UInt64 = 0) -> CGFloat {
        TextPVSeed.signed(seed, index, salt: salt)
    }

    func cachedPath(
        _ name: String,
        size: CGSize,
        discriminator: String,
        includesSeed: Bool = false,
        make: () -> Path
    ) -> Path {
        TextPVPathCache.shared.path(
            for: pathCacheKey(
                name,
                size: size,
                discriminator: discriminator,
                includesSeed: includesSeed
            ),
            make: make
        )
    }

    func cachedPathPair(
        _ name: String,
        size: CGSize,
        discriminator: String,
        includesSeed: Bool = false,
        make: () -> (Path, Path)
    ) -> (Path, Path) {
        TextPVPathCache.shared.pair(
            for: pathCacheKey(
                name,
                size: size,
                discriminator: discriminator,
                includesSeed: includesSeed
            ),
            make: make
        )
    }

    private func pathCacheKey(
        _ name: String,
        size: CGSize,
        discriminator: String,
        includesSeed: Bool
    ) -> String {
        let width = Int(size.width.rounded(.toNearestOrAwayFromZero))
        let height = Int(size.height.rounded(.toNearestOrAwayFromZero))
        let seedComponent = includesSeed ? ":\(seed)" : ""
        return "\(name):\(width)x\(height):\(discriminator)\(seedComponent)"
    }

    func font(
        size: CGFloat,
        family: String = "",
        weight: Font.Weight = .bold,
        monospaced: Bool = false
    ) -> Font {
        let scaledSize = max(size * frame.fontScale, 6)
        return TextPVFontFactory.font(
            size: scaledSize,
            family: family,
            weight: weight,
            monospaced: monospaced
        )
    }

    func drawText(
        _ string: String,
        in context: inout GraphicsContext,
        at position: CGPoint,
        color: Color,
        size: CGFloat,
        family: String = "",
        weight: Font.Weight = .bold,
        anchor: UnitPoint = .center,
        rotation: CGFloat = 0,
        opacity: CGFloat = 1,
        tracking: CGFloat = 0,
        strokeColor: Color? = nil,
        strokeWidth: CGFloat = 0
    ) {
        var text = Text(verbatim: string)
            .font(font(size: size, family: family, weight: weight))
            .foregroundStyle(color.opacity(opacity))
        if tracking != 0 {
            text = text.tracking(tracking)
        }

        var layer = context
        layer.translateBy(x: position.x, y: position.y)
        layer.rotate(by: .radians(Double(rotation)))

        if let strokeColor, strokeWidth > 0 {
            let stroke = context.resolve(
                Text(verbatim: string)
                    .font(font(size: size, family: family, weight: weight))
                    .foregroundStyle(strokeColor.opacity(opacity))
                    .tracking(tracking)
            )
            for direction in TextPVTextResources.strokeDirections {
                layer.draw(
                    stroke,
                    at: CGPoint(
                        x: direction.x * strokeWidth,
                        y: direction.y * strokeWidth
                    ),
                    anchor: anchor
                )
            }
        }

        layer.draw(context.resolve(text), at: .zero, anchor: anchor)
    }

    func rotatedRectangle(
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        rotation: CGFloat
    ) -> Path {
        let cosine = cos(rotation)
        let sine = sin(rotation)
        let corners = [
            CGPoint(x: -width / 2, y: -height / 2),
            CGPoint(x: width / 2, y: -height / 2),
            CGPoint(x: width / 2, y: height / 2),
            CGPoint(x: -width / 2, y: height / 2),
        ].map { point in
            CGPoint(
                x: center.x + point.x * cosine - point.y * sine,
                y: center.y + point.x * sine + point.y * cosine
            )
        }

        var path = Path()
        path.move(to: corners[0])
        corners.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }

    func starPath(center: CGPoint, radius: CGFloat, points: Int = 4) -> Path {
        var path = Path()
        for index in 0..<(points * 2) {
            let angle = CGFloat(index) * .pi / CGFloat(points) - .pi / 2
            let currentRadius = index.isMultiple(of: 2) ? radius : radius * 0.28
            let point = CGPoint(
                x: center.x + cos(angle) * currentRadius,
                y: center.y + sin(angle) * currentRadius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
