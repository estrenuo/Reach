import Foundation

/// What Learning remembers about one result for one query.
public struct LearnedPick: Equatable, Sendable {
    public var count: Int
    public var lastUsed: Date

    public init(count: Int, lastUsed: Date) {
        self.count = count
        self.lastUsed = lastUsed
    }
}

/// Orders results by text match plus Learning.
///
/// Text scores from `Matcher` run from about 200 (the letters appear somewhere
/// in the title) to 1000 (the title is the query). Rough bands:
///   1000 exact · 800–900 title starts with the query · 600–700 a word starts
///   with it · 500–600 initials · 400–500 word starts across words · 200–300 inside a word
public enum Ranking {
    public static func order<ID: Hashable>(_ scored: [(id: ID, score: Int)],
                                           learned: [ID: LearnedPick],
                                           now: Date = .now) -> [ID] {
        scored
            .enumerated()
            .map { (offset: $0.offset, id: $0.element.id,
                    total: $0.element.score + learningBoost(learned[$0.element.id], now: now)) }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.offset < $1.offset }
            .map(\.id)
    }

    /// Extra points for a result the user opened before with this query.
    /// Nil means never picked: no boost.
    /// 150 points a pick, counting at most five picks, halved for every 30 days
    /// since the last one. The cap (750) stays under the gap between the weakest
    /// match and an exact title, so typing a full name always wins.
    public static func learningBoost(_ pick: LearnedPick?, now: Date) -> Int {
        guard let pick, pick.count > 0 else { return 0 }
        let days = max(0, now.timeIntervalSince(pick.lastUsed) / 86_400)
        let decay = pow(0.5, days / halfLifeDays)
        return Int((Double(min(pick.count, maxCountedPicks) * pointsPerPick) * decay).rounded())
    }

    static let pointsPerPick = 150
    static let maxCountedPicks = 5
    static let halfLifeDays = 30.0
}
