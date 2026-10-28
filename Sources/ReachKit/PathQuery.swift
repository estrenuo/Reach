import Foundation

/// A query that browses the file system: `~/Developer/Re` is the folder
/// `~/Developer/` filtered by the name `Re`.
public struct PathQuery: Equatable, Sendable {
    /// The folder as typed, always ending in "/": "~/Developer/".
    public var folder: String
    /// What is typed after the last slash. Filters the folder's contents.
    public var name: String

    public init?(_ query: String) {
        guard query.hasPrefix("/") || query.hasPrefix("~/"),
              let slash = query.lastIndex(of: "/") else { return nil }
        folder = String(query[...slash])
        name = String(query[query.index(after: slash)...])
    }

    /// The folder with `~` replaced by `home`.
    public func expandedFolder(home: String) -> String {
        guard folder.hasPrefix("~/") else { return folder }
        return Self.withSlash(home) + folder.dropFirst(2)
    }

    /// The query for → or Tab on a folder called `child`.
    public func entering(_ child: String) -> String {
        folder + child + "/"
    }

    /// The query for ←: a typed name goes first, then one folder up.
    /// `~/` goes up to the home folder's parent; `/` stays.
    public func back(home: String) -> String {
        if !name.isEmpty { return folder }
        let trimmed = folder.dropLast()
        if trimmed.isEmpty { return "/" }
        if trimmed == "~" { return Self.parent(of: home) }
        guard let slash = trimmed.lastIndex(of: "/") else { return folder }
        return String(trimmed[...slash])
    }

    private static func parent(of path: String) -> String {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard let slash = trimmed.lastIndex(of: "/") else { return "/" }
        return String(trimmed[...slash])
    }

    private static func withSlash(_ path: String) -> String {
        path.hasSuffix("/") ? path : path + "/"
    }
}
