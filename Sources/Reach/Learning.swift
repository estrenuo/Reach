import Foundation
import ReachKit
import SwiftData

/// Learning: remembers which result was opened for which query (S-004).
/// Lives in the app's database, so it survives a restart.
final class Learning {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// Queries are stored lowercased and trimmed, so "Saf" and "saf " count as one.
    static func key(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    func picks(for query: String) -> [String: LearnedPick] {
        let key = Self.key(query)
        let entries = (try? container.mainContext.fetch(
            FetchDescriptor<LearningEntry>(predicate: #Predicate { $0.query == key }))) ?? []
        return Dictionary(entries.map { ($0.resultID, LearnedPick(count: $0.count, lastUsed: $0.lastUsed)) },
                          uniquingKeysWith: { first, _ in first })
    }

    func record(query: String, resultID: String) {
        let key = Self.key(query)
        guard !key.isEmpty else { return }
        let context = container.mainContext
        let existing = try? context.fetch(FetchDescriptor<LearningEntry>(
            predicate: #Predicate { $0.query == key && $0.resultID == resultID })).first
        let entry = existing ?? LearningEntry(query: key, resultID: resultID)
        if existing == nil { context.insert(entry) }
        entry.count += 1
        entry.lastUsed = .now
        try? context.save()
    }
}
