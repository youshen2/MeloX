import AVFoundation
import MediaToolbox

nonisolated final class AudioEqualizerProcessor {
    private let sharedConfiguration: SharedAudioEqualizerConfiguration

    init(configuration: AudioEqualizerConfiguration) {
        sharedConfiguration = SharedAudioEqualizerConfiguration(
            configuration: configuration
        )
    }

    @MainActor
    func update(configuration: AudioEqualizerConfiguration) {
        sharedConfiguration.update(configuration)
    }

    func makeAudioMix(for track: AVAssetTrack) -> AVAudioMix? {
        let context = AudioEqualizerTapContext(
            sharedConfiguration: sharedConfiguration
        )
        let retainedContext = Unmanaged.passRetained(context)

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: retainedContext.toOpaque(),
            init: audioEqualizerTapInit,
            finalize: audioEqualizerTapFinalize,
            prepare: audioEqualizerTapPrepare,
            unprepare: audioEqualizerTapUnprepare,
            process: audioEqualizerTapProcess
        )
        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tap
        )

        guard status == noErr, let tap else {
            retainedContext.release()
            return nil
        }

        let inputParameters = AVMutableAudioMixInputParameters(track: track)
        inputParameters.audioTapProcessor = tap

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [inputParameters]
        return audioMix
    }
}

nonisolated private func audioEqualizerTapContext(
    for tap: MTAudioProcessingTap
) -> AudioEqualizerTapContext {
    Unmanaged<AudioEqualizerTapContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()
}

nonisolated private func audioEqualizerTapInit(
    _ tap: MTAudioProcessingTap,
    _ clientInfo: UnsafeMutableRawPointer?,
    _ tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    tapStorageOut.pointee = clientInfo
}

nonisolated private func audioEqualizerTapFinalize(
    _ tap: MTAudioProcessingTap
) {
    Unmanaged<AudioEqualizerTapContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .release()
}

nonisolated private func audioEqualizerTapPrepare(
    _ tap: MTAudioProcessingTap,
    _ maxFrames: CMItemCount,
    _ processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    audioEqualizerTapContext(for: tap).prepare(
        format: processingFormat.pointee
    )
}

nonisolated private func audioEqualizerTapUnprepare(
    _ tap: MTAudioProcessingTap
) {
    audioEqualizerTapContext(for: tap).unprepare()
}

nonisolated private func audioEqualizerTapProcess(
    _ tap: MTAudioProcessingTap,
    _ numberFrames: CMItemCount,
    _ flags: MTAudioProcessingTapFlags,
    _ bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    _ numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    _ flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    var sourceFlags: MTAudioProcessingTapFlags = 0
    var providedFrames: CMItemCount = 0
    let status = MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferListInOut,
        &sourceFlags,
        nil,
        &providedFrames
    )

    numberFramesOut.pointee = providedFrames
    flagsOut.pointee = sourceFlags
    guard status == noErr, providedFrames > 0 else { return }

    audioEqualizerTapContext(for: tap).process(
        bufferList: bufferListInOut,
        frameCount: providedFrames,
        flags: sourceFlags
    )
}
