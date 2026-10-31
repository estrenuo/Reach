import Foundation

/// One line in the workflow debugger (S-045).
public struct WorkflowLogEntry: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        /// An object ran, with the text it got.
        case ran
        /// What the script printed.
        case output
        /// What the script wrote to stderr, or how it failed.
        case error
    }

    public var id: Int
    public var date: Date
    public var workflow: String
    public var kind: Kind
    public var text: String
}

/// How much the debugger shows.
public enum WorkflowLogLevel: String, CaseIterable, Sendable, Identifiable {
    case all = "All Information"
    case errors = "Errors Only"

    public var id: String { rawValue }
}

/// The debugger's log: every script run, its output and its errors, newest
/// last. It keeps the last `limit` lines, so a busy workflow never fills memory.
public struct WorkflowLog: Equatable, Sendable {
    public static let limit = 500
    /// Longer output is cut, so one script cannot flood the log.
    public static let longest = 4000

    public private(set) var entries: [WorkflowLogEntry] = []
    private var nextID = 0

    public init() {}

    /// Logs one run of `object` (such as "Script Filter") in `workflow`.
    public mutating func record(workflow: String, object: String, input: String?, output: String, errors: String,
                                status: Int32, failure: String?, at date: Date = .now) {
        let ran = input.map { "\(object) ran with “\($0)”" } ?? "\(object) ran"
        add(workflow, .ran, ran, date)
        let output = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty { add(workflow, .output, output, date) }
        let errors = errors.trimmingCharacters(in: .whitespacesAndNewlines)
        if !errors.isEmpty { add(workflow, .error, errors, date) }
        if let failure {
            add(workflow, .error, failure, date)
        } else if status != 0 {
            add(workflow, .error, "\(object) ended with exit code \(status).", date)
        }
    }

    /// Logs an object that Return reached but Reach does not run (S-047).
    public mutating func skipped(workflow: String, kind: String, at date: Date = .now) {
        add(workflow, .error, "Reach does not run \(kind) yet.", date)
    }

    public mutating func clear() {
        entries = []
    }

    public func shown(_ level: WorkflowLogLevel) -> [WorkflowLogEntry] {
        level == .all ? entries : entries.filter { $0.kind == .error }
    }

    /// The lines as text for Copy, one entry per line: time, workflow, text.
    public func text(_ level: WorkflowLogLevel) -> String {
        Self.text(shown(level))
    }

    public static func text(_ entries: [WorkflowLogEntry]) -> String {
        entries.map { "[\(time($0.date))] [\($0.workflow)] \($0.text)" }.joined(separator: "\n")
    }

    /// The time an entry shows: hours to milliseconds.
    public static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)
            .secondFraction(.fractional(3)).locale(Locale(identifier: "en_GB")))
    }

    private mutating func add(_ workflow: String, _ kind: WorkflowLogEntry.Kind, _ text: String, _ date: Date) {
        let text = text.count > Self.longest ? String(text.prefix(Self.longest)) + "…" : text
        entries.append(WorkflowLogEntry(id: nextID, date: date, workflow: workflow, kind: kind, text: text))
        nextID += 1
        if entries.count > Self.limit { entries.removeFirst(entries.count - Self.limit) }
    }
}
