import Foundation

/// One line on the canvas, found by where it starts, where it goes, and the
/// key held for it. Two lines never share all three (S-062).
public struct WorkflowLine: Hashable, Sendable {
    public var from: String
    public var to: String
    public var modifiers: Int

    public init(from: String, to: String, modifiers: Int = 0) {
        self.from = from
        self.to = to
        self.modifiers = modifiers
    }
}

/// Why a connection cannot be made, in words the canvas shows next to the drop.
public enum WorkflowRefusal: Error, Equatable, Sendable, LocalizedError {
    case itself
    case connected
    case intoTrigger
    case intoInput
    case afterEnd(kind: String)
    case loop(kind: String)

    public var errorDescription: String? {
        switch self {
        case .itself: "An object cannot connect to itself."
        case .connected: "These objects are already connected."
        case .intoTrigger: "A trigger starts a workflow: nothing connects into it."
        case .intoInput: "An input only takes a line from a trigger."
        case .afterEnd(let kind): "\(kind) ends a workflow: nothing comes after it."
        case .loop(let kind): "This would make a loop: \(kind) already leads here."
        }
    }
}

extension WorkflowEdit {
    /// The outputs with no output of their own in Alfred: nothing comes after them.
    public static let ends: Set<String> = [Workflow.copyToClipboard, Workflow.largeType, Workflow.callExternalTrigger]

    /// Why `from` cannot get a new line to `to` without a modifier, or nil when it can.
    public static func refusal(from: String, to: String, in workflow: Workflow) -> WorkflowRefusal? {
        guard from != to else { return .itself }
        guard let source = workflow.object(from), let target = workflow.object(to) else { return .itself }
        if (workflow.connections[from] ?? []).contains(where: { $0.to == to && $0.modifiers == 0 }) { return .connected }
        if ends.contains(source.type) { return .afterEnd(kind: source.kindName) }
        switch target.category {
        case .trigger: return .intoTrigger
        case .input where source.category != .trigger: return .intoInput
        default: break
        }
        if leads(from: to, to: from, in: workflow) { return .loop(kind: target.kindName) }
        return nil
    }

    /// True when a path of lines goes from `start` to `goal`.
    static func leads(from start: String, to goal: String, in workflow: Workflow) -> Bool {
        var seen: Set<String> = [start]
        var queue = [start]
        while let uid = queue.popLast() {
            if uid == goal { return true }
            for line in workflow.connections[uid] ?? [] where seen.insert(line.to).inserted {
                queue.append(line.to)
            }
        }
        return false
    }

    /// Adds a line from `from` to `to` without a modifier, as Alfred writes one.
    /// The rest of info.plist, and the other lines of `from`, stay as they are.
    public static func connect(_ from: String, to: String, in plist: inout [String: Any], folder: URL) throws {
        if let refusal = refusal(from: from, to: to, in: Workflow(plist: plist, folder: folder)) { throw refusal }
        insert(newLine(to: to), from: from, at: nil, in: &plist)
    }

    /// A line as Alfred writes a new one: no modifier, and Alfred stays open.
    static func newLine(to: String) -> [String: Any] {
        ["destinationuid": to, "modifiers": 0, "modifiersubtext": "", "vitoclose": false]
    }

    /// Removes `line`, and returns where it was and what it held, so Undo can put it back.
    @discardableResult
    public static func disconnect(_ line: WorkflowLine, in plist: inout [String: Any]) -> (index: Int, entry: [String: Any])? {
        var connections = plist["connections"] as? [String: Any] ?? [:]
        var lines = connections[line.from] as? [[String: Any]] ?? []
        guard let index = index(of: line, in: lines) else { return nil }
        let entry = lines.remove(at: index)
        if lines.isEmpty { connections[line.from] = nil } else { connections[line.from] = lines }
        plist["connections"] = connections
        return (index, entry)
    }

    /// Puts a line's `entry` back among the lines of `from`, at `index` (at the end when nil).
    public static func insert(_ entry: [String: Any], from: String, at index: Int?, in plist: inout [String: Any]) {
        var connections = plist["connections"] as? [String: Any] ?? [:]
        var lines = connections[from] as? [[String: Any]] ?? []
        lines.insert(entry, at: min(index ?? lines.count, lines.count))
        connections[from] = lines
        plist["connections"] = connections
    }

    /// Sets the key held for `line`; other keys of the line, like its subtext, stay.
    /// Returns the line as it is now, or nil when it is not there or another line already has that key.
    @discardableResult
    public static func setModifiers(_ modifiers: Int, of line: WorkflowLine, in plist: inout [String: Any]) -> WorkflowLine? {
        var connections = plist["connections"] as? [String: Any] ?? [:]
        var lines = connections[line.from] as? [[String: Any]] ?? []
        guard let index = index(of: line, in: lines) else { return nil }
        let moved = WorkflowLine(from: line.from, to: line.to, modifiers: modifiers)
        guard modifiers == line.modifiers || self.index(of: moved, in: lines) == nil else { return nil }
        lines[index]["modifiers"] = modifiers
        connections[line.from] = lines
        plist["connections"] = connections
        return moved
    }

    /// Connects `from` to `to` in the workflow in `folder`, reading info.plist fresh.
    public static func connect(_ from: String, to: String, folder: URL) throws {
        // A refused line leaves the file untouched, not even written again.
        guard let workflow = Workflow(folder: folder) else { throw CocoaError(.fileReadCorruptFile) }
        if let refusal = refusal(from: from, to: to, in: workflow) { throw refusal }
        try WorkflowFolder.update(folder) { insert(newLine(to: to), from: from, at: nil, in: &$0) }
    }

    /// Removes `line` from the workflow in `folder`; nil when it was not there.
    public static func disconnect(_ line: WorkflowLine, folder: URL) throws -> (index: Int, entry: [String: Any])? {
        var removed: (index: Int, entry: [String: Any])?
        try WorkflowFolder.update(folder) { removed = disconnect(line, in: &$0) }
        return removed
    }

    public static func insert(_ entry: [String: Any], from: String, at index: Int?, folder: URL) throws {
        try WorkflowFolder.update(folder) { insert(entry, from: from, at: index, in: &$0) }
    }

    public static func setModifiers(_ modifiers: Int, of line: WorkflowLine, folder: URL) throws -> WorkflowLine? {
        var moved: WorkflowLine?
        try WorkflowFolder.update(folder) { moved = setModifiers(modifiers, of: line, in: &$0) }
        return moved
    }

    private static func index(of line: WorkflowLine, in lines: [[String: Any]]) -> Int? {
        lines.firstIndex { entry in
            PlistValue(entry["destinationuid"] as Any)?.string == line.to
                && (entry["modifiers"].flatMap(PlistValue.init)?.int ?? 0) == line.modifiers
        }
    }
}
