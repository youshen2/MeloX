import SwiftUI

struct LyricFocusColorTransition: Equatable, Identifiable {
    enum TimingCurve: Equatable {
        case smoothStep
        case cubicBezier(
            controlPoint1X: CGFloat,
            controlPoint1Y: CGFloat,
            controlPoint2X: CGFloat,
            controlPoint2Y: CGFloat
        )
        case physicalSpring(LyricPhysicalSpringParameters)
    }

    let id: UUID
    let initialColorProgressByID: [LyricLine.ID: CGFloat]
    /// Absolute focus-progress velocity in progress units per second.
    let initialColorVelocityByID: [LyricLine.ID: CGFloat]
    let initialBlurProgressByID: [LyricLine.ID: CGFloat]
    let destinationLyricID: LyricLine.ID?
    let startedAt: Date
    let colorDuration: TimeInterval
    let blurDuration: TimeInterval
    let colorTimingCurve: TimingCurve
    let blurTimingCurve: TimingCurve

    init(
        id: UUID = UUID(),
        initialColorProgressByID: [LyricLine.ID: CGFloat],
        initialColorVelocityByID: [LyricLine.ID: CGFloat],
        initialBlurProgressByID: [LyricLine.ID: CGFloat],
        destinationLyricID: LyricLine.ID?,
        startedAt: Date,
        colorDuration: TimeInterval,
        blurDuration: TimeInterval,
        colorTimingCurve: TimingCurve,
        blurTimingCurve: TimingCurve
    ) {
        self.id = id
        self.initialColorProgressByID = initialColorProgressByID.mapValues {
            Self.unitProgress($0)
        }
        self.initialColorVelocityByID =
            initialColorVelocityByID.mapValues {
                $0.isFinite ? $0 : 0
            }
        self.initialBlurProgressByID = initialBlurProgressByID.mapValues {
            Self.unitProgress($0)
        }
        self.destinationLyricID = destinationLyricID
        self.startedAt = startedAt
        self.colorDuration = colorDuration.isFinite
            ? max(colorDuration, 0)
            : 0
        self.blurDuration = blurDuration.isFinite
            ? max(blurDuration, 0)
            : 0
        self.colorTimingCurve = colorTimingCurve
        self.blurTimingCurve = blurTimingCurve
    }

    var completionDate: Date {
        startedAt.addingTimeInterval(max(colorDuration, blurDuration))
    }

    static func settlingDuration(
        initialProgressByID: [LyricLine.ID: CGFloat],
        initialVelocityByID: [LyricLine.ID: CGFloat],
        destinationLyricID: LyricLine.ID?,
        parameters: LyricPhysicalSpringParameters
    ) -> TimeInterval {
        let spring = Spring(
            mass: parameters.mass,
            stiffness: parameters.stiffness,
            damping: parameters.damping,
            allowOverDamping: true
        )
        var lyricIDs = Set(initialProgressByID.keys)
        lyricIDs.formUnion(initialVelocityByID.keys)
        if let destinationLyricID {
            lyricIDs.insert(destinationLyricID)
        }
        return lyricIDs.reduce(0) { maximumDuration, lyricID in
            let start = Double(initialProgressByID[lyricID, default: 0])
            let target = lyricID == destinationLyricID ? 1.0 : 0.0
            let velocity = Double(
                initialVelocityByID[lyricID, default: 0]
            )
            let duration = spring.settlingDuration(
                fromValue: start,
                toValue: target,
                initialVelocity: velocity,
                epsilon: 0.001
            )
            guard duration.isFinite else { return maximumDuration }
            return max(maximumDuration, max(duration, 0))
        }
    }

    func includes(_ lyricID: LyricLine.ID) -> Bool {
        initialColorProgressByID[lyricID] != nil
            || initialColorVelocityByID[lyricID] != nil
            || initialBlurProgressByID[lyricID] != nil
            || destinationLyricID == lyricID
    }

    func colorProgress(
        for lyricID: LyricLine.ID,
        at date: Date
    ) -> CGFloat {
        colorPresentation(for: lyricID, at: date).progress
    }

    private func colorPresentation(
        for lyricID: LyricLine.ID,
        at date: Date
    ) -> LyricFocusColorPresentation {
        guard case let .physicalSpring(parameters) = colorTimingCurve else {
            return LyricFocusColorPresentation(
                progress: progress(
                    for: lyricID,
                    initialProgressByID: initialColorProgressByID,
                    timingCurve: colorTimingCurve,
                    duration: colorDuration,
                    at: date
                ),
                velocity: 0
            )
        }

        let initialProgress =
            initialColorProgressByID[lyricID, default: 0]
        let destinationProgress: CGFloat =
            destinationLyricID == lyricID ? 1 : 0
        let elapsed = max(date.timeIntervalSince(startedAt), 0)
        guard colorDuration > 0, elapsed < colorDuration else {
            return LyricFocusColorPresentation(
                progress: destinationProgress,
                velocity: 0
            )
        }
        let spring = Spring(
            mass: parameters.mass,
            stiffness: parameters.stiffness,
            damping: parameters.damping,
            allowOverDamping: true
        )
        let start = Double(initialProgress)
        let target = Double(destinationProgress)
        let initialVelocity = Double(
            initialColorVelocityByID[lyricID, default: 0]
        )
        let rawProgress: Double = spring.value(
            fromValue: start,
            toValue: target,
            initialVelocity: initialVelocity,
            time: elapsed
        )
        // The absolute from/to overload returns progress units per second.
        // Carry it directly so an interrupted spring remains C1-continuous.
        let rawVelocity: Double = spring.velocity(
            fromValue: start,
            toValue: target,
            initialVelocity: initialVelocity,
            time: elapsed
        )
        let progress = Self.unitProgress(CGFloat(rawProgress))
        let velocity: CGFloat
        if rawProgress.isFinite,
           rawVelocity.isFinite,
           Double(progress) == rawProgress {
            velocity = CGFloat(rawVelocity)
        } else {
            velocity = 0
        }
        return LyricFocusColorPresentation(
            progress: progress,
            velocity: velocity
        )
    }

    func blurProgress(
        for lyricID: LyricLine.ID,
        at date: Date
    ) -> CGFloat {
        progress(
            for: lyricID,
            initialProgressByID: initialBlurProgressByID,
            timingCurve: blurTimingCurve,
            duration: blurDuration,
            at: date
        )
    }

    private func progress(
        for lyricID: LyricLine.ID,
        initialProgressByID: [LyricLine.ID: CGFloat],
        timingCurve: TimingCurve,
        duration: TimeInterval,
        at date: Date
    ) -> CGFloat {
        let initialProgress = initialProgressByID[lyricID, default: 0]
        let destinationProgress: CGFloat =
            destinationLyricID == lyricID ? 1 : 0
        let progress = easedProgress(
            at: date,
            duration: duration,
            timingCurve: timingCurve
        )
        return Self.unitProgress(
            initialProgress
                + (destinationProgress - initialProgress) * progress
        )
    }

    func presentationColorProgressByID(
        at date: Date
    ) -> [LyricLine.ID: CGFloat] {
        presentationProgressByID(at: date, usesBlurProgress: false)
    }

    func presentationColorVelocityByID(
        at date: Date
    ) -> [LyricLine.ID: CGFloat] {
        var lyricIDs = Set(initialColorProgressByID.keys)
        lyricIDs.formUnion(initialColorVelocityByID.keys)
        if let destinationLyricID {
            lyricIDs.insert(destinationLyricID)
        }
        return lyricIDs.reduce(into: [:]) { velocityByID, lyricID in
            let velocity = colorPresentation(
                for: lyricID,
                at: date
            ).velocity
            if velocity != 0 {
                velocityByID[lyricID] = velocity
            }
        }
    }

    func presentationBlurProgressByID(
        at date: Date
    ) -> [LyricLine.ID: CGFloat] {
        presentationProgressByID(at: date, usesBlurProgress: true)
    }

    private func presentationProgressByID(
        at date: Date,
        usesBlurProgress: Bool
    ) -> [LyricLine.ID: CGFloat] {
        var lyricIDs = Set(
            usesBlurProgress
                ? initialBlurProgressByID.keys
                : initialColorProgressByID.keys
        )
        if !usesBlurProgress {
            lyricIDs.formUnion(initialColorVelocityByID.keys)
        }
        if let destinationLyricID {
            lyricIDs.insert(destinationLyricID)
        }
        return lyricIDs.reduce(into: [:]) { progressByID, lyricID in
            let progress = usesBlurProgress
                ? blurProgress(for: lyricID, at: date)
                : colorProgress(for: lyricID, at: date)
            if progress > 0 {
                progressByID[lyricID] = progress
            }
        }
    }

    private func easedProgress(
        at date: Date,
        duration: TimeInterval,
        timingCurve: TimingCurve
    ) -> CGFloat {
        guard duration > 0 else { return 1 }
        let elapsed = max(date.timeIntervalSince(startedAt), 0)
        if elapsed >= duration {
            return 1
        }
        let linearProgress = Self.unitProgress(
            CGFloat(elapsed / duration)
        )
        switch timingCurve {
        case .smoothStep:
            return linearProgress * linearProgress
                * (3 - 2 * linearProgress)
        case let .cubicBezier(
            controlPoint1X,
            controlPoint1Y,
            controlPoint2X,
            controlPoint2Y
        ):
            return Self.cubicBezierProgress(
                linearProgress,
                controlPoint1X: controlPoint1X,
                controlPoint1Y: controlPoint1Y,
                controlPoint2X: controlPoint2X,
                controlPoint2Y: controlPoint2Y
            )
        case .physicalSpring:
            return linearProgress
        }
    }

    /// Core Animation cubic timing functions map elapsed time on the x-axis
    /// to presentation progress on the y-axis. Invert x with a bounded binary
    /// search so interrupted focus changes can still be sampled exactly.
    private static func cubicBezierProgress(
        _ linearProgress: CGFloat,
        controlPoint1X: CGFloat,
        controlPoint1Y: CGFloat,
        controlPoint2X: CGFloat,
        controlPoint2Y: CGFloat
    ) -> CGFloat {
        let progress = unitProgress(linearProgress)
        guard progress > 0 else { return 0 }
        guard progress < 1 else { return 1 }
        var lowerBound: CGFloat = 0
        var upperBound: CGFloat = 1
        for _ in 0..<16 {
            let parameter = (lowerBound + upperBound) * 0.5
            let x = cubicBezierCoordinate(
                parameter,
                firstControlPoint: controlPoint1X,
                secondControlPoint: controlPoint2X
            )
            if x < progress {
                lowerBound = parameter
            } else {
                upperBound = parameter
            }
        }
        return unitProgress(
            cubicBezierCoordinate(
                (lowerBound + upperBound) * 0.5,
                firstControlPoint: controlPoint1Y,
                secondControlPoint: controlPoint2Y
            )
        )
    }

    private static func cubicBezierCoordinate(
        _ parameter: CGFloat,
        firstControlPoint: CGFloat,
        secondControlPoint: CGFloat
    ) -> CGFloat {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * parameter * firstControlPoint
            + 3 * inverse * parameter * parameter * secondControlPoint
            + parameter * parameter * parameter
    }

    private static func unitProgress(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

private struct LyricFocusColorPresentation {
    let progress: CGFloat
    let velocity: CGFloat
}

struct LyricFocusVisualProgress: Equatable {
    let color: CGFloat
    let blur: CGFloat
}
