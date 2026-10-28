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
    let container: ModelContainer
    var sidebar: SidebarItem? = .all
    var selection: PersistentIdentifier?
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { if !Store.isOverridden { UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab") } }
    }

    init(container: ModelContainer) {
        self.container = container
    }

    func addSnippet(name: String = "") {
        let snippet = Snippet(name: SnippetName.clean(name))
        if sidebar == .starred { snippet.isStarred = true }
        container.mainContext.insert(snippet)
        selection = snippet.id
    }
}
