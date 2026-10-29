import Foundation
import UniformTypeIdentifiers

/// The file types and folders people skip in Settings > Previews (S-012):
/// they get no Quick Look and no dates in the Preview.
public struct PreviewSkips: Equatable, Sendable {
    /// Type identifiers, like "public.image". A type skips every type that conforms to it.
    public var types: [String]
    /// Full folder paths, like "/Volumes/NAS".
    public var folders: [String]

    public init(types: [String] = [], folders: [String] = []) {
        self.types = types
        self.folders = folders
    }

    /// True for a file inside a skipped folder, or of a skipped type.
    /// Reads nothing from disk, so it stays fast on slow network drives.
    public func skips(path: String, type: String?) -> Bool {
        let path = Self.plain(path)
        if folders.map(Self.plain).contains(where: { path == $0 || path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }) {
            return true
        }
        guard let type, let fileType = UTType(type) else { return false }
        return types.contains { UTType($0).map(fileType.conforms(to:)) ?? false }
    }

    /// /private/var and /var are one folder; results use the first, a resolved path the second.
    static func plain(_ path: String) -> String {
        for top in ["/private/var/", "/private/tmp/", "/private/etc/"] where path.hasPrefix(top) || path + "/" == top {
            return String(path.dropFirst("/private".count))
        }
        return path
    }

    /// The type of `path` from its name alone: a folder, or its extension.
    public static func type(ofPath path: String, isFolder: Bool) -> String? {
        if isFolder { return UTType.folder.identifier }
        let ext = (path as NSString).pathExtension
        return ext.isEmpty ? nil : UTType(filenameExtension: ext)?.identifier
    }
}
