@preconcurrency import AVFoundation

enum AudioPlaybackFormat {
    static func load(from url: URL) async -> AVAudioFormat? {
        let format: AVAudioFormat
        if url.isFileURL {
            guard let file = try? AVAudioFile(forReading: url) else { return nil }
            format = file.processingFormat
        } else {
            let asset = AVURLAsset(url: url)
            guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
                  let description = try? await track.load(.formatDescriptions).first else { return nil }
            format = AVAudioFormat(cmAudioFormatDescription: description)
        }
        if let layout = format.channelLayout {
            return AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: format.sampleRate,
                interleaved: true,
                channelLayout: layout
            )
        }
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: format.channelCount,
            interleaved: true
        )
    }
}
