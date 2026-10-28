import Foundation

/// Something the action panel can do with a file, folder or app.
public enum FileAction: String, CaseIterable, Sendable {
    case open, openWith, reveal, browse, getInfo, copyPath, copyFile, terminal, trash

    public var title: String {
        switch self {
        case .open: "Open"
        case .openWith: "Open With…"
        case .reveal: "Reveal in Finder"
        case .browse: "Browse in Launcher"
        case .getInfo: "Get Info"
        case .copyPath: "Copy Path"
        case .copyFile: "Copy File"
        case .terminal: "Open in Terminal"
        case .trash: "Move to Trash"
        }
    }

    /// Shown in the action panel's footer for the selected action.
    public var summary: String {
        switch self {
        case .open: "Open it with its default app"
        case .openWith: "Choose another app to open it with"
        case .reveal: "Show it selected in a Finder window"
        case .browse: "List the folder in the launcher"
        case .getInfo: "Show its Finder Info window"
        case .copyPath: "Copy the full path as text"
        case .copyFile: "Copy the file, to paste it in Finder or another app"
        case .terminal: "Open a Terminal window in this folder"
        case .trash: "Move it to the Trash. You can put it back from the Trash."
        }
    }

    public var symbol: String {
        switch self {
        case .open: "arrow.up.forward.app"
        case .openWith: "square.grid.2x2"
        case .reveal: "folder"
        case .browse: "list.bullet.indent"
        case .getInfo: "info.circle"
        case .copyPath: "link"
        case .copyFile: "doc.on.doc"
        case .terminal: "terminal"
        case .trash: "trash"
        }
    }

    /// The actions for a target, in panel order. Folders skip Open With….
    public static func available(isFolder: Bool) -> [FileAction] {
        allCases.filter { !(isFolder && $0 == .openWith) }
    }

    /// Actions whose title matches `filter`, best match first; all of them for an empty filter.
    public static func filtered(_ actions: [FileAction], by filter: String) -> [FileAction] {
        let text = filter.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return actions }
        return actions
            .compactMap { action in Matcher.score(query: text, title: action.title).map { (action, $0) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }
}

/// What Move to Trash needs from the file system: the trash, and nothing that deletes.
public protocol Trashing {
    func trashItem(at url: URL, resultingItemURL: AutoreleasingUnsafeMutablePointer<NSURL?>?) throws
}

extension FileManager: Trashing {}

public enum Trash {
    /// Moves `url` to the Trash, where it can be put back. Returns where it went.
    /// When macOS keeps Reach out of the folder (Desktop, Documents and
    /// Downloads need permission), `fallback` asks another app (Finder) that
    /// has access. Other errors are thrown as they are.
    @discardableResult
    public static func move(_ url: URL, using files: some Trashing = FileManager.default,
                            fallback: ((URL) throws -> Void)? = nil) throws -> URL? {
        var trashed: NSURL?
        do {
            try files.trashItem(at: url, resultingItemURL: &trashed)
        } catch let error as CocoaError where error.code == .fileWriteNoPermission && fallback != nil {
            try fallback?(url)
            return nil
        }
        return trashed as URL?
    }
}
