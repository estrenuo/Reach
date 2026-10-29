import Foundation

/// What a use of Reach was, for the Usage page (S-040).
public enum UsageKind: String, CaseIterable, Codable, Sendable, Identifiable {
    /// A result opened from the launcher.
    case launcher
    /// An action run from the action panel.
    case actions
    /// A clip pasted or copied from the clipboard history.
    case clipboard
    /// A snippet pasted from the launcher or the viewer.
    case snippets
    /// A snippet keyword expanded while typing.
    case expansion

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .launcher: "Launcher"
        case .actions: "Actions"
        case .clipboard: "Clipboard"
        case .snippets: "Snippets"
        case .expansion: "Expansion"
        }
    }
}

/// How often each kind of use happened, counted per day (S-040).
public struct UsageLog: Codable, Equatable, Sendable {
    /// Days older than this are dropped, so the log stays small.
    public static let keptDays = 400

    /// "2026-10-29" → kind → count.
    public private(set) var days: [String: [UsageKind: Int]] = [:]
    /// The first day anything was counted.
    public private(set) var since: Date?

    public init() {}

    public mutating func record(_ kind: UsageKind, at date: Date, calendar: Calendar = .current) {
        days[Self.key(date, calendar), default: [:]][kind, default: 0] += 1
        if since == nil { since = calendar.startOfDay(for: date) }
        if days.count > Self.keptDays, let oldest = days.keys.min() { days[oldest] = nil }
    }

    public func count(_ kind: UsageKind, on date: Date, calendar: Calendar = .current) -> Int {
        days[Self.key(date, calendar)]?[kind] ?? 0
    }

    /// One day of the chart.
    public struct Day: Equatable, Sendable, Identifiable {
        public var date: Date
        public var counts: [UsageKind: Int]
        public var id: Date { date }
        public var total: Int { counts.values.reduce(0, +) }
    }

    /// The last `length` days up to `date`, oldest first, with zeros for quiet days.
    public func chart(days length: Int = 28, ending date: Date, calendar: Calendar = .current) -> [Day] {
        let today = calendar.startOfDay(for: date)
        return (0..<length).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            return Day(date: day, counts: days[Self.key(day, calendar)] ?? [:])
        }
    }

    public var total: Int { days.values.reduce(0) { $0 + $1.values.reduce(0, +) } }

    /// Uses per day since the first one, counting today.
    public func averagePerDay(at date: Date, calendar: Calendar = .current) -> Double {
        guard let since else { return 0 }
        let elapsed = calendar.dateComponents([.day], from: since, to: calendar.startOfDay(for: date)).day ?? 0
        return Double(total) / Double(max(1, elapsed + 1))
    }

    private static func key(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
