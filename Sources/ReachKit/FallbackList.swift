import Foundation

/// When the fallback web searches show (S-018).
public enum FallbackMode: String, CaseIterable, Codable, Sendable {
    case noResults, always

    public var title: String {
        switch self {
        case .noResults: "Only when there are no results"
        case .always: "Always, below the results"
        }
    }
}

/// The fallbacks: web searches by id, in the order people put them (S-018).
public enum FallbackList {
    /// Alfred's: Google, Amazon, Wikipedia.
    public static let standard = ["google", "amazon", "wiki"]

    /// The searches for `ids`, in that order. Searches that are gone, or that
    /// take no words ("Open Gmail"), are left out. Whether a keyword is on does
    /// not matter: Google is a fallback while its keyword is off.
    public static func searches(ids: [String], from all: [WebSearch]) -> [WebSearch] {
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }.filter(\.takesQuery)
    }

    /// What can still be added: every search that takes words and is not in `ids` yet.
    public static func choices(ids: [String], from all: [WebSearch]) -> [WebSearch] {
        all.filter { $0.takesQuery && !ids.contains($0.id) }
    }

    /// How many results and fallbacks show, out of `limit` rows. Fallbacks
    /// below the results keep their rows, so ⌘1–⌘9 still match what is shown.
    public static func split(found: Int, fallbacks: Int, mode: FallbackMode, limit: Int = 9) -> (results: Int, fallbacks: Int) {
        switch mode {
        case .noResults:
            return found == 0 ? (0, min(fallbacks, limit)) : (min(found, limit), 0)
        case .always:
            let shown = min(fallbacks, limit)
            return (min(found, limit - shown), shown)
        }
    }
}
