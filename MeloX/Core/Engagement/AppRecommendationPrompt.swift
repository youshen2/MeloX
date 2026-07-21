import Foundation

enum AppRecommendationPrompt {
    private enum Key {
        static let launchCount = "appRecommendation.launchCount"
        static let hasPresentedPrompt = "appRecommendation.hasPresentedPrompt"
    }

    static let launchThreshold = 5

    static func recordLaunch(defaults: UserDefaults = .standard) -> Bool {
        guard !defaults.bool(forKey: Key.hasPresentedPrompt) else {
            return false
        }

        let currentCount = max(defaults.integer(forKey: Key.launchCount), 0)
        let launchCount = min(currentCount + 1, launchThreshold)
        defaults.set(launchCount, forKey: Key.launchCount)

        guard launchCount >= launchThreshold else { return false }

        defaults.set(true, forKey: Key.hasPresentedPrompt)
        return true
    }
}
