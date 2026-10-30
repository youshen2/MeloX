import AVFoundation
import AudioStreaming

@MainActor
final class AudioEqualizerProcessor {
    private var configuration: AudioEqualizerConfiguration
    private var equalizer: AVAudioUnitEQ?
    private var autoMixEqualizer: AVAudioUnitEQ?

    init(configuration: AudioEqualizerConfiguration) {
        self.configuration = configuration
    }

    func attach(to player: AudioStreaming.AudioPlayer) {
        let equalizer = AVAudioUnitEQ(numberOfBands: AudioEqualizerBand.count)
        let autoMixEqualizer = AVAudioUnitEQ(numberOfBands: 3)
        self.equalizer = equalizer
        self.autoMixEqualizer = autoMixEqualizer
        for (band, frequency) in zip(equalizer.bands, AudioEqualizerBand.allCases) {
            band.filterType = .parametric
            band.frequency = Float(frequency.centerFrequency)
            band.bandwidth = 1.4
            band.bypass = false
        }
        for (band, frequency) in zip(autoMixEqualizer.bands, [120.0, 1_500, 7_000]) {
            band.filterType = .parametric
            band.frequency = Float(frequency)
            band.bandwidth = 1.4
            band.bypass = false
        }
        update(configuration: configuration)
        player.attach(nodes: [equalizer, autoMixEqualizer])
    }

    func update(configuration: AudioEqualizerConfiguration) {
        self.configuration = configuration
        equalizer?.bypass = !configuration.isEnabled
        equalizer?.globalGain = Float(configuration.preamp)
        if let equalizer {
            for (band, gain) in zip(equalizer.bands, configuration.bandGains) { band.gain = Float(gain) }
        }
    }

    func setAutoMixGains(low: Float, mid: Float, high: Float) {
        guard let autoMixEqualizer else { return }
        for (band, gain) in zip(autoMixEqualizer.bands, [low, mid, high]) { band.gain = gain }
    }
}
