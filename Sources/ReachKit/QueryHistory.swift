import Foundation

/// The queries typed in the launcher, newest first (S-038). ⌃↑ walks to older
/// ones and ⌃↓ back to newer ones; the last query can come back when the
/// launcher shows again within a few minutes.
public struct QueryHistory: Equatable, Sendable {
    public static let limit = 50
    /// How long the last query stays restorable.
    public static let restoreWindow: TimeInterval = 5 * 60

    public private(set) var queries: [String] = []
    /// When the newest query was added, in the clock the caller uses.
    public private(set) var lastAdded: TimeInterval?
    /// Where ⌃↑/⌃↓ are; nil while the person types their own text.
    public private(set) var position: Int?

    public init(queries: [String] = [], lastAdded: TimeInterval? = nil) {
        self.queries = Array(queries.prefix(Self.limit))
        self.lastAdded = lastAdded
    }

    /// Adds a query at the front. Blank queries are skipped; one typed before moves up.
    public mutating func add(_ query: String, at time: TimeInterval) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        position = nil
        guard !trimmed.isEmpty else { return }
        queries.removeAll { $0 == trimmed }
        queries.insert(trimmed, at: 0)
        if queries.count > Self.limit { queries.removeLast(queries.count - Self.limit) }
        lastAdded = time
    }

    /// ⌃↑: the next older query, or nil at the oldest.
    public mutating func older() -> String? {
        let next = (position ?? -1) + 1
        guard queries.indices.contains(next) else { return nil }
        position = next
        return queries[next]
    }

    /// ⌃↓: the next newer query, "" past the newest, nil when not walking.
    public mutating func newer() -> String? {
        guard let position else { return nil }
        guard position > 0 else {
            self.position = nil
            return ""
        }
        self.position = position - 1
        return queries[position - 1]
    }

    /// Typing ends the walk, so the next ⌃↑ starts from the newest again.
    public mutating func resetWalk() { position = nil }

    /// The query to show when the launcher opens at `time`, if the last one is recent enough.
    public func restorable(at time: TimeInterval) -> String? {
        guard let lastAdded, let newest = queries.first, time - lastAdded <= Self.restoreWindow, time >= lastAdded else {
            return nil
        }
        return newest
    }

    public mutating func clear() {
        queries = []
        lastAdded = nil
        position = nil
    }
}

/// The modifier held with Return for an alternative action (S-038): each
/// runs a web search chosen in Settings > Advanced with the typed text.
public enum ReturnModifier: String, CaseIterable, Identifiable, Sendable {
    case control, option, command

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .control: "⌃↩"
        case .option: "⌥↩"
        case .command: "⌘↩"
        }
    }

    /// The modifier for the keys held, when exactly one of these three is.
    /// `control`, `option`, `command` say which of them are down.
    public static func held(control: Bool, option: Bool, command: Bool) -> ReturnModifier? {
        switch (control, option, command) {
        case (true, false, false): .control
        case (false, true, false): .option
        case (false, false, true): .command
        default: nil
        }
    }

    /// The search mapped to this modifier: its id in `mapping`, if that search still exists.
    public func search(in mapping: [String: String], from searches: [WebSearch]) -> WebSearch? {
        guard let id = mapping[rawValue] else { return nil }
        return searches.first { $0.id == id && $0.takesQuery }
    }
}
