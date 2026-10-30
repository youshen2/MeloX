import Observation
import SwiftUI

@MainActor
@Observable
final class DesktopCollectionTrackLocator {
    private(set) var request: Request?
    private(set) var highlightedSongID: Int?

    func locate(_ songID: Int) {
        request = Request(songID: songID)
    }

    func reset() {
        request = nil
        highlightedSongID = nil
    }

    func scroll(using proxy: ScrollViewProxy, reduceMotion: Bool) async {
        guard let request else { return }
        await Task.yield()
        guard !Task.isCancelled else { return }

        highlightedSongID = request.songID
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            proxy.scrollTo(request.songID, anchor: .center)
        }

        try? await Task.sleep(for: .seconds(1.5))
        guard self.request == request else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            highlightedSongID = nil
        }
        self.request = nil
    }

    struct Request: Equatable {
        let songID: Int
        private let id = UUID()
    }
}
