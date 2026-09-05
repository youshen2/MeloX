import CoreImage
import Metal
import MetalKit

/// Renders the same backdrop shader into a fixed-size texture off the main actor.
/// The final native SwiftUI Image only scales that texture to the window.
actor DesktopAppleMusicBackdropRasterizer {
    private var resources: Resources?
    private var artwork: CGImage?
    private var artworkTexture: (any MTLTexture)?
    private var fieldPhaseCount = 0
    private var fieldBuffer: (any MTLBuffer)?
    private var outputTexture: (any MTLTexture)?

    func image(
        artwork: CGImage,
        field: DesktopAppleMusicWarpField,
        size: CGSize,
        time: TimeInterval,
        motionIntensity: Double,
        meshWarpTimeScale: Double,
        blackScrimAlpha: Double,
        usesDarkAppearance: Bool
    ) -> CGImage? {
        guard !Task.isCancelled, size.width > 0, size.height > 0 else { return nil }
        if resources == nil { resources = Resources() }
        guard let resources else { return nil }

        if self.artwork !== artwork {
            artworkTexture = try? MTKTextureLoader(device: resources.device)
                .newTexture(cgImage: artwork, options: [.SRGB: false])
            self.artwork = artwork
        }
        // A surface owns one mesh for its lifetime; the only replacement is
        // the identity field becoming the prepared animation field.
        if fieldBuffer == nil || fieldPhaseCount != field.phaseCount {
            fieldBuffer = field.coordinates.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return nil }
                return resources.device.makeBuffer(
                    bytes: baseAddress,
                    length: bytes.count,
                    options: .storageModeShared
                )
            }
            fieldPhaseCount = field.phaseCount
        }
        let width = Int(size.width), height = Int(size.height)
        if outputTexture?.width != width || outputTexture?.height != height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            outputTexture = resources.device.makeTexture(descriptor: descriptor)
        }
        guard let artworkTexture, let fieldBuffer, let outputTexture,
              let commandBuffer = resources.queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        var parameters: [Float] = [
            Float(width), Float(height),
            Float(DesktopAppleMusicBackdropShader.meshWeight(at: time, timeScale: meshWarpTimeScale)),
            Float(blackScrimAlpha), usesDarkAppearance ? 1 : 0,
            Float(field.dimension), Float(field.phaseCount),
        ]
        parameters += DesktopAppleMusicBackdropShader.rotations(at: time, motionIntensity: motionIntensity)
        encoder.setComputePipelineState(resources.pipeline)
        encoder.setTexture(artworkTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        parameters.withUnsafeBytes { bytes in
            encoder.setBytes(bytes.baseAddress!, length: bytes.count, index: 0)
        }
        encoder.setBuffer(fieldBuffer, offset: 0, index: 1)
        let threadWidth = resources.pipeline.threadExecutionWidth
        let threadHeight = resources.pipeline.maxTotalThreadsPerThreadgroup / threadWidth
        encoder.dispatchThreads(
            MTLSize(width: width, height: height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        // This wait runs on the renderer actor, never on the UI thread. Finish
        // the CGImage before reusing the output texture for the next frame.
        commandBuffer.waitUntilCompleted()
        guard !Task.isCancelled, commandBuffer.status == .completed,
              let image = CIImage(mtlTexture: outputTexture, options: [.colorSpace: resources.colorSpace]) else {
            return nil
        }
        return resources.context.createCGImage(
            image.oriented(.downMirrored),
            from: CGRect(x: 0, y: 0, width: width, height: height),
            format: .RGBA8,
            colorSpace: resources.colorSpace,
            deferred: false
        )
    }

    private struct Resources {
        let device: any MTLDevice
        let queue: any MTLCommandQueue
        let pipeline: any MTLComputePipelineState
        let context: CIContext
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

        init?() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let queue = device.makeCommandQueue(),
                  let function = device.makeDefaultLibrary()?.makeFunction(name: "desktopAppleMusicBackdropFrame"),
                  let pipeline = try? device.makeComputePipelineState(function: function) else {
                return nil
            }
            self.device = device
            self.queue = queue
            self.pipeline = pipeline
            context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        }
    }
}
