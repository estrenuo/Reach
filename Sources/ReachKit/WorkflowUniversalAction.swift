import Foundation

/// A workflow's Universal Action (S-052): an action in the action panel for
/// selected text, a URL or files, as it accepts them, that runs the objects
/// connected to it with the text or the paths.
/// Alfred's `alfred.workflow.trigger.universalaction`.
public struct WorkflowUniversalAction: Equatable, Sendable, Identifiable {
    public static let type = "alfred.workflow.trigger.universalaction"

    public var uid: String
    public var name: String
    public var acceptsFiles: Bool
    public var acceptsText: Bool
    public var acceptsURLs: Bool
    /// Alfred's "accepts multiple": off shows the action for one file only.
    public var acceptsMany: Bool
    public var id: String { uid }

    public init(uid: String, name: String, acceptsFiles: Bool = false, acceptsText: Bool = false, acceptsURLs: Bool = false,
                acceptsMany: Bool = false) {
        self.uid = uid
        self.name = name
        self.acceptsFiles = acceptsFiles
        self.acceptsText = acceptsText
        self.acceptsURLs = acceptsURLs
        self.acceptsMany = acceptsMany
    }

    public init?(_ object: WorkflowObject) {
        guard object.type == Self.type else { return nil }
        self.init(uid: object.uid, name: object.string("name"), acceptsFiles: object.bool("acceptsfiles"),
                  acceptsText: object.bool("acceptstext"), acceptsURLs: object.bool("acceptsurls"),
                  acceptsMany: object.int("acceptsmulti") != 0)
    }

    /// Whether the action shows for these files.
    public func accepts(_ urls: [URL]) -> Bool {
        acceptsFiles && !urls.isEmpty && (acceptsMany || urls.count == 1)
    }

    /// Whether the action shows for selected text: a web address needs
    /// "accepts URLs", other text "accepts text".
    public func accepts(text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return Self.isURL(text) ? acceptsURLs : acceptsText
    }

    /// One web address and nothing else, like "https://example.com/docs".
    public static func isURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace), let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme) && url.host() != nil
    }
}

extension Workflow {
    /// The Universal Actions, in the order of the info.plist.
    public var universalActions: [WorkflowUniversalAction] { objects.compactMap(WorkflowUniversalAction.init) }
}
