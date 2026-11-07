import Foundation
import SwiftData
import ReachKit

@Model
final class Snippet {
    var name: String
    /// A short word to find the snippet by, like "sig" (S-029).
    var keyword: String = ""
    var text: String = ""
    var createdAt: Date = Date.now
    /// A stable id for links, sync, and the agent CLI.
    var uuid: UUID = UUID()
    /// Every snippet is in one collection; nil only for snippets from before S-029.
    var collection: SnippetCollection?

    init(name: String) {
        self.name = name
    }
}

/// A named group of snippets, like "Work" (S-029). Deleting one deletes its snippets.
@Model
final class SnippetCollection {
    var name: String = ""
    var createdAt: Date = Date.now
    var uuid: UUID = UUID()
    @Relationship(deleteRule: .cascade, inverse: \Snippet.collection) var snippets: [Snippet]? = []

    init(name: String) {
        self.name = name
    }
}

/// What Learning knows: for a query, which result was opened, how often, and when (S-004).
@Model
final class LearningEntry {
    var query: String = ""
    var resultID: String = ""
    var count: Int = 0
    var lastUsed: Date = Date.now

    init(query: String, resultID: String) {
        self.query = query
        self.resultID = resultID
    }
}

/// A URL opened from the launcher, for the URL history (S-017).
@Model
final class URLVisit {
    var url: String = ""
    var lastUsed: Date = Date.now

    init(url: String) {
        self.url = url
    }
}

/// One copied item in the clipboard history (S-025). Every field has a
/// default, so databases from before the history keep loading.
@Model
final class ClipboardItem {
    /// `ClipboardPolicy.Kind`: text, image or files.
    var kind: String = ClipboardPolicy.Kind.text.rawValue
    /// The text, or one file path per line for a file list; empty for an image.
    var text: String = ""
    /// PNG or TIFF data for an image, kept beside the database.
    @Attribute(.externalStorage) var imageData: Data?
    /// The app that was in front when it was copied, by name and bundle id.
    var sourceApp: String = ""
    var sourceBundleID: String = ""
    /// When it was copied; copying the same again moves it to the top.
    var copiedAt: Date = Date.now

    init(kind: ClipboardPolicy.Kind, text: String = "", imageData: Data? = nil, sourceApp: String = "", sourceBundleID: String = "") {
        self.kind = kind.rawValue
        self.text = text
        self.imageData = imageData
        self.sourceApp = sourceApp
        self.sourceBundleID = sourceBundleID
    }

    var clipKind: ClipboardPolicy.Kind { ClipboardPolicy.Kind(rawValue: kind) ?? .text }
}

/// A deleted collection and its snippets as values, for ⌘Z.
struct DeletedCollection {
    struct Value { var name, keyword, text: String; var createdAt: Date; var uuid: UUID }
    var name: String
    var createdAt: Date
    var uuid: UUID
    var snippets: [Value]

    init(_ collection: SnippetCollection) {
        (name, createdAt, uuid) = (collection.name, collection.createdAt, collection.uuid)
        snippets = (collection.snippets ?? []).map {
            Value(name: $0.name, keyword: $0.keyword, text: $0.text, createdAt: $0.createdAt, uuid: $0.uuid)
        }
    }
}

extension ModelContext {
    /// The model with this id while it is in the store, else nil. Unlike
    /// `model(for:)`, it never returns a deleted model, whose properties
    /// crash when read (fix log: deleting the collection on screen).
    func existing<T: PersistentModel>(_ id: PersistentIdentifier, as type: T.Type) -> T? {
        var descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return (try? fetch(descriptor))?.first
    }
}

/// What the snippets window's sidebar shows: every snippet, or one collection.
enum SnippetPage: Hashable {
    case all
    case collection(PersistentIdentifier)

    static let allTitle = "All Snippets"
}

/// App-wide state that menus, toolbars, and views share.
@Observable
final class AppModel {
    static let shared: AppModel = {
        let container = Store.makeContainer()
        // A newer setup from the sync folder goes in before any setting is read (S-039).
        SyncService.shared.start(container: container)
        return AppModel(container: container)
    }()
    /// Snapshots and the self-test run with the snippets window and no real hotkey.
    static let isTestRun = Store.isOverridden
        && (ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil || CommandLine.arguments.contains("--selftest"))

    let container: ModelContainer
    let launcherModel = LauncherModel()
    private(set) var launcher: LauncherController?
    /// The menu bar icon; Launcher Options can hide it (S-035).
    private(set) var menuBarIcon: MenuBarIcon?
    /// Keeps what is copied, per Settings > Clipboard (S-025). Test runs never
    /// watch the real clipboard; the self-test makes its own on a private pasteboard.
    private(set) var clipboard: ClipboardHistory?
    /// ⌘C twice appends to the last clip (S-028); nil in test runs, like the history.
    private(set) var doubleCopy: DoubleCopyWatcher?
    /// Expands snippet keywords while typing (S-031); nil in test runs, which never watch real keys.
    private(set) var snippetExpander: SnippetExpander?
    var page: SnippetPage? = .all
    /// The selected snippet in the window.
    var selection: PersistentIdentifier?
    /// Settings reopens on the last tab.
    var settingsTab: SettingsTab = SettingsTab(rawValue: Store.settings.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { Store.settings.set(settingsTab.rawValue, forKey: "settings.tab") }
    }
    /// What Search Settings looks for (S-036); empty shows the pages.
    var settingsQuery = ""
    /// Goes up by one for each Search Settings (⌘F), which focuses the field.
    var settingsSearchRequests = 0

    init(container: ModelContainer) {
        self.container = container
        launcherModel.history.attach(container)
        launcherModel.snippets.context = container.mainContext
        adoptLooseSnippets()
    }

    /// Builds the panel and listens for the hotkey. Test runs install the
    /// handler but leave the user's hotkey to the real app.
    func startLauncher() {
        let controller = LauncherController(model: launcherModel)
        launcher = controller
        menuBarIcon = MenuBarIcon()
        let learning = Learning(container: container)
        launcherModel.learning = learning
        launcherModel.onOpened = { [launcherModel] query, result in
            learning.record(query: query, resultID: result.id)
            // The action panel and snippets count as their own kind.
            if launcherModel.actions == nil, result.pastes == nil { UsageStore.shared.record(.launcher) }
        }
        launcherModel.onUsed = { UsageStore.shared.record($0) }
        launcherModel.onURLOpened = { [launcherModel] url in launcherModel.history.record(url) }
        HotkeyCenter.shared.onPress = { controller.toggle() }
        HotkeyCenter.shared.onSelection = { controller.showSelection() }
        HotkeyCenter.shared.onClipboard = { controller.toggleClipboard() }
        HotkeyCenter.shared.onMiniPlayer = { [launcherModel] in
            if controller.isVisible, launcherModel.inMiniPlayer { return controller.hide() }
            if !controller.isVisible { controller.show() }
            launcherModel.openMiniPlayer()
        }
        launcherModel.followMusicLibrary()
        HotkeyCenter.shared.start(register: !Self.isTestRun)
        // Workflow hotkeys (S-049): registered again whenever the library is read.
        let hotkeys = WorkflowHotkeys.shared
        hotkeys.registers = !Self.isTestRun
        hotkeys.run = { [launcherModel] workflow, hotkey in Task { await launcherModel.runHotkey(hotkey, in: workflow) } }
        HotkeyCenter.shared.onWorkflow = { hotkeys.pressed($0) }
        WorkflowLibrary.shared.onReload = { hotkeys.apply() }
        hotkeys.apply()
        // Snapshots and the self-test never sleep, lock or restart the Mac, run shell commands, or read contacts.
        if Self.isTestRun {
            launcherModel.runSystem = { _ in true }
            launcherModel.runShell = { _ in true }
            // Nor read the person's contacts, or ask for access to them.
            launcherModel.contacts.loader = { $0([]) }
            // Nor send Apple Events to Music (S-059).
            launcherModel.music.player = .silent
            // Nor read the Music library (S-060): an empty one until a check brings samples.
            launcherModel.music.library.loaderIsLive = false
            launcherModel.music.library.loader = { $0(MusicLibrary()) }
            launcherModel.music.library.artwork = { _ in nil }
        }
        // Starts following which app was used last, for `quit`.
        _ = AppRecency.shared
        launcherModel.apps.refreshIfStale()
        if !Self.isTestRun {
            let history = ClipboardHistory(context: container.mainContext)
            history.start()
            clipboard = history
            launcherModel.clipboard = history
            let watcher = DoubleCopyWatcher(history: history)
            watcher.follow()
            doubleCopy = watcher
            let expander = SnippetExpander(launcher: launcherModel)
            expander.follow()
            snippetExpander = expander
        }
    }

    static let defaultCollection = "Snippets"

    /// The collection the window shows, nil on All Snippets.
    var currentCollection: SnippetCollection? {
        guard case .collection(let id) = page else { return nil }
        return container.mainContext.existing(id, as: SnippetCollection.self)
    }

    /// A new snippet goes into the collection on screen; on All Snippets into
    /// the oldest collection, or a new "Snippets" one when there is none.
    @discardableResult
    func addSnippet(name: String = "") -> Snippet {
        let context = container.mainContext
        let snippet = Snippet(name: SnippetName.clean(name))
        context.insert(snippet)
        snippet.collection = currentCollection ?? defaultCollection()
        try? context.save()
        selection = snippet.id
        return snippet
    }

    @discardableResult
    func addCollection(name: String) -> SnippetCollection {
        let collection = SnippetCollection(name: SnippetName.clean(name, fallback: "New Collection"))
        container.mainContext.insert(collection)
        try? container.mainContext.save()
        page = .collection(collection.id)
        selection = nil
        return collection
    }

    /// Deletes the collection and its snippets; ⌘Z brings them back.
    ///
    /// The undo is Reach's own: it keeps the collection and its snippets as
    /// values and inserts them again. SwiftData's own undo of a saved cascade
    /// delete crashes now and then (fix log: ⌘Z after deleting a collection).
    func delete(_ collection: SnippetCollection) {
        if case .collection(collection.id) = page { page = .all }
        selection = nil
        let context = container.mainContext
        let kept = DeletedCollection(collection)
        let undo = context.undoManager
        context.undoManager = nil
        context.delete(collection)
        try? context.save()
        context.undoManager = undo
        undo?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.restore(kept) }
        }
        undo?.setActionName("Delete Collection")
    }

    /// Puts a deleted collection and its snippets back, with their ids, and
    /// shows it; ⌘⇧Z deletes it again.
    private func restore(_ kept: DeletedCollection) {
        let context = container.mainContext
        let undo = context.undoManager
        context.undoManager = nil
        let collection = SnippetCollection(name: kept.name)
        collection.uuid = kept.uuid
        collection.createdAt = kept.createdAt
        context.insert(collection)
        for value in kept.snippets {
            let snippet = Snippet(name: value.name)
            (snippet.keyword, snippet.text, snippet.createdAt, snippet.uuid) = (value.keyword, value.text, value.createdAt, value.uuid)
            context.insert(snippet)
            snippet.collection = collection
        }
        try? context.save()
        context.undoManager = undo
        page = .collection(collection.id)
        undo?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.delete(collection) }
        }
        undo?.setActionName("Delete Collection")
    }

    /// Snippets from before collections go into "Snippets", so every snippet has one.
    func adoptLooseSnippets() {
        let context = container.mainContext
        let loose = (try? context.fetch(FetchDescriptor<Snippet>(predicate: #Predicate { $0.collection == nil }))) ?? []
        guard !loose.isEmpty else { return }
        let home = defaultCollection()
        loose.forEach { $0.collection = home }
        try? context.save()
    }

    private func defaultCollection() -> SnippetCollection {
        let context = container.mainContext
        var oldest = FetchDescriptor<SnippetCollection>(sortBy: [SortDescriptor(\.createdAt)])
        oldest.fetchLimit = 1
        if let first = try? context.fetch(oldest).first { return first }
        let home = SnippetCollection(name: Self.defaultCollection)
        context.insert(home)
        return home
    }
}
