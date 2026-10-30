import AVFoundation
import XCTest
@testable import AudioStreaming

final class AudioSeekTests: XCTestCase {
    func testSeekDoesNotAdvanceWhileWaitingForDecodedAudio() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "vbr", withExtension: "mp3", subdirectory: "Fixtures"))
        let decoder = try Decoder(data: Data(contentsOf: url), hint: kAudioFileMP3Type)
        decoder.context.setInternalState(to: .waitingForDataAfterSeek)
        let render = AudioPlayerRenderProcessor(playerContext: decoder.context,
            rendererContext: decoder.renderer,
            outputAudioFormat: AVAudioFormat(commonFormat: .pcmFormatFloat32,
                sampleRate: 44_100, channels: 2, interleaved: true)!.basicStreamDescription)
        // More than one second of output requests with no decoded input.
        for _ in 0..<12 { _ = render.inRender(inNumberFrames: 4096) }
        XCTAssertEqual(decoder.context.state.value, .bufferring)
        XCTAssertEqual(decoder.entry.framesPlayed, 0)
    }

    func testSeekMatchesDecodedAudioForCBRAndVBRAndLossless() throws {
        for (name, ext, hint) in [
            ("cbr", "mp3", kAudioFileMP3Type),
            ("vbr", "mp3", kAudioFileMP3Type),
            ("audio", "m4a", kAudioFileM4AType),
            ("audio", "flac", kAudioFileFLACType),
        ] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"))
            let data = try Data(contentsOf: url)
            let baseline = try Decoder(data: data, hint: hint)
            try baseline.feed(data)
            let reference = baseline.samples
            let file = try AVAudioFile(forReading: url)
            XCTAssertEqual(reference.count / 2, Int(file.length), "Valid frame count: \(name).\(ext)")
            let native = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096)!
            try file.read(into: native)
            let nativeLeft = native.floatChannelData![0]
            let baselineRMS = sqrt((0..<Int(native.frameLength)).reduce(0.0) {
                $0 + pow(Double(reference[$1 * 2] - nativeLeft[$1]), 2)
            } / Double(native.frameLength))
            XCTAssertLessThan(baselineRMS, 0.008, "Native file timeline mismatch: \(name).\(ext), RMS \(baselineRMS)")
            let decoder = try Decoder(data: data, hint: hint)
            try decoder.feed(data.prefix(8192))
            // Forward, backward, repeated and fractional-second lyric jumps.
            for target in [4.125, 1.325, 5.425, 0, 2.437, 2.437] {
                decoder.entry.seekRequest.time = target
                decoder.processor.processSeek()
                XCTAssertEqual(decoder.context.state.value, .bufferring)
                try decoder.feed(data.dropFirst(decoder.source.position))
                let actual = Array(decoder.samples.prefix(4096))
                let offset = Int((target * 44_100).rounded()) * 2
                let expected = Array(reference.dropFirst(offset).prefix(actual.count))
                XCTAssertGreaterThan(actual.count, 1000, "\(name) @ \(target)")
                XCTAssertEqual(actual.count, expected.count)
                let rms = sqrt(zip(actual, expected).reduce(0.0) { $0 + pow(Double($1.0 - $1.1), 2) } / Double(max(actual.count, 1)))
                XCTAssertLessThan(rms, 0.008, "\(name).\(ext) @ \(target): RMS \(rms)")
            }
        }
    }
}

private final class MemorySource: CoreAudioStreamSource {
    var position = 0
    let length: Int
    let audioFileHint: AudioFileTypeID
    weak var delegate: AudioStreamSourceDelegate?
    let underlyingQueue = DispatchQueue(label: "seek-test")
    init(length: Int, hint: AudioFileTypeID) { self.length = length; audioFileHint = hint }
    func seek(at offset: Int) { position = offset }
    func close() {}
    func suspend() {}
    func resume() {}
}

private final class Decoder {
    let source: MemorySource
    let context = AudioPlayerContext()
    let renderer: AudioRendererContext
    let entry: AudioEntry
    let processor: AudioFileStreamProcessor
    var failure: AudioPlayerError?

    init(data: Data, hint: AudioFileTypeID) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 2, interleaved: true)!
        source = MemorySource(length: data.count, hint: hint)
        entry = AudioEntry(source: source, entryId: AudioEntryId(id: "fixture"), outputAudioFormat: format)
        renderer = AudioRendererContext(configuration: AudioPlayerConfiguration(bufferSizeInSeconds: 8), outputAudioFormat: format)
        context.audioPlayingEntry = entry
        context.audioReadingEntry = entry
        processor = AudioFileStreamProcessor(playerContext: context, rendererContext: renderer, outputAudioFormat: format.basicStreamDescription)
        processor.fileStreamCallback = { [weak self] effect in
            if case let .raiseError(error) = effect { self?.failure = error }
        }
        XCTAssertEqual(processor.openFileStream(with: hint), noErr)
    }
    deinit { processor.closeFileStreamIfNeeded(); renderer.clean() }
    func feed(_ data: Data) throws {
        let status = processor.parseFileStreamBytes(data: data)
        XCTAssertEqual(status, noErr)
        XCTAssertNil(failure)
        if let stream = processor.audioFileStream { _ = AudioFileStreamParseBytes(stream, 0, nil, []) }
    }
    var samples: [Float] {
        guard let data = renderer.audioBuffer.mData else { return [] }
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: Int(renderer.bufferContext.frameUsedCount) * 2))
    }
}
