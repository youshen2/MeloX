import SwiftUI

enum LyricsRefreshRate: Int, CaseIterable, Identifiable {
    case fps30 = 30
    case fps60 = 60
    case fps90 = 90
    case fps120 = 120

    static let defaultValue = LyricsRefreshRate.fps60
    static let lowPowerValue = LyricsRefreshRate.fps30

    var id: Int { rawValue }

    var title: String {
        "\(rawValue) FPS"
    }

    var minimumInterval: TimeInterval {
        1.0 / Double(rawValue)
    }
}

private struct EffectiveLyricsRefreshRateKey: EnvironmentKey {
    static let defaultValue = LyricsRefreshRate.defaultValue
}

extension EnvironmentValues {
    var effectiveLyricsRefreshRate: LyricsRefreshRate {
        get { self[EffectiveLyricsRefreshRateKey.self] }
        set { self[EffectiveLyricsRefreshRateKey.self] = newValue }
    }
}
