import Foundation
import SwiftData
import ReachKit

@Model
final class Snippet {
    var name: String
    var text: String = ""
    var isStarred: Bool = false
    var createdAt: Date = Date.now
    /// A stable id for links, sync, and the agent CLI.
    var uuid: UUID = UUID()

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

/// The sidebar pages. Snapshot mode walks through every case.
enum SidebarItem: String, CaseIterable, Identifiable {
    case all, starred

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Snippets"
        case .starred: "Starred"
        }
    }

    var symbol: String {
        switch self {
        case .all: "text.quote"
        case .starred: "star"
        }
    }
}

/// App-wide state that menus, toolbars, and views share.
@Observable
final class AppModel {
    static let shared = AppModel(container: Store.makeContainer())
    /// Snapshots and the self-test run with the snippets window and no real hotkey.
    static let isTestRun = Store.isOverridden
        && (ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil || CommandLine.arguments.contains("--selftest"))

    let container: ModelContainer
    let launcherModel = LauncherModel()
    private(set) var launcher: LauncherController?
    var sidebar: SidebarItem? = .all
    var selection: PersistentIdentifier?
    /// Settings reopens on the last tab.
    var settingsTab: SettingsTab = SettingsTab(rawValue: Store.settings.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { Store.settings.set(settingsTab.rawValue, forKey: "settings.tab") }
    }

    init(container: ModelContainer) {
        self.container = container
        launcherModel.history.attach(container)
    }

    /// Builds the panel and listens for the hotkey. Test runs install the
    /// handler but leave the user's hotkey to the real app.
    func startLauncher() {
        let controller = LauncherController(model: launcherModel)
        launcher = controller
        let learning = Learning(container: container)
        launcherModel.learning = learning
        launcherModel.onOpened = { query, result in learning.record(query: query, resultID: result.id) }
        launcherModel.onURLOpened = { [launcherModel] url in launcherModel.history.record(url) }
        HotkeyCenter.shared.onPress = { controller.toggle() }
        HotkeyCenter.shared.onSelection = { controller.showSelection() }
        HotkeyCenter.shared.start(register: !Self.isTestRun)
        // Snapshots and the self-test never sleep, lock or restart the Mac.
        if Self.isTestRun { launcherModel.runSystem = { _ in true } }
        launcherModel.apps.refreshIfStale()
    }

    func addSnippet(name: String = "") {
        let snippet = Snippet(name: SnippetName.clean(name))
        if sidebar == .starred { snippet.isStarred = true }
        container.mainContext.insert(snippet)
        selection = snippet.id
    }
}
