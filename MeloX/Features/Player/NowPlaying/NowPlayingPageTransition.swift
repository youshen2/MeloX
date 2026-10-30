import SwiftUI

enum NowPlayingPageTransition {
    static let motion = NowPlayingMotionSpec.appleMusic26.page

    static var animation: Animation {
        motion.selection.animation
    }

    static var directLyricsQueueContentScale: CGFloat {
        motion.directAlternateContentScale
    }

    static var lyricsEntranceOffset: CGFloat {
        motion.lyricsTravel
    }

    static var queueOffset: CGFloat {
        motion.queueTravel
    }

    static func content(
        for page: NowPlayingPage,
        entersFromHiddenQueue: Bool,
        reducesMotion: Bool
    ) -> AnyTransition {
        if reducesMotion {
            return .opacity
        }

        if entersFromHiddenQueue {
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            )
        }

        switch page {
        case .artwork:
            return directionalOffsetAndOpacity(
                insertionY: motion.artworkDetailsTravel,
                removalY: motion.artworkDetailsTravel
            )
        case .lyrics:
            return .asymmetric(
                insertion: .opacity,
                removal:
                    offsetAndOpacity(y: lyricsEntranceOffset)
                    .animation(motion.outgoing.animation)
            )
        case .queue:
            return stagedOffsetAndOpacity(y: queueOffset)
        }
    }

    static func songHeader(reducesMotion: Bool) -> AnyTransition {
        guard !reducesMotion else { return .opacity }
        return .asymmetric(
            insertion:
                offsetAndOpacity(y: motion.songHeaderTravel)
                .animation(motion.songHeaderIncoming.animation),
            removal:
                offsetAndOpacity(y: motion.songHeaderTravel)
                .animation(motion.outgoing.animation)
        )
    }

    static func selectionAnimation(
        from source: NowPlayingPage,
        to destination: NowPlayingPage
    ) -> Animation {
        if isDirectLyricsQueueTransition(
            from: source,
            to: destination
        ) {
            return motion.directAlternate.animation
        }
        return animation
    }

    static func residentQueueAnimation(
        from source: NowPlayingPage,
        to destination: NowPlayingPage,
        reducesMotion: Bool
    ) -> Animation? {
        guard !reducesMotion else { return nil }
        if isDirectLyricsQueueTransition(
            from: source,
            to: destination
        ) {
            return motion.directAlternate.animation
        }
        if destination == .queue {
            return motion.delayedResidentEntrance.animation
        }
        if source == .queue {
            return motion.outgoing.animation
        }
        return nil
    }

    static func residentLyricsSpatialAnimation(
        for transition: NowPlayingTransitionContext?,
        reducesMotion: Bool
    ) -> Animation? {
        guard !reducesMotion else { return nil }
        return motion
            .residentLyricsSpatialAnimation(for: transition)?
            .animation
    }

    static func residentLyricsOpacityAnimation(
        for transition: NowPlayingTransitionContext?,
        reducesMotion: Bool
    ) -> Animation? {
        guard !reducesMotion else { return nil }
        return motion
            .residentLyricsOpacityAnimation(for: transition)?
            .animation
    }

    static func isDirectLyricsQueueTransition(
        from source: NowPlayingPage,
        to destination: NowPlayingPage
    ) -> Bool {
        source == .lyrics && destination == .queue
            || source == .queue && destination == .lyrics
    }

    static func directAlternateContent(
        reducesMotion: Bool
    ) -> AnyTransition {
        guard !reducesMotion else { return .opacity }
        return .scale(
            scale: directLyricsQueueContentScale,
            anchor: .center
        )
        .combined(with: .opacity)
    }

    private static func stagedOffsetAndOpacity(
        y: CGFloat
    ) -> AnyTransition {
        directionalOffsetAndOpacity(
            insertionY: y,
            removalY: y
        )
    }

    private static func directionalOffsetAndOpacity(
        insertionY: CGFloat,
        removalY: CGFloat
    ) -> AnyTransition {
        .asymmetric(
            insertion:
                offsetAndOpacity(y: insertionY)
                .animation(motion.incoming.animation),
            removal:
                offsetAndOpacity(y: removalY)
                .animation(motion.outgoing.animation)
        )
    }

    private static func offsetAndOpacity(
        y: CGFloat
    ) -> AnyTransition {
        .offset(y: y).combined(with: .opacity)
    }
}
