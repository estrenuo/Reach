import Foundation

/// A workflow's Fallback Search trigger (S-052): a row below the results, or
/// in their place when nothing matches, that sends the typed text on.
/// Alfred's `alfred.workflow.trigger.fallback`.
public struct WorkflowFallback: Equatable, Sendable, Identifiable {
    public static let type = "alfred.workflow.trigger.fallback"

    public var uid: String
    /// The row's title, with `{query}` for the typed text.
    public var text: String
    public var id: String { uid }

    public init(uid: String, text: String = "") {
        self.uid = uid
        self.text = text
    }

    public init?(_ object: WorkflowObject) {
        guard object.type == Self.type else { return nil }
        self.init(uid: object.uid, text: object.string("text"))
    }

    /// The title for `query`; without a text, "Search <workflow> for '<query>'".
    public func title(for query: String, workflow: String) -> String {
        WorkflowText.fill(text.isEmpty ? "Search \(workflow) for '{query}'" : text, query: query)
    }
}

extension Workflow {
    /// The Fallback Search triggers, in the order of the info.plist.
    public var fallbacks: [WorkflowFallback] { objects.compactMap(WorkflowFallback.init) }
}
