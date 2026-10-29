import Foundation
import ReachKit

/// Counts what Reach is used for, per day, for Settings > Usage (S-040).
/// The counts stay on this Mac: the sync folder leaves `usage.` keys out.
@Observable
final class UsageStore {
    static let shared = UsageStore()

    private(set) var log: UsageLog
    /// The clock, which the self-test and seed data set.
    @ObservationIgnored var now: () -> Date = { .now }

    private static let key = "usage.log"

    private init() {
        log = Store.settings.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(UsageLog.self, from: $0) } ?? UsageLog()
    }

    func record(_ kind: UsageKind) {
        log.record(kind, at: now())
        save()
    }

    /// Replaces the counts (seed data and the self-test).
    func replace(with log: UsageLog) {
        self.log = log
        save()
    }

    /// Copy Stats: the summary and the last 28 days as tab-separated lines.
    func statsText() -> String {
        let header = (["Day"] + UsageKind.allCases.map(\.title)).joined(separator: "\t")
        let rows = log.chart(ending: now()).map { day in
            ([day.date.formatted(.iso8601.year().month().day())] + UsageKind.allCases.map { String(day.counts[$0] ?? 0) })
                .joined(separator: "\t")
        }
        return ([summary(), "", header] + rows).joined(separator: "\n")
    }

    /// "Since 1 October 2026: 312 uses, 11 a day on average."
    func summary() -> String {
        guard let since = log.since else { return "Nothing counted yet. Each result, action, clip and snippet you use counts." }
        let average = log.averagePerDay(at: now()).formatted(.number.precision(.fractionLength(0...1)))
        let uses = log.total == 1 ? "1 use" : "\(log.total.formatted()) uses"
        return "Since \(since.formatted(date: .long, time: .omitted)): \(uses), \(average) a day on average."
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(log) else { return }
        Store.settings.set(data, forKey: Self.key)
    }
}
