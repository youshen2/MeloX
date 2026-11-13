extension Dictionary {
    /// Like `init(uniqueKeysWithValues:)`, but keeps the first value when a
    /// key repeats instead of trapping. Lyrics data comes from outside the
    /// app, so a repeated id must never crash the player.
    init<S: Sequence>(keepingFirst pairs: S) where S.Element == (Key, Value) {
        self.init(pairs, uniquingKeysWith: { first, _ in first })
    }
}
