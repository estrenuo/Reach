import Foundation
import ReachKit
import SwiftData

extension SelfTest {
    /// S-039: the setup goes to a sync folder, and a folder another Mac wrote comes back in.
    static func checkSync(model: AppModel) {
        let sync = SyncService.shared
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "reach-selftest-sync-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let context = model.container.mainContext
        let snippet = Snippet(name: "Sync check")
        snippet.text = "from this Mac"
        context.insert(snippet)
        try? context.save()
        Store.settings.set("this Mac", forKey: "selftest.sync")
        defer {
            sync.stop()
            context.delete(snippet)
            try? context.save()
            Store.settings.removeObject(forKey: "selftest.sync")
            try? FileManager.default.removeItem(at: folder)
        }

        check("an empty folder gets this Mac's setup", !sync.setFolder(folder) && sync.folder == folder)
        let files = SyncFolder(folder: folder)
        check("settings, snippets and workflows live under the folder",
              [files.preferences, files.snippets, files.workflows].allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        check("the folder has the settings", files.readPreferences()["selftest.sync"] as? String == "this Mac")
        check("the folder has the snippets", files.readSnippets()?.snippets.contains { $0.id == snippet.uuid && $0.text == "from this Mac" } == true)
        check("the folder stays out of the sync", files.readPreferences()["sync.folder"] == nil)

        // Another Mac changes the folder.
        var library = files.readSnippets() ?? SnippetLibrary()
        if let index = library.snippets.firstIndex(where: { $0.id == snippet.uuid }) { library.snippets[index].text = "from the other Mac" }
        var values = files.readPreferences()
        values["selftest.sync"] = "the other Mac"
        try? files.write(preferences: values, snippets: library)

        check("a folder with a setup asks for a restart", sync.setFolder(folder))
        check("its settings come in", Store.settings.string(forKey: "selftest.sync") == "the other Mac",
              Store.settings.string(forKey: "selftest.sync") ?? "nil")
        check("its snippets come in", snippet.text == "from the other Mac", snippet.text)

        sync.stop()
        check("Stop Syncing leaves the folder's files", sync.folder == nil && FileManager.default.fileExists(atPath: files.snippets.path))
    }
}
