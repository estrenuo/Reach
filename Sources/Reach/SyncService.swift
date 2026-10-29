import AppKit
import Foundation
import ReachKit
import SwiftData

/// Keeps Reach's setup in a folder another Mac reads too (S-039): settings
/// and themes from `Store.settings`, snippets from the database, and the
/// workflows folder. At launch a newer folder is read before anything uses
/// a setting; after that, changes are written to it a moment later.
@Observable
final class SyncService {
    static let shared = SyncService()

    /// The chosen folder; nil when Reach does not sync.
    private(set) var folder: URL? = Store.settings.string(forKey: Keys.folder).map { URL(fileURLWithPath: $0) }
    /// The last write or read failure, shown under the folder.
    private(set) var error: String?
    /// How long after a change the folder is written.
    var delay: Duration = .seconds(2)

    private enum Keys {
        static let folder = "sync.folder"
        /// The folder's time when this Mac last wrote or read it.
        static let lastSynced = "sync.lastSynced"
    }

    private var container: ModelContainer?
    private var pending: Task<Void, Never>?
    /// True while the folder is being read, so its own changes are not written back.
    private var reading = false
    /// What was last written, so an unchanged setup is not written again.
    private var written: (values: NSDictionary, snippets: SnippetLibrary)?

    private init() {}

    var sync: SyncFolder? { folder.map(SyncFolder.init(folder:)) }

    /// Reads a newer folder or writes this Mac's setup, then watches for changes.
    func start(container: ModelContainer) {
        self.container = container
        if let sync {
            if SyncFolder.step(folderModified: sync.modified, lastSynced: lastSynced) == .read {
                read(sync)
            } else {
                write()
            }
        }
        let center = NotificationCenter.default
        center.addObserver(forName: UserDefaults.didChangeNotification, object: Store.settings, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed() }
        }
        center.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed() }
        }
    }

    /// Set Folder…: a folder with a setup in it is read, and Reach restarts
    /// to use it (true); an empty one gets this Mac's setup (false).
    @discardableResult
    func setFolder(_ url: URL) -> Bool {
        folder = url
        Store.settings.set(url.path, forKey: Keys.folder)
        Store.settings.removeObject(forKey: Keys.lastSynced)
        written = nil
        guard let sync, sync.modified != nil else {
            write()
            return false
        }
        read(sync)
        return true
    }

    /// Stop Syncing: the folder keeps its files, and this Mac its setup.
    func stop() {
        pending?.cancel()
        folder = nil
        error = nil
        Store.settings.removeObject(forKey: Keys.folder)
        Store.settings.removeObject(forKey: Keys.lastSynced)
    }

    /// Reveal: shows the folder's Reach folder in Finder.
    func reveal() {
        guard let sync else { return }
        NSWorkspace.shared.activateFileViewerSelecting([sync.root])
    }

    /// Opens a new Reach and quits this one, so every setting is read again.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    /// Writes this Mac's setup to the folder now.
    func write() {
        pending?.cancel()
        guard let sync, let container else { return }
        let values = SyncFolder.synced(Store.settings.persistentDomain(forName: Store.settingsDomain) ?? [:])
        let snippets = library(in: container.mainContext)
        // Saving `lastSynced` is a change too; the same setup is not written again.
        if let written, written.values == values as NSDictionary, written.snippets == snippets, sync.modified != nil { return }
        do {
            try sync.write(preferences: values, snippets: snippets)
            written = (values as NSDictionary, snippets)
            lastSynced = sync.modified
            error = nil
        } catch {
            self.error = "Unable to write to the folder: \(error.localizedDescription)"
        }
    }

    private func changed() {
        guard folder != nil, !reading else { return }
        pending?.cancel()
        pending = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.write()
        }
    }

    private var lastSynced: Date? {
        get { Store.settings.object(forKey: Keys.lastSynced) as? Date }
        set { Store.settings.set(newValue, forKey: Keys.lastSynced) }
    }

    /// Puts the folder's settings and snippets in place of this Mac's.
    private func read(_ sync: SyncFolder) {
        guard let container else { return }
        reading = true
        defer { reading = false }
        for (key, value) in sync.readPreferences() { Store.settings.set(value, forKey: key) }
        if let library = sync.readSnippets() { apply(library, to: container.mainContext) }
        written = (SyncFolder.synced(Store.settings.persistentDomain(forName: Store.settingsDomain) ?? [:]) as NSDictionary,
                   library(in: container.mainContext))
        lastSynced = sync.modified
        error = nil
    }

    private func library(in context: ModelContext) -> SnippetLibrary {
        let collections = (try? context.fetch(FetchDescriptor<SnippetCollection>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let snippets = (try? context.fetch(FetchDescriptor<Snippet>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        return SnippetLibrary(
            collections: collections.map { .init(id: $0.uuid, name: $0.name, createdAt: $0.createdAt) },
            snippets: snippets.map {
                .init(id: $0.uuid, name: $0.name, keyword: $0.keyword, text: $0.text, createdAt: $0.createdAt, collection: $0.collection?.uuid)
            })
    }

    private func apply(_ library: SnippetLibrary, to context: ModelContext) {
        let collections = (try? context.fetch(FetchDescriptor<SnippetCollection>())) ?? []
        var byID = Dictionary(collections.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let collectionChanges = SnippetLibrary.changes(from: collections.map(\.uuid), to: library.collections.map(\.id))
        for record in library.collections {
            let collection = byID[record.id] ?? {
                let new = SnippetCollection(name: record.name)
                new.uuid = record.id
                context.insert(new)
                return new
            }()
            collection.name = record.name
            collection.createdAt = record.createdAt
            byID[record.id] = collection
        }

        let snippets = (try? context.fetch(FetchDescriptor<Snippet>())) ?? []
        let snippetsByID = Dictionary(snippets.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let snippetChanges = SnippetLibrary.changes(from: snippets.map(\.uuid), to: library.snippets.map(\.id))
        for record in library.snippets {
            let snippet = snippetsByID[record.id] ?? {
                let new = Snippet(name: record.name)
                new.uuid = record.id
                context.insert(new)
                return new
            }()
            snippet.name = record.name
            snippet.keyword = record.keyword
            snippet.text = record.text
            snippet.createdAt = record.createdAt
            snippet.collection = record.collection.flatMap { byID[$0] }
        }
        for id in snippetChanges.delete { snippetsByID[id].map(context.delete) }
        for id in collectionChanges.delete { byID[id].map(context.delete) }
        try? context.save()
    }
}
