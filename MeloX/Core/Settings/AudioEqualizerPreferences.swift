import Foundation
import Observation

nonisolated enum AudioEqualizerBand: Int, CaseIterable, Identifiable, Sendable {
    case hz31
    case hz62
    case hz125
    case hz250
    case hz500
    case khz1
    case khz2
    case khz4
    case khz8
    case khz16

    nonisolated static let count = khz16.rawValue + 1

    var id: Int { rawValue }

    var centerFrequency: Double {
        switch self {
        case .hz31: 31.25
        case .hz62: 62.5
        case .hz125: 125
        case .hz250: 250
        case .hz500: 500
        case .khz1: 1_000
        case .khz2: 2_000
        case .khz4: 4_000
        case .khz8: 8_000
        case .khz16: 16_000
        }
    }

    var title: String {
        switch self {
        case .hz31: "31 Hz"
        case .hz62: "62 Hz"
        case .hz125: "125 Hz"
        case .hz250: "250 Hz"
        case .hz500: "500 Hz"
        case .khz1: "1 kHz"
        case .khz2: "2 kHz"
        case .khz4: "4 kHz"
        case .khz8: "8 kHz"
        case .khz16: "16 kHz"
        }
    }
}

nonisolated struct AudioEqualizerConfiguration: Equatable, Sendable {
    let isEnabled: Bool
    let preamp: Double
    let bandGains: [Double]

    static let disabled = AudioEqualizerConfiguration(
        isEnabled: false,
        preamp: 0,
        bandGains: Array(
            repeating: 0,
            count: AudioEqualizerBand.count
        )
    )
}

nonisolated enum AudioEqualizerPreset: String, CaseIterable, Identifiable, Sendable {
    case flat
    case acoustic
    case bassBoost
    case bassReduce
    case classical
    case dance
    case electronic
    case hipHop
    case jazz
    case pop
    case rock
    case spokenWord
    case trebleBoost
    case trebleReduce
    case vocal
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flat: "平直"
        case .acoustic: "原声"
        case .bassBoost: "低音增强"
        case .bassReduce: "低音减弱"
        case .classical: "古典"
        case .dance: "舞曲"
        case .electronic: "电子"
        case .hipHop: "嘻哈"
        case .jazz: "爵士"
        case .pop: "流行"
        case .rock: "摇滚"
        case .spokenWord: "播客与有声书"
        case .trebleBoost: "高音增强"
        case .trebleReduce: "高音减弱"
        case .vocal: "人声突出"
        case .custom: "自定义"
        }
    }

    fileprivate var values: (preamp: Double, gains: [Double])? {
        switch self {
        case .flat:
            (0, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        case .acoustic:
            (-4, [4, 3, 2, 1, 0, 1, 2, 3, 4, 3])
        case .bassBoost:
            (-6, [7, 6, 5, 3, 1, 0, 0, 0, 0, 0])
        case .bassReduce:
            (0, [-7, -6, -5, -3, -1, 0, 0, 0, 0, 0])
        case .classical:
            (-4, [5, 4, 3, 0, -2, -2, 0, 3, 4, 5])
        case .dance:
            (-6, [6, 5, 2, 0, 0, -3, -4, -4, 0, 0])
        case .electronic:
            (-5, [5, 4, 1, 0, -2, 2, 1, 2, 5, 6])
        case .hipHop:
            (-5, [6, 5, 2, 3, -1, -1, 2, -1, 2, 3])
        case .jazz:
            (-4, [4, 3, 2, 2, -2, -2, 0, 2, 3, 4])
        case .pop:
            (-5, [-1, 2, 4, 5, 2, -2, -2, -2, -1, -1])
        case .rock:
            (-5, [5, 3, -1, -3, -2, 1, 3, 5, 5, 5])
        case .spokenWord:
            (-3, [-6, -5, -3, 0, 3, 5, 5, 3, 0, -2])
        case .trebleBoost:
            (-6, [0, 0, 0, 0, 0, 1, 3, 5, 6, 7])
        case .trebleReduce:
            (0, [0, 0, 0, 0, 0, -1, -3, -5, -6, -7])
        case .vocal:
            (-4, [-2, -3, -3, 1, 4, 5, 4, 2, 0, -2])
        case .custom:
            nil
        }
    }
}

@MainActor
@Observable
final class AudioEqualizerPreferences {
    nonisolated static let preampRange = -12.0...6.0
    nonisolated static let bandGainRange = -12.0...12.0

    private enum Key {
        static let isEnabled = "melox.equalizer.isEnabled"
        static let preset = "melox.equalizer.preset"
        static let preamp = "melox.equalizer.preamp"
        static let bandGains = "melox.equalizer.bandGains"
    }

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Key.isEnabled)
        }
    }

    private(set) var selectedPreset: AudioEqualizerPreset
    private(set) var preamp: Double
    private(set) var bandGains: [Double]

    var configuration: AudioEqualizerConfiguration {
        AudioEqualizerConfiguration(
            isEnabled: isEnabled,
            preamp: preamp,
            bandGains: bandGains
        )
    }

    var summary: String {
        isEnabled ? selectedPreset.title : "关闭"
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        isEnabled = defaults.object(forKey: Key.isEnabled) as? Bool ?? false
        let storedPreset = AudioEqualizerPreset(
            rawValue: defaults.string(forKey: Key.preset) ?? ""
        ) ?? .flat
        selectedPreset = storedPreset

        let presetValues = storedPreset.values ?? (
            preamp: 0,
            gains: Array(
                repeating: 0,
                count: AudioEqualizerBand.count
            )
        )
        preamp = Self.clamp(
            defaults.object(forKey: Key.preamp) as? Double
                ?? presetValues.preamp,
            to: Self.preampRange
        )

        let storedGains = defaults.array(forKey: Key.bandGains)?
            .compactMap { ($0 as? NSNumber)?.doubleValue }
        let restoredGains: [Double]
        if let storedGains,
           storedGains.count == AudioEqualizerBand.count {
            restoredGains = storedGains
        } else {
            restoredGains = presetValues.gains
        }
        bandGains = Self.sanitizedGains(
            restoredGains
        )
    }

    func apply(_ preset: AudioEqualizerPreset) {
        guard selectedPreset != preset || preset != .custom else { return }

        selectedPreset = preset
        defaults.set(preset.rawValue, forKey: Key.preset)

        guard let values = preset.values else { return }
        preamp = Self.clamp(values.preamp, to: Self.preampRange)
        bandGains = Self.sanitizedGains(values.gains)
        persistCurve()
    }

    func gain(for band: AudioEqualizerBand) -> Double {
        bandGains[band.rawValue]
    }

    func setGain(_ gain: Double, for band: AudioEqualizerBand) {
        let clampedGain = Self.clamp(gain, to: Self.bandGainRange)
        guard bandGains[band.rawValue] != clampedGain else { return }
        bandGains[band.rawValue] = clampedGain
        markAsCustom()
        defaults.set(bandGains, forKey: Key.bandGains)
    }

    func setPreamp(_ value: Double) {
        let clampedValue = Self.clamp(value, to: Self.preampRange)
        guard preamp != clampedValue else { return }
        preamp = clampedValue
        markAsCustom()
        defaults.set(preamp, forKey: Key.preamp)
    }

    func resetCurve() {
        apply(.flat)
    }

    func reset() {
        isEnabled = false
        apply(.flat)
    }

    private func markAsCustom() {
        guard selectedPreset != .custom else { return }
        selectedPreset = .custom
        defaults.set(selectedPreset.rawValue, forKey: Key.preset)
    }

    private func persistCurve() {
        defaults.set(preamp, forKey: Key.preamp)
        defaults.set(bandGains, forKey: Key.bandGains)
    }

    private static func sanitizedGains(_ gains: [Double]) -> [Double] {
        gains.map { gain in
            clamp(gain.isFinite ? gain : 0, to: bandGainRange)
        }
    }

    private static func clamp(
        _ value: Double,
        to range: ClosedRange<Double>
    ) -> Double {
        min(max(value.isFinite ? value : 0, range.lowerBound), range.upperBound)
    }
}
