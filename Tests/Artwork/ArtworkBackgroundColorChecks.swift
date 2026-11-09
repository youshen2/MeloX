@main
struct ArtworkBackgroundColorChecks {
    static func main() {
        let black: [UInt8] = [0, 0, 0, 255]
        let white: [UInt8] = [255, 255, 255, 255]
        let red: [UInt8] = [230, 22, 46, 255]
        let amber: [UInt8] = [143, 109, 73, 255]
        let nearbyAmber: [UInt8] = [145, 111, 75, 255]
        let redColor = SIMD3<Double>(230, 22, 46) / 255

        check(repeated(white, count: 10) + repeated(red, count: 3), equals: SIMD3<Double>(repeating: 1))
        check(repeated(white, count: 10) + repeated(red, count: 4), equals: redColor)
        check(repeated(black, count: 10) + repeated(red, count: 4), equals: redColor)
        check(
            amber + nearbyAmber + red,
            equals: SIMD3<Double>(144, 110, 74) / 255
        )

        let translucentBlue: [UInt8] = [18, 42, 96, 128]
        let transparent: [UInt8] = [0, 0, 0, 0]
        check(
            repeated(transparent, count: 20) + translucentBlue,
            equals: SIMD3<Double>(18, 42, 96) / 128
        )
        precondition(ArtworkBackgroundColor.dominant(inPremultipliedRGBA8: transparent) == nil)
        precondition(ArtworkBackgroundColor.dominant(inPremultipliedRGBA8: []) == nil)
        print("Artwork background color regression passed")
    }

    private static func repeated(_ pixel: [UInt8], count: Int) -> [UInt8] {
        Array(repeating: pixel, count: count).flatMap { $0 }
    }

    private static func check(_ pixels: [UInt8], equals expected: SIMD3<Double>) {
        guard let actual = ArtworkBackgroundColor.dominant(inPremultipliedRGBA8: pixels) else {
            preconditionFailure("Expected a background color")
        }
        precondition(abs(actual.x - expected.x) < 0.000001)
        precondition(abs(actual.y - expected.y) < 0.000001)
        precondition(abs(actual.z - expected.z) < 0.000001)
    }
}
