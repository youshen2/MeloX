import Foundation

struct LyricSyllable: Identifiable, Hashable, Sendable {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval

    var id: String {
        "\(startTime)-\(endTime)-\(text)"
    }
}

enum LyricLineTimingKind: Hashable, Sendable {
    /// The line carries an authored content duration, usually from YRC.
    case precise

    /// LRC only tells us when this line is replaced by the next one. Its
    /// inferred display duration must not be treated as sung-content timing.
    case lineSynchronized
}

enum LyricAgentAlignment: Hashable, Sendable {
    case normal
    case flipped
}

enum LyricAgentKind: Hashable, Sendable {
    case person
    case group
}

struct LyricAgent: Hashable, Sendable {
    let identifier: String
    let displayName: String
    let kind: LyricAgentKind
    let alignment: LyricAgentAlignment
}

enum LyricVocalistsType: Hashable, Sendable {
    case single
    case duet
    case group

    static func resolve(in lines: [LyricLine]) -> LyricVocalistsType {
        let agents = lines.compactMap(\.agent)
        let personIdentifiers = Set(
            agents
                .filter { $0.kind == .person }
                .map(\.identifier)
        )
        if agents.contains(where: { $0.kind == .group })
            || personIdentifiers.count > 2 {
            return .group
        }
        return personIdentifiers.count == 2 ? .duet : .single
    }
}

enum LyricBackgroundVocalsPosition: Hashable, Sendable {
    case beforePrimary
    case afterPrimary
}

struct LyricBackgroundVocal: Hashable, Sendable {
    let time: TimeInterval
    let duration: TimeInterval?
    let text: String
    let syllables: [LyricSyllable]
    let translation: String?
    let position: LyricBackgroundVocalsPosition

    func lyricLine(
        parentID: LyricLine.ID,
        agent: LyricAgent?
    ) -> LyricLine {
        LyricLine(
            id: "\(parentID):background-vocal",
            time: time,
            duration: duration,
            text: text,
            syllables: syllables,
            translation: translation,
            agent: agent
        )
    }
}

struct LyricLine: Identifiable, Hashable, Sendable {
    let id: String
    let time: TimeInterval
    let duration: TimeInterval?
    let timingKind: LyricLineTimingKind
    let text: String
    let syllables: [LyricSyllable]
    let romanization: String?
    let romanizationSyllables: [LyricSyllable]
    let translation: String?
    let agent: LyricAgent?
    let backgroundVocal: LyricBackgroundVocal?

    init(
        id: String? = nil,
        time: TimeInterval,
        duration: TimeInterval? = nil,
        timingKind: LyricLineTimingKind = .precise,
        text: String,
        syllables: [LyricSyllable] = [],
        romanization: String? = nil,
        romanizationSyllables: [LyricSyllable] = [],
        translation: String? = nil,
        agent: LyricAgent? = nil,
        backgroundVocal: LyricBackgroundVocal? = nil
    ) {
        self.id = id ?? Self.fallbackID(
            time: time,
            text: text
        )
        self.time = time
        self.duration = duration
        self.timingKind = timingKind
        self.text = text
        self.syllables = syllables
        self.romanization = romanization
        self.romanizationSyllables = romanizationSyllables
        self.translation = translation
        self.agent = agent
        self.backgroundVocal = backgroundVocal
    }

    init(
        id: String,
        copying line: LyricLine
    ) {
        self.init(
            id: id,
            time: line.time,
            duration: line.duration,
            timingKind: line.timingKind,
            text: line.text,
            syllables: line.syllables,
            romanization: line.romanization,
            romanizationSyllables: line.romanizationSyllables,
            translation: line.translation,
            agent: line.agent,
            backgroundVocal: line.backgroundVocal
        )
    }

    var isSyllableSynced: Bool {
        !syllables.isEmpty
    }

    static func fallbackID(
        time: TimeInterval,
        text: String
    ) -> String {
        "line:\(time.bitPattern):\(Self.stableTextHash(text))"
    }

    static func stableTextHash(_ text: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    var hasTranslation: Bool {
        guard let translation else { return false }
        return !translation
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var hasRomanization: Bool {
        guard let romanization else { return false }
        return !romanization
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    func makePseudoSyllables() -> [LyricSyllable] {
        guard syllables.isEmpty,
              let duration,
              duration > 0 else { return [] }

        let characters = Array(text)
        guard !characters.isEmpty else { return [] }

        let characterDuration = duration / Double(characters.count)
        return characters.enumerated().map { index, character in
            let startTime = time + Double(index) * characterDuration
            return LyricSyllable(
                text: String(character),
                startTime: startTime,
                endTime: startTime + characterDuration
            )
        }
    }

    func attachingTranslation(_ translation: String?) -> LyricLine {
        LyricLine(
            id: id,
            time: time,
            duration: duration,
            timingKind: timingKind,
            text: text,
            syllables: syllables,
            romanization: romanization,
            romanizationSyllables: romanizationSyllables,
            translation: translation,
            agent: agent,
            backgroundVocal: backgroundVocal
        )
    }

    func attachingRomanization(
        _ romanization: String?,
        romanizationSyllables: [LyricSyllable] = []
    ) -> LyricLine {
        LyricLine(
            id: id,
            time: time,
            duration: duration,
            timingKind: timingKind,
            text: text,
            syllables: syllables,
            romanization: romanization,
            romanizationSyllables: romanizationSyllables,
            translation: translation,
            agent: agent,
            backgroundVocal: backgroundVocal
        )
    }

    func attachingAgent(
        _ agent: LyricAgent?,
        text: String? = nil,
        syllables: [LyricSyllable]? = nil
    ) -> LyricLine {
        LyricLine(
            id: id,
            time: time,
            duration: duration,
            timingKind: timingKind,
            text: text ?? self.text,
            syllables: syllables ?? self.syllables,
            romanization: romanization,
            romanizationSyllables: romanizationSyllables,
            translation: translation,
            agent: agent,
            backgroundVocal: backgroundVocal
        )
    }

    func accessibilityText(
        includingTranslation: Bool,
        includingRomanization: Bool = false
    ) -> String {
        var components = [text]
        if includingRomanization, hasRomanization,
           let romanization {
            components.append(L10n.format("ui.lyrics.accessibility.romanization", romanization))
        }
        if includingTranslation, hasTranslation,
           let translation {
            components.append(L10n.format("ui.lyrics.accessibility.translation", translation))
        }
        if let backgroundVocal {
            components.append(backgroundVocal.text)
            if includingTranslation,
               let translation = backgroundVocal.translation {
                components.append(
                    L10n.format(
                        "ui.lyrics.accessibility.translation",
                        translation
                    )
                )
            }
        }
        return components.joined(separator: L10n.string("ui.common.spoken_separator"))
    }
}

extension Array where Element == LyricLine {
    /// Keeps the first line's id and gives any later line that repeats it a
    /// `#n` suffix, so lyrics with the same text at the same time (repeated
    /// LRC tags, merged sources, duplicated TTML spans) stay distinct.
    func withUniqueIDs() -> [LyricLine] {
        var seen = Set<LyricLine.ID>()
        seen.reserveCapacity(count)
        return map { line in
            guard !seen.insert(line.id).inserted else { return line }
            var suffix = 1
            var candidate = "\(line.id)#\(suffix)"
            while !seen.insert(candidate).inserted {
                suffix += 1
                candidate = "\(line.id)#\(suffix)"
            }
            return LyricLine(id: candidate, copying: line)
        }
    }
}

extension Dictionary {
    /// Like `init(uniqueKeysWithValues:)`, but keeps the first value when a
    /// key repeats instead of trapping. Lyrics data comes from outside the
    /// app, so a repeated id must never crash the player.
    init<S: Sequence>(keepingFirst pairs: S) where S.Element == (Key, Value) {
        self.init(pairs, uniquingKeysWith: { first, _ in first })
    }
}
