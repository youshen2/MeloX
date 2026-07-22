import CoreGraphics

enum DeterministicRandom {
    static func mixed(_ seed: UInt64) -> UInt64 {
        var value = seed
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return value
    }

    static func splitMix64(_ seed: UInt64) -> UInt64 {
        mixed(seed &+ 0x9E3779B97F4A7C15)
    }

    static func unit(_ seed: UInt64) -> CGFloat {
        CGFloat(mixed(seed) % 10_000) / 10_000
    }

    static func closedUnit(_ seed: UInt64) -> CGFloat {
        CGFloat(mixed(seed) % 10_000) / 9_999
    }
}
