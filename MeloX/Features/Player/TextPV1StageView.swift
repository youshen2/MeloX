import SwiftUI

enum TextPV1Scene: Int, CaseIterable {
    case impactDark
    case editorialWhite
    case aperture
    case wireframe
    case splitScreen
    case verticalColumns
    case targetLock
    case staggeredBands

    var isDark: Bool {
        switch self {
        case .impactDark, .splitScreen, .targetLock: true
        case .editorialWhite, .aperture, .wireframe,
             .verticalColumns, .staggeredBands: false
        }
    }

    var backgroundColor: Color {
        isDark ? Color(white: 0.035) : Color(white: 0.96)
    }

    var foregroundColor: Color {
        isDark ? .white : .black
    }
}

struct TextPV1MotionFrame {
    let entry: CGFloat
    let exit: CGFloat
    let progress: CGFloat
    let pulse: CGFloat
    let phase: CGFloat
    let entryKick: CGFloat
    let entryBounce: CGFloat

    var transitionActivity: CGFloat {
        max(1 - entry, exit)
    }

    init(
        playbackTime: TimeInterval,
        lineStartTime: TimeInterval,
        scheduledDuration: TimeInterval?,
        intensity: CGFloat,
        reducesMotion: Bool
    ) {
        if reducesMotion {
            entry = 1
            exit = 0
            progress = 0.46
            pulse = 0
            phase = 0.8
            entryKick = 0
            entryBounce = 0
            return
        }

        let elapsed = max(playbackTime - lineStartTime, 0)
        let workingDuration = max(scheduledDuration ?? 3.2, 0.12)
        let entryDuration = min(0.72, workingDuration * 0.42)
        let exitDuration = min(0.46, workingDuration * 0.3)
        let rawEntry = Self.clamped(elapsed / max(entryDuration, 0.04))
        let exitStart = max(workingDuration - exitDuration, entryDuration)
        let rawExit: Double
        if scheduledDuration == nil {
            rawExit = 0
        } else {
            rawExit = Self.clamped(
                (elapsed - exitStart)
                    / max(exitDuration, 0.04)
            )
        }

        entry = CGFloat(Self.smoothStep(rawEntry))
        exit = CGFloat(Self.smoothStep(rawExit))
        progress = CGFloat(Self.smoothStep(rawEntry))
        let speed = 7.2 + Double(intensity) * 2.4
        let exitElapsed = scheduledDuration == nil
            ? 0
            : max(elapsed - exitStart, 0)
        let animatedElapsed = min(elapsed, entryDuration) + exitElapsed
        let activity = max(1 - entry, exit)
        phase = CGFloat(animatedElapsed * speed)
        pulse = CGFloat(sin(animatedElapsed * speed)) * activity
        entryKick = CGFloat(sin(rawEntry * .pi)) * (1 - entry)
        entryBounce = CGFloat(
            sin(rawEntry * .pi * 2.5)
                * pow(1 - rawEntry, 1.7)
        )
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func smoothStep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}

struct TextPV1StageView: View {
    let line: LyricLine
    let scene: TextPV1Scene
    let sceneSeed: UInt64
    let isClimax: Bool
    let performsFullEntrance: Bool
    let performsFullExit: Bool
    let playbackTime: TimeInterval
    let lineScheduledDuration: TimeInterval?
    let sceneStartTime: TimeInterval
    let sceneScheduledDuration: TimeInterval?
    let fontScale: CGFloat
    let motionIntensity: CGFloat
    let showsTranslation: Bool
    let reducesMotion: Bool

    var body: some View {
        let lineMotion = TextPV1MotionFrame(
            playbackTime: playbackTime,
            lineStartTime: line.time,
            scheduledDuration: lineScheduledDuration,
            intensity: motionIntensity,
            reducesMotion: reducesMotion
        )
        let sceneMotion = TextPV1MotionFrame(
            playbackTime: playbackTime,
            lineStartTime: sceneStartTime,
            scheduledDuration: sceneScheduledDuration,
            intensity: motionIntensity,
            reducesMotion: reducesMotion
        )
        ZStack {
            TextPV1GeometryLayer(
                scene: scene,
                motion: sceneMotion,
                intensity: motionIntensity,
                seed: sceneSeed
            )

            TextPV1KineticTextLayer(
                text: line.text,
                scene: scene,
                motion: lineMotion,
                fontScale: fontScale,
                intensity: motionIntensity,
                seed: sceneSeed,
                isClimax: isClimax,
                performsFullEntrance: performsFullEntrance,
                performsFullExit: performsFullExit
            )

            if isClimax {
                TextPV1ClimaxTransitionLayer(
                    scene: scene,
                    motion: lineMotion,
                    intensity: motionIntensity,
                    seed: sceneSeed
                )
            }

            if showsTranslation, let translation = line.translation {
                TextPV1TranslationOverlay(
                    text: translation,
                    scene: scene,
                    motion: lineMotion,
                    performsFullEntrance: performsFullEntrance
                )
            }
        }
        .background(scene.backgroundColor)
        .clipped()
    }
}

private struct TextPV1TranslationOverlay: View {
    let text: String
    let scene: TextPV1Scene
    let motion: TextPV1MotionFrame
    let performsFullEntrance: Bool

    var body: some View {
        VStack {
            Spacer()

            Text(verbatim: text)
                .font(.caption.weight(.bold).monospaced())
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .foregroundStyle(scene.backgroundColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(scene.foregroundColor.opacity(0.88), in: .rect)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(
                    x: (1 - motion.entry)
                        * (performsFullEntrance ? 80 : 18)
                        + motion.entryBounce * 8
                )
                .opacity(motion.entry * (1 - motion.exit))
        }
        .padding(12)
    }
}

enum TextPV1StableSeed {
    static func value(for string: String) -> UInt64 {
        string.utf8.reduce(0xcbf29ce484222325) { partial, byte in
            (partial ^ UInt64(byte)) &* 0x100000001b3
        }
    }

    static func unit(_ index: Int, seed: UInt64) -> CGFloat {
        var value = seed &+ UInt64(index &* 0x9E37)
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return CGFloat(value % 10_000) / 9_999
    }
}
