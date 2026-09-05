import Combine
import Foundation
import SwiftUI

/// Uses one shader pass over a cached, blurred artwork texture.
/// Mesh inversion is prepared off the main actor; each display frame samples
/// that field and three rotating artwork layers into a bounded pixel surface.
struct DesktopAppleMusicBackdropView: View {
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale

    let artworkURL: URL?
    let motionIntensity: Double
    let renderQuality: PlayerBackgroundRenderQuality
    let isActive: Bool
    let isPlaying: Bool

    @State private var clock = DesktopAppleMusicBackdropClock()
    @State private var meshIndex =
        DesktopAppleMusicPinchMeshStore.randomIndex()
    @State private var warpField = DesktopAppleMusicWarpField.identity
    @State private var isLowPowerModeEnabled =
        ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var thermalState =
        ProcessInfo.processInfo.thermalState

    private static let standardRenderDimension: CGFloat = 960
    private static let lowPowerRenderDimension: CGFloat = 640

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let renderSize = renderSize(for: size)
            DesktopAppleMusicBackdropArtwork(
                artworkURL: artworkURL,
                blurRadius: bakedBlurRadius(for: size)
            ) { image in
                Group {
                    if renderQuality == .high {
                        TimelineView(
                            .animation(minimumInterval: frameInterval, paused: !isClockRunning)
                        ) { context in
                            Color.white.colorEffect(
                                DesktopAppleMusicBackdropShader.backdrop(
                                    artwork: Image(nsImage: image),
                                    size: size,
                                    time: clock.elapsed(at: context.date),
                                    motionIntensity: motionIntensity,
                                    meshWarpTimeScale: meshWarpTimeScale(for: size.width),
                                    blackScrimAlpha: scrimAlpha(for: size.width),
                                    usesDarkAppearance: colorScheme == .dark,
                                    warpField: warpField
                                )
                            )
                        }
                    } else {
                        DesktopAppleMusicBackdropSurface(
                            artwork: image,
                            warpField: warpField,
                            configuration: .init(
                                size: renderSize,
                                motionIntensity: motionIntensity,
                                meshWarpTimeScale: meshWarpTimeScale(for: size.width),
                                blackScrimAlpha: scrimAlpha(for: size.width),
                                usesDarkAppearance: colorScheme == .dark,
                                clock: clock,
                                isRunning: isClockRunning,
                                frameInterval: frameInterval
                            )
                        )
                    }
                }
                .frame(width: size.width, height: size.height)
                .opacity(warpField.phaseCount > 1 ? 1 : 0)
                .animation(
                    accessibilityReduceMotion ? nil : .easeInOut(duration: 0.35),
                    value: warpField.phaseCount > 1
                )
            }
            .frame(width: size.width, height: size.height)
            .background(Color(white: 0.30))
            .clipped()
        }
        .task(id: meshIndex) {
            let mesh = DesktopAppleMusicPinchMeshStore.mesh(at: meshIndex)
            let field = await DesktopAppleMusicWarpFieldCache.shared.field(for: mesh)
            guard !Task.isCancelled else { return }
            warpField = field
        }
        .onChange(of: isClockRunning, initial: true) { _, isRunning in
            clock.setRunning(isRunning, at: Date())
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .NSProcessInfoPowerStateDidChange
            )
        ) { _ in
            isLowPowerModeEnabled =
                ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "NSProcessInfoThermalStateDidChangeNotification"
                )
            )
        ) { _ in
            thermalState = ProcessInfo.processInfo.thermalState
        }
    }

    private var isClockRunning: Bool {
        warpField.phaseCount > 1
            && isActive
            && scenePhase == .active
            && isPlaying
            && !accessibilityReduceMotion
    }

    private var frameInterval: TimeInterval {
        if isLowPowerModeEnabled {
            return 1.0 / 30.0
        }
        switch thermalState {
        case .serious:
            return 1.0 / 30.0
        case .critical:
            return 1.0 / 20.0
        case .nominal, .fair:
            return 1.0 / 60.0
        @unknown default:
            return 1.0 / 60.0
        }
    }

    private func renderSize(for size: CGSize) -> CGSize {
        guard let renderDimension = resolvedRenderDimension else {
            return size
        }
        let pixelWidth = size.width * displayScale
        let pixelHeight = size.height * displayScale
        let maximumDimension = max(pixelWidth, pixelHeight)
        guard maximumDimension > 0 else { return .zero }
        let downscale = min(renderDimension / maximumDimension, 1)
        return CGSize(
            width: max((pixelWidth * downscale).rounded(.down), 1),
            height: max((pixelHeight * downscale).rounded(.down), 1)
        )
    }

    private var resolvedRenderDimension: CGFloat? {
        switch renderQuality {
        case .automatic:
            if isLowPowerModeEnabled
                || thermalState == .critical {
                return Self.lowPowerRenderDimension
            }
            return Self.standardRenderDimension
        case .high:
            return nil
        case .standard:
            return Self.standardRenderDimension
        case .low:
            return Self.lowPowerRenderDimension
        }
    }

    private func scrimAlpha(for width: CGFloat) -> Double {
        let progress = min(max((width - 400) / 400, 0), 1)
        return 0.7 - 0.4 * Double(progress)
    }

    private func meshWarpTimeScale(for width: CGFloat) -> Double {
        let progress = min(max((width - 400) / 400, 0), 1)
        return min(max(10.5 - 9 * Double(progress), 0.1), 10)
    }

    private func blurSigma(for size: CGSize) -> CGFloat {
        let sigma = floor(hypot(size.width, size.height) * 0.045_394_707)
        return min(max(sigma, 4), 2_000)
    }

    /// Blur in source pixels, independent of the window's backing scale.
    /// All quality levels share the baked source; quality controls the final
    /// render resolution, including native resolution for the high setting.
    private func bakedBlurRadius(for renderSize: CGSize) -> Double {
        let sourcePixels = isLowPowerModeEnabled
            ? DesktopArtworkBackdropRenderer.lowPowerPixelSize
            : DesktopArtworkBackdropRenderer.standardPixelSize
        let artworkSide = max(renderSize.width, renderSize.height, 1)
        return (Double(blurSigma(for: renderSize)) * Double(sourcePixels)
            / artworkSide).rounded()
    }
}
