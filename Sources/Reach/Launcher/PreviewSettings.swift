import Foundation
import ReachKit

/// Settings > Previews: whether ⇧ opens Quick Look, and what it skips (S-012).
/// Saved in UserDefaults, except in test and snapshot runs.
@Observable
final class PreviewSettings {
    static let shared = PreviewSettings()
    private static let quickLookKey = "previews.quickLook"
    private static let typesKey = "previews.skipTypes"
    private static let foldersKey = "previews.skipFolders"

    var quickLook: Bool {
        didSet { save(quickLook, Self.quickLookKey) }
    }
    var skips: PreviewSkips {
        didSet {
            save(skips.types, Self.typesKey)
            save(skips.folders, Self.foldersKey)
        }
    }

    private init() {
        let defaults = Store.isOverridden ? nil : UserDefaults.standard
        quickLook = defaults?.object(forKey: Self.quickLookKey) as? Bool ?? true
        skips = PreviewSkips(types: defaults?.stringArray(forKey: Self.typesKey) ?? [],
                             folders: defaults?.stringArray(forKey: Self.foldersKey) ?? [])
    }

    /// True when Quick Look and the Preview dates leave this file alone.
    func skips(_ url: URL, isFolder: Bool) -> Bool {
        skips.skips(path: url.path, type: PreviewSkips.type(ofPath: url.path, isFolder: isFolder))
    }

    private func save(_ value: Any, _ key: String) {
        guard !Store.isOverridden else { return }
        UserDefaults.standard.set(value, forKey: key)
    }
}
