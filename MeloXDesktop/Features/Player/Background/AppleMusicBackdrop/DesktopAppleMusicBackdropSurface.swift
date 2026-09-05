import AppKit
import SwiftUI

/// Presents completed background frames using a native Image. One cancellable
/// producer owns each artwork surface, so slow frames never queue behind input.
struct DesktopAppleMusicBackdropSurface: View {
    struct Configuration: Equatable {
        let size: CGSize
        let motionIntensity: Double
        let meshWarpTimeScale: Double
        let blackScrimAlpha: Double
        let usesDarkAppearance: Bool
        let clock: DesktopAppleMusicBackdropClock
        let isRunning: Bool
        let frameInterval: TimeInterval
    }

    let artwork: NSImage
    let warpField: DesktopAppleMusicWarpField
    let configuration: Configuration

    @State private var rasterizer = DesktopAppleMusicBackdropRasterizer()
    @State private var frame: CGImage?

    var body: some View {
        Group {
            if let frame {
                Image(decorative: frame, scale: 1)
                    .resizable()
                    .interpolation(.medium)
            } else {
                Color(white: 0.30)
            }
        }
        .task(id: RenderIdentity(
            artwork: ObjectIdentifier(artwork),
            phaseCount: warpField.phaseCount,
            configuration: configuration
        )) {
            guard let source = artwork.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return
            }
            repeat {
                let startedAt = ContinuousClock.now
                let rendered = await rasterizer.image(
                    artwork: source,
                    field: warpField,
                    size: configuration.size,
                    time: configuration.clock.elapsed(at: Date()),
                    motionIntensity: configuration.motionIntensity,
                    meshWarpTimeScale: configuration.meshWarpTimeScale,
                    blackScrimAlpha: configuration.blackScrimAlpha,
                    usesDarkAppearance: configuration.usesDarkAppearance
                )
                guard !Task.isCancelled, let rendered else { return }
                frame = rendered
                guard configuration.isRunning else { return }
                do {
                    try await Task.sleep(
                        until: startedAt.advanced(by: .seconds(configuration.frameInterval)),
                        clock: .continuous
                    )
                } catch {
                    return
                }
            } while !Task.isCancelled
        }
    }

    private struct RenderIdentity: Equatable {
        let artwork: ObjectIdentifier
        let phaseCount: Int
        let configuration: Configuration
    }
}
