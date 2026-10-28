import Foundation
import ReachKit

/// Which actions people switched off in Settings > Actions. Saved in
/// UserDefaults, except in test and snapshot runs, which must leave the
/// real settings alone.
@Observable
final class ActionSettings {
    static let shared = ActionSettings()
    private static let key = "actions.off"

    var off: Set<FileAction> {
        didSet {
            guard !Store.isOverridden else { return }
            UserDefaults.standard.set(off.map(\.rawValue).sorted(), forKey: Self.key)
        }
    }

    private init() {
        let saved = Store.isOverridden ? [] : UserDefaults.standard.stringArray(forKey: Self.key) ?? []
        off = Set(saved.compactMap(FileAction.init(rawValue:)))
    }

    func isOn(_ action: FileAction) -> Bool { !off.contains(action) }

    func set(_ action: FileAction, on: Bool) {
        if on { off.remove(action) } else { off.insert(action) }
    }
}
