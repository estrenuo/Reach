import Foundation
import UniformTypeIdentifiers

/// Which result rows show a thumbnail instead of the file icon (S-056).
/// Decides from the name alone, like `PreviewSkips`, so it never touches a slow drive.
public enum ThumbnailRule {
    /// Images, PDFs and movies. Everything else keeps its icon, which already says what it is.
    static let kinds: [UTType] = [.image, .pdf, .movie]

    /// True when the row for `path` should ask Quick Look for a thumbnail.
    public static func wants(path: String, isFolder: Bool, enabled: Bool, skips: PreviewSkips) -> Bool {
        guard enabled, !isFolder,
              let id = PreviewSkips.type(ofPath: path, isFolder: false),
              let type = UTType(id),
              kinds.contains(where: type.conforms(to:))
        else { return false }
        return !skips.skips(path: path, type: id)
    }
}
