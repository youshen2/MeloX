import Foundation

struct DesktopAppleMusicPinchMesh: Equatable {
    let index: Int
    let positions: Data
    let lookupOffsets: Data
    let lookupTriangles: Data
}

@MainActor
enum DesktopAppleMusicPinchMeshStore {
    private static let pairCount = 5
    private static let gridDimension = 41
    private static let phaseCount = 2
    private static let bytesPerPoint = MemoryLayout<SIMD2<Float>>.stride
    private static let pairByteCount =
        gridDimension
        * gridDimension
        * phaseCount
        * bytesPerPoint
    private static let lookupDimension = 64
    private static var meshesByIndex: [Int: DesktopAppleMusicPinchMesh] = [:]

    static func randomIndex() -> Int {
        Int.random(in: 0..<pairCount)
    }

    static func mesh(at requestedIndex: Int) -> DesktopAppleMusicPinchMesh {
        let index = min(max(requestedIndex, 0), pairCount - 1)
        if let mesh = meshesByIndex[index] { return mesh }
        let lowerBound = index * pairByteCount
        let upperBound = lowerBound + pairByteCount
        let mesh = makeMesh(
            index: index,
            positions: allMeshData.count >= upperBound
                ? allMeshData.subdata(in: lowerBound..<upperBound)
                : identityMeshData
        )
        meshesByIndex[index] = mesh
        return mesh
    }

    private static func makeMesh(
        index: Int,
        positions: Data
    ) -> DesktopAppleMusicPinchMesh {
        let lookup = makeLookup(for: positions)
        return DesktopAppleMusicPinchMesh(
            index: index,
            positions: positions,
            lookupOffsets: lookup.offsets,
            lookupTriangles: lookup.triangles
        )
    }

    private static func makeLookup(
        for data: Data
    ) -> (offsets: Data, triangles: Data) {
        let expectedPointCount = gridDimension * gridDimension * phaseCount
        return data.withUnsafeBytes { rawBuffer in
            let points = rawBuffer.bindMemory(to: SIMD2<Float>.self)
            guard points.count == expectedPointCount else {
                return (Data(), Data())
            }

            var bins = Array(
                repeating: [UInt16](),
                count: lookupDimension * lookupDimension
            )
            for y in 0..<(gridDimension - 1) {
                for x in 0..<(gridDimension - 1) {
                    let cellIndex = y * (gridDimension - 1) + x
                    appendTriangle(
                        cellIndex: cellIndex,
                        triangleOffset: 0,
                        vertexOffsets: (0, gridDimension + 1, gridDimension),
                        topLeftIndex: y * gridDimension + x,
                        points: points,
                        bins: &bins
                    )
                    appendTriangle(
                        cellIndex: cellIndex,
                        triangleOffset: 1,
                        vertexOffsets: (0, 1, gridDimension + 1),
                        topLeftIndex: y * gridDimension + x,
                        points: points,
                        bins: &bins
                    )
                }
            }

            var offsets = [UInt32]()
            offsets.reserveCapacity(bins.count + 1)
            var triangles = [UInt16]()
            triangles.reserveCapacity(
                bins.reduce(into: 0) { $0 += $1.count }
            )
            offsets.append(0)
            for bin in bins {
                triangles.append(contentsOf: bin)
                offsets.append(UInt32(triangles.count))
            }
            return (
                offsets.withUnsafeBytes { Data($0) },
                triangles.withUnsafeBytes { Data($0) }
            )
        }
    }

    private static func appendTriangle(
        cellIndex: Int,
        triangleOffset: Int,
        vertexOffsets: (Int, Int, Int),
        topLeftIndex: Int,
        points: UnsafeBufferPointer<SIMD2<Float>>,
        bins: inout [[UInt16]]
    ) {
        let phaseOffset = gridDimension * gridDimension
        let indices = [
            topLeftIndex + vertexOffsets.0,
            topLeftIndex + vertexOffsets.1,
            topLeftIndex + vertexOffsets.2,
        ]
        var minimum = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
        for phase in 0..<phaseCount {
            for index in indices {
                let clip = points[phase * phaseOffset + index]
                let destination = SIMD2<Float>(
                    clip.x * 0.5 + 0.5,
                    0.5 - clip.y * 0.5
                )
                minimum = SIMD2<Float>(
                    Swift.min(minimum.x, destination.x),
                    Swift.min(minimum.y, destination.y)
                )
                maximum = SIMD2<Float>(
                    Swift.max(maximum.x, destination.x),
                    Swift.max(maximum.y, destination.y)
                )
            }
        }
        guard maximum.x >= 0,
              minimum.x <= 1,
              maximum.y >= 0,
              minimum.y <= 1 else {
            return
        }

        let lowerX = lookupIndex(for: minimum.x)
        let upperX = lookupIndex(for: maximum.x)
        let lowerY = lookupIndex(for: minimum.y)
        let upperY = lookupIndex(for: maximum.y)
        let triangle = UInt16(cellIndex * 2 + triangleOffset)
        for y in lowerY...upperY {
            for x in lowerX...upperX {
                bins[y * lookupDimension + x].append(triangle)
            }
        }
    }

    private static func lookupIndex(for coordinate: Float) -> Int {
        min(
            max(Int(floor(coordinate * Float(lookupDimension))), 0),
            lookupDimension - 1
        )
    }

    private static let allMeshData: Data = {
        guard let url = Bundle.main.url(
            forResource: "DesktopAppleMusicPinchMeshes",
            withExtension: "bin"
        ), let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return Data()
        }
        return data
    }()

    private static let identityMeshData: Data = {
        var points: [SIMD2<Float>] = []
        points.reserveCapacity(gridDimension * gridDimension * phaseCount)
        for _ in 0..<phaseCount {
            for y in 0..<gridDimension {
                for x in 0..<gridDimension {
                    let unitX = Float(x) / Float(gridDimension - 1)
                    let unitY = Float(y) / Float(gridDimension - 1)
                    points.append(
                        SIMD2<Float>(
                            unitX * 2 - 1,
                            unitY * 2 - 1
                        )
                    )
                }
            }
        }
        return points.withUnsafeBytes { Data($0) }
    }()
}
