import Foundation
import UniformTypeIdentifiers

/// A workflow's File Action trigger (S-050): an action in the action panel for
/// files of the types it names, that runs the objects connected to it with the
/// paths as `{query}`.
public struct WorkflowFileAction: Equatable, Sendable, Identifiable {
    public static let type = "alfred.workflow.trigger.action"

    public var uid: String
    public var name: String
    /// UTIs; a file shows the action when it conforms to one. Empty is any file.
    public var fileTypes: [String]
    /// Alfred's "accepts multiple": off shows the action for one file only.
    public var acceptsMany: Bool
    public var id: String { uid }

    public init(uid: String, name: String, fileTypes: [String] = [], acceptsMany: Bool = false) {
        self.uid = uid
        self.name = name
        self.fileTypes = fileTypes
        self.acceptsMany = acceptsMany
    }

    public init?(_ object: WorkflowObject) {
        guard object.type == Self.type else { return nil }
        self.init(uid: object.uid, name: object.string("name"),
                  fileTypes: (object.config["filetypes"]?.array ?? []).compactMap(\.string),
                  acceptsMany: object.int("acceptsmulti") != 0)
    }

    /// Whether the action shows for `urls`; `conforms` says whether a file is of a UTI.
    public func accepts(_ urls: [URL], conforms: (URL, String) -> Bool = Self.conforms) -> Bool {
        guard !urls.isEmpty, acceptsMany || urls.count == 1 else { return false }
        guard !fileTypes.isEmpty else { return true }
        return urls.allSatisfy { url in fileTypes.contains { conforms(url, $0) } }
    }

    /// The text the connected objects get: the paths, tab-separated as Alfred passes them.
    public static func argument(for urls: [URL]) -> String {
        urls.map(\.path).joined(separator: "\t")
    }

    /// Whether the file at `url` is of the UTI `identifier`, by what is on disk
    /// (through a symlink, like /Applications/Safari.app), else by its extension.
    public static func conforms(_ url: URL, _ identifier: String) -> Bool {
        guard let wanted = UTType(identifier) else { return false }
        let type = (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
        return type?.conforms(to: wanted) ?? false
    }
}

extension Workflow {
    /// The File Action triggers, in the order of the info.plist.
    public var fileActions: [WorkflowFileAction] { objects.compactMap(WorkflowFileAction.init) }
}
