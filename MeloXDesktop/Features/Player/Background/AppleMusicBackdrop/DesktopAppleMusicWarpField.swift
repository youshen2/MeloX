import Foundation

/// A small, temporally interpolated UNORM16 inverse map of the original pinch mesh.
/// The background is already blurred; sampling this field avoids solving
/// overlapping triangles again for every output pixel on every display frame.
struct DesktopAppleMusicWarpField: Sendable {
    let dimension: Int
    let phaseCount: Int
    let coordinates: Data

    nonisolated static let identity = DesktopAppleMusicWarpField(
        dimension: 2,
        phaseCount: 1,
        coordinates: [UInt16(0), .max, .max, .max, 0, 0, .max, 0]
            .withUnsafeBytes { Data($0) }
    )
}

actor DesktopAppleMusicWarpFieldCache {
    static let shared = DesktopAppleMusicWarpFieldCache()

    private var fields: [Int: DesktopAppleMusicWarpField] = [:]

    func field(
        for mesh: DesktopAppleMusicPinchMesh
    ) -> DesktopAppleMusicWarpField {
        if let field = fields[mesh.index] { return field }
        let field = Self.makeField(for: mesh)
        // Keep the active mesh and a recently used one, rather than retaining
        // all five 4.1 MB maps for the lifetime of the player.
        if fields.count == 2 { fields.remove(at: fields.startIndex) }
        fields[mesh.index] = field
        return field
    }

    private struct Triangle {
        let origin: SIMD2<Float>
        let inverseX: SIMD2<Float>
        let inverseY: SIMD2<Float>
    }

    nonisolated private static func makeField(
        for mesh: DesktopAppleMusicPinchMesh
    ) -> DesktopAppleMusicWarpField {
        let dimension = 129
        let phaseCount = 65
        let gridDimension = 41
        let cellDimension = gridDimension - 1
        let pointCount = gridDimension * gridDimension
        let positions = mesh.positions.withUnsafeBytes {
            Array($0.bindMemory(to: SIMD2<Float>.self))
        }
        let offsets = mesh.lookupOffsets.withUnsafeBytes {
            Array($0.bindMemory(to: UInt32.self))
        }
        let candidates = mesh.lookupTriangles.withUnsafeBytes {
            Array($0.bindMemory(to: UInt16.self))
        }
        var coordinates = [UInt16]()
        coordinates.reserveCapacity(dimension * dimension * phaseCount * 2)

        for phase in 0..<phaseCount {
            let weight = Float(phase) / Float(phaseCount - 1)
            let points = (0..<pointCount).map { index in
                let clip = positions[index]
                    + (positions[pointCount + index] - positions[index]) * weight
                return SIMD2<Float>(clip.x * 0.5 + 0.5, 0.5 - clip.y * 0.5)
            }
            var triangles = [Triangle]()
            triangles.reserveCapacity(cellDimension * cellDimension * 2)
            for y in 0..<cellDimension {
                for x in 0..<cellDimension {
                    let index = y * gridDimension + x
                    let topLeft = points[index]
                    let topRight = points[index + 1]
                    let bottomLeft = points[index + gridDimension]
                    let bottomRight = points[index + gridDimension + 1]
                    triangles.append(triangle(
                        origin: topLeft,
                        x: bottomRight - bottomLeft,
                        y: bottomLeft - topLeft
                    ))
                    triangles.append(triangle(
                        origin: topLeft,
                        x: topRight - topLeft,
                        y: bottomRight - topRight
                    ))
                }
            }

            for y in 0..<dimension {
                for x in 0..<dimension {
                    let destination = SIMD2<Float>(Float(x), Float(y))
                        / Float(dimension - 1)
                    let binX = min(Int(destination.x * 64), 63)
                    let binY = min(Int(destination.y * 64), 63)
                    let bin = binY * 64 + binX
                    var uv = SIMD2<Float>(destination.x, 1 - destination.y)
                    // Match the mesh's draw order at folded triangles.
                    let candidatesInBin = Int(offsets[bin])..<Int(offsets[bin + 1])
                    for candidate in candidatesInBin.reversed() {
                        let index = Int(candidates[candidate])
                        let triangle = triangles[index]
                        let delta = destination - triangle.origin
                        let local = SIMD2<Float>(
                            triangle.inverseX.x * delta.x + triangle.inverseX.y * delta.y,
                            triangle.inverseY.x * delta.x + triangle.inverseY.y * delta.y
                        )
                        guard local.x >= -0.00002, local.x <= 1.00002,
                              local.y >= -0.00002, local.y <= 1.00002,
                              index.isMultiple(of: 2)
                                ? local.y + 0.00002 >= local.x
                                : local.x + 0.00002 >= local.y else { continue }
                        let cell = index / 2
                        let cellOrigin = SIMD2<Float>(
                            Float(cell % cellDimension),
                            Float(cell / cellDimension)
                        )
                        uv = (cellOrigin + local)
                            / Float(cellDimension)
                        break
                    }
                    coordinates.append(UInt16((min(max(uv.x, 0), 1) * 65_535).rounded()))
                    coordinates.append(UInt16((min(max(uv.y, 0), 1) * 65_535).rounded()))
                }
            }
        }
        return DesktopAppleMusicWarpField(
            dimension: dimension,
            phaseCount: phaseCount,
            coordinates: coordinates.withUnsafeBytes { Data($0) }
        )
    }

    nonisolated private static func triangle(
        origin: SIMD2<Float>,
        x: SIMD2<Float>,
        y: SIMD2<Float>
    ) -> Triangle {
        let determinant = x.x * y.y - x.y * y.x
        let inverse = abs(determinant) >= 0.0000001 ? 1 / determinant : .infinity
        return Triangle(
            origin: origin,
            inverseX: SIMD2<Float>(y.y, -y.x) * inverse,
            inverseY: SIMD2<Float>(-x.y, x.x) * inverse
        )
    }
}
