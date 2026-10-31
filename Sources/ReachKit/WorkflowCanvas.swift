import Foundation

/// Where an object sits on the canvas (S-044): the top left of its card.
public struct WorkflowPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// The kind of object, from the middle of its Alfred type
/// (`alfred.workflow.<category>.<name>`). The canvas colors a card by it.
public enum WorkflowCategory: String, Sendable, CaseIterable {
    case trigger, input, action, utility, output, other
}

extension WorkflowObject {
    public var category: WorkflowCategory {
        let parts = type.split(separator: ".")
        return parts.count >= 3 ? WorkflowCategory(rawValue: String(parts[2])) ?? .other : .other
    }

    /// The object's kind in words, such as "Script Filter".
    public var kindName: String {
        if let name = Self.names[type] { return name }
        let last = type.split(separator: ".").last.map(String.init) ?? type
        return last.prefix(1).uppercased() + last.dropFirst()
    }

    /// What this object does, in one line: its keyword, URL, text or script.
    public var summary: String {
        for key in ["keyword", "url", "clipboardtext", "largetypetext", "title", "text", "argument", "sourcefile"] {
            let value = string(key)
            if !value.isEmpty { return value }
        }
        let script = string("script")
        return script.split(separator: "\n").first.map(String.init) ?? ""
    }

    private static let names: [String: String] = [
        ScriptFilter.type: "Script Filter",
        "alfred.workflow.input.keyword": "Keyword",
        "alfred.workflow.input.filefilter": "File Filter",
        "alfred.workflow.input.listfilter": "List Filter",
        "alfred.workflow.trigger.hotkey": "Hotkey",
        "alfred.workflow.trigger.external": "External Trigger",
        "alfred.workflow.trigger.snippet": "Snippet Trigger",
        "alfred.workflow.trigger.universalaction": "Universal Action",
        Workflow.openURL: "Open URL",
        Workflow.openFile: "Open File",
        Workflow.revealFile: "Reveal in Finder",
        Workflow.runScript: "Run Script",
        "alfred.workflow.action.applescript": "Run NSAppleScript",
        "alfred.workflow.action.terminalcommand": "Terminal Command",
        "alfred.workflow.userinterface.text": "Text View",
        WorkflowShortcut.runType: "Run Shortcut",
        Workflow.copyToClipboard: "Copy to Clipboard",
        Workflow.largeType: "Large Type",
        "alfred.workflow.output.notification": "Post Notification",
        Workflow.junction: "Junction",
        Workflow.argument: "Arg and Vars",
        "alfred.workflow.utility.conditional": "Conditional",
        "alfred.workflow.utility.transform": "Transform",
    ]
}

/// Where each card goes on the canvas.
public enum WorkflowLayout {
    /// The step between columns and rows when the workflow has no positions.
    public static let column = 220.0
    public static let row = 100.0

    /// The positions from the workflow's uidata; objects without one are laid
    /// out in columns by how many lines lead to them, left to right.
    public static func positions(_ workflow: Workflow) -> [String: WorkflowPoint] {
        var result = workflow.positions.filter { uid, _ in workflow.object(uid) != nil }
        let missing = workflow.objects.filter { result[$0.uid] == nil }
        guard !missing.isEmpty else { return result }
        let depth = depths(workflow)
        var nextRow: [Int: Int] = [:]
        // Below the placed cards, so new ones never cover them.
        let top = (result.values.map(\.y).max().map { $0 + row } ?? 0)
        for object in missing {
            let column = depth[object.uid] ?? 0
            let index = nextRow[column, default: 0]
            nextRow[column] = index + 1
            result[object.uid] = WorkflowPoint(x: 40 + Double(column) * Self.column, y: top + 20 + Double(index) * row)
        }
        return result
    }

    /// How many lines lead to each object along the longest path from a start object.
    static func depths(_ workflow: Workflow) -> [String: Int] {
        let targets = Set(workflow.connections.values.flatMap { $0.map(\.to) })
        var depth: [String: Int] = [:]
        var queue = workflow.objects.map(\.uid).filter { !targets.contains($0) }
        for uid in queue { depth[uid] = 0 }
        var steps = 0
        while !queue.isEmpty, steps < workflow.objects.count * workflow.objects.count + 1 {
            steps += 1
            let uid = queue.removeFirst()
            for line in workflow.connections[uid] ?? [] where (depth[line.to] ?? -1) < depth[uid]! + 1 {
                depth[line.to] = depth[uid]! + 1
                queue.append(line.to)
            }
        }
        return depth
    }
}
