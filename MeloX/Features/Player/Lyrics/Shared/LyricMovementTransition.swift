import SwiftUI

enum LyricMovementSpringModel: Equatable, Sendable {
    case durationBounce(usesBounce: Bool, bounce: Double)
    case physical(LyricPhysicalSpringParameters)
}

struct LyricMovementAnimationConfiguration: Equatable {
    let delay: TimeInterval
    let duration: TimeInterval
    let springModel: LyricMovementSpringModel
    let initialVelocity: Double
    let presentationDuration: TimeInterval

    init(
        delay: TimeInterval,
        duration: TimeInterval,
        usesBounce: Bool,
        bounce: Double,
        initialVelocity: Double = 0
    ) {
        self.init(
            delay: delay,
            duration: duration,
            springModel: .durationBounce(
                usesBounce: usesBounce,
                bounce: bounce.isFinite ? bounce : 0
            ),
            initialVelocity: initialVelocity
        )
    }

    init(
        delay: TimeInterval,
        duration: TimeInterval,
        physicalSpring: LyricPhysicalSpringParameters,
        initialVelocity: Double = 0
    ) {
        self.init(
            delay: delay,
            duration: duration,
            springModel: .physical(physicalSpring),
            initialVelocity: initialVelocity
        )
    }

    init(
        delay: TimeInterval,
        duration: TimeInterval,
        springModel: LyricMovementSpringModel,
        initialVelocity: Double = 0
    ) {
        let resolvedDuration = duration.isFinite ? max(duration, 0) : 0
        self.delay = delay.isFinite ? max(delay, 0) : 0
        self.duration = resolvedDuration
        self.springModel = springModel
        let resolvedInitialVelocity = initialVelocity.isFinite
            ? initialVelocity
            : 0
        self.initialVelocity = resolvedInitialVelocity
        switch springModel {
        case .durationBounce:
            presentationDuration = resolvedDuration
        case let .physical(parameters):
            let spring = Spring(
                mass: parameters.mass,
                stiffness: parameters.stiffness,
                damping: parameters.damping,
                allowOverDamping: true
            )
            let settlingDuration = spring.settlingDuration(
                target: 1.0,
                initialVelocity: resolvedInitialVelocity,
                epsilon: 0.001
            )
            presentationDuration = settlingDuration.isFinite
                ? max(settlingDuration, 0)
                : resolvedDuration
        }
    }

    var usesBounce: Bool {
        guard case let .durationBounce(usesBounce, _) = springModel else {
            return false
        }
        return usesBounce
    }

    var bounce: Double {
        guard case let .durationBounce(_, bounce) = springModel else {
            return 0
        }
        return bounce
    }

    var resolvedSpring: Spring {
        switch springModel {
        case let .durationBounce(usesBounce, bounce):
            return usesBounce
                ? Spring(duration: duration, bounce: bounce)
                : .snappy(duration: duration)
        case let .physical(parameters):
            return Spring(
                mass: parameters.mass,
                stiffness: parameters.stiffness,
                damping: parameters.damping,
                allowOverDamping: true
            )
        }
    }

}

struct LyricMovementPresentation: Equatable {
    let offset: CGFloat
    let velocity: CGFloat
}

enum LyricMovementPhase: Equatable {
    case stationary(offset: CGFloat)
    case animated(
        transitionID: UUID,
        initialOffset: CGFloat,
        destinationOffset: CGFloat,
        configuration: LyricMovementAnimationConfiguration,
        startedAt: Date
    )

    var targetOffset: CGFloat {
        switch self {
        case let .stationary(offset):
            offset
        case let .animated(_, _, destinationOffset, _, _):
            destinationOffset
        }
    }

    var isAnimated: Bool {
        if case .animated = self {
            true
        } else {
            false
        }
    }

    func presentation(
        at date: Date
    ) -> LyricMovementPresentation {
        switch self {
        case let .stationary(offset):
            return LyricMovementPresentation(
                offset: offset,
                velocity: 0
            )
        case let .animated(
            _,
            initialOffset,
            destinationOffset,
            configuration,
            startedAt
        ):
            return Self.presentation(
                initialOffset: initialOffset,
                destinationOffset: destinationOffset,
                configuration: configuration,
                elapsed: max(date.timeIntervalSince(startedAt), 0)
            )
        }
    }

    fileprivate static func presentation(
        initialOffset: CGFloat,
        destinationOffset: CGFloat,
        configuration: LyricMovementAnimationConfiguration,
        elapsed: TimeInterval
    ) -> LyricMovementPresentation {
        guard elapsed >= configuration.delay else {
            return LyricMovementPresentation(
                offset: initialOffset,
                velocity: 0
            )
        }
        guard elapsed
                < configuration.delay
                    + configuration.presentationDuration else {
            return LyricMovementPresentation(
                offset: destinationOffset,
                velocity: 0
            )
        }

        let animationElapsed = max(elapsed - configuration.delay, 0)
        let spring = configuration.resolvedSpring
        let progress = spring.value(
            target: 1,
            initialVelocity: configuration.initialVelocity,
            time: animationElapsed
        )
        let progressVelocity = spring.velocity(
            target: 1,
            initialVelocity: configuration.initialVelocity,
            time: animationElapsed
        )
        let distance = destinationOffset - initialOffset
        let offset = initialOffset + distance * CGFloat(progress)
        let velocity = distance * CGFloat(progressVelocity)
        return LyricMovementPresentation(
            offset: offset.isFinite ? offset : destinationOffset,
            velocity: velocity.isFinite ? velocity : 0
        )
    }
}

struct LyricMovementTransition: Equatable {
    let id: UUID
    let focusID: LyricLine.ID
    let initialOffsetsByID: [LyricLine.ID: CGFloat]
    let destinationOffsetsByID: [LyricLine.ID: CGFloat]
    let animationByID: [
        LyricLine.ID: LyricMovementAnimationConfiguration
    ]
    let startedAt: Date?

    init(
        id: UUID = UUID(),
        focusID: LyricLine.ID,
        initialOffsetsByID: [LyricLine.ID: CGFloat],
        destinationOffsetsByID: [LyricLine.ID: CGFloat] = [:],
        animationByID: [
            LyricLine.ID: LyricMovementAnimationConfiguration
        ] = [:],
        startedAt: Date? = nil
    ) {
        self.id = id
        self.focusID = focusID
        self.initialOffsetsByID = initialOffsetsByID
        self.destinationOffsetsByID = destinationOffsetsByID
        self.animationByID = animationByID
        self.startedAt = startedAt
    }

    func starting(
        with animationByID: [
            LyricLine.ID: LyricMovementAnimationConfiguration
        ],
        at date: Date
    ) -> Self {
        let animatedInitialOffsets = initialOffsetsByID.filter {
            animationByID[$0.key] != nil
        }
        let animatedDestinationOffsets = destinationOffsetsByID.filter {
            animationByID[$0.key] != nil
        }
        return Self(
            id: id,
            focusID: focusID,
            initialOffsetsByID: animatedInitialOffsets,
            destinationOffsetsByID: animatedDestinationOffsets,
            animationByID: animationByID,
            startedAt: date
        )
    }

    var completionDuration: TimeInterval {
        animationByID.values.reduce(0) { duration, configuration in
            max(
                duration,
                max(configuration.delay, 0)
                    + max(configuration.presentationDuration, 0)
            )
        }
    }

    func presentationStates(
        at date: Date
    ) -> [LyricLine.ID: LyricMovementPresentation] {
        guard let startedAt else {
            return initialOffsetsByID.mapValues {
                LyricMovementPresentation(offset: $0, velocity: 0)
            }
        }
        let elapsed = max(date.timeIntervalSince(startedAt), 0)
        var animatedIDs = Set(initialOffsetsByID.keys)
        animatedIDs.formUnion(destinationOffsetsByID.keys)
        return animatedIDs.reduce(into: [:]) { states, id in
            let destinationOffset = destinationOffsetsByID[id, default: 0]
            let initialOffset = initialOffsetsByID[
                id,
                default: destinationOffset
            ]
            guard let configuration = animationByID[id] else {
                states[id] = LyricMovementPresentation(
                    offset: initialOffset,
                    velocity: 0
                )
                return
            }
            states[id] = LyricMovementPhase.presentation(
                initialOffset: initialOffset,
                destinationOffset: destinationOffset,
                configuration: configuration,
                elapsed: elapsed
            )
        }
    }

    func phase(
        for id: LyricLine.ID,
        fallbackOffset: CGFloat
    ) -> LyricMovementPhase {
        guard let startedAt,
              let configuration = animationByID[id] else {
            return .stationary(offset: fallbackOffset)
        }
        let destinationOffset = destinationOffsetsByID[id, default: 0]
        let initialOffset = initialOffsetsByID[
            id,
            default: destinationOffset
        ]
        return .animated(
            transitionID: self.id,
            initialOffset: initialOffset,
            destinationOffset: destinationOffset,
            configuration: configuration,
            startedAt: startedAt
        )
    }
}
