import Foundation
import ReachKit

/// Settings > Previews: whether ⇧ opens Quick Look, and what it skips (S-012).
/// Saved in `Store.settings`.
@Observable
final class PreviewSettings {
    static let shared = PreviewSettings()
    private static let quickLookKey = "previews.quickLook"
    private static let typesKey = "previews.skipTypes"
    private static let foldersKey = "previews.skipFolders"
    private static let thumbnailsKey = "previews.thumbnails"

    var quickLook: Bool {
        didSet { save(quickLook, Self.quickLookKey) }
    }
    /// Image, PDF and movie rows show a thumbnail instead of the file icon (S-056).
    var thumbnails: Bool {
        didSet { save(thumbnails, Self.thumbnailsKey) }
    }
    var skips: PreviewSkips {
        didSet {
            save(skips.types, Self.typesKey)
            save(skips.folders, Self.foldersKey)
        }
    }

    private init() {
        let defaults = Store.settings
        quickLook = defaults.object(forKey: Self.quickLookKey) as? Bool ?? true
        thumbnails = defaults.object(forKey: Self.thumbnailsKey) as? Bool ?? true
        skips = PreviewSkips(types: defaults.stringArray(forKey: Self.typesKey) ?? [],
                             folders: defaults.stringArray(forKey: Self.foldersKey) ?? [])
    }

    /// True when Quick Look and the Preview dates leave this file alone.
    func skips(_ url: URL, isFolder: Bool) -> Bool {
        skips.skips(path: url.path, type: PreviewSkips.type(ofPath: url.path, isFolder: isFolder))
    }

    private func save(_ value: Any, _ key: String) {
        Store.settings.set(value, forKey: key)
    }
}
