import AppKit
import ReachKit

extension SelfTest {
    /// S-037: Settings is a sidebar of pages with the features grouped, and
    /// the menu bar has the standard Edit, View and Window menus with Close ⌘W.
    static func checkSettingsWindow(model: AppModel) async {
        check("Settings starts with General, Appearance, Advanced and Usage", SettingsTab.pages == [.general, .appearance, .advanced, .usage])
        check("every other page is a feature with a summary",
              SettingsTab.features.count == SettingsTab.allCases.count - SettingsTab.pages.count
                  && SettingsTab.features.allSatisfy { !$0.summary.isEmpty })
        let menus = NSApp.mainMenu?.items.map(\.title) ?? []
        for title in ["Edit", "View", "Window"] {
            check("the menu bar has \(title)", menus.contains(title), menus.joined(separator: ", "))
        }
        let close = NSApp.mainMenu?.items.flatMap { $0.submenu?.items ?? [] }
            .first { $0.action == #selector(NSWindow.performClose(_:)) }
        check("Close is ⌘W", close?.keyEquivalent == "w" && close?.keyEquivalentModifierMask == .command,
              close.map { "\($0.title) \($0.keyEquivalent)" } ?? "no Close item")
        await checkSearchSettings(model: model)
    }

    /// S-036: Search Settings finds a setting by its label, a page by its
    /// name, and has Edit > Search Settings ⌘F.
    static func checkSearchSettings(model: AppModel) async {
        let edit = NSApp.mainMenu?.items.first { $0.title == "Edit" }?.submenu
        let item = edit?.items.first { $0.title == "Search Settings" }
        check("Edit has Search Settings ⌘F", item?.keyEquivalent == "f" && item?.keyEquivalentModifierMask == .command,
              item.map { "\($0.title) \($0.keyEquivalent)" } ?? "no item")
        let login = SettingsTab.search("login").first
        check("searching “login” finds Open at login on General", login?.entry.title == "Open at login" && login?.tab == .general)
        check("searching a page's name finds the page", SettingsTab.search("Clipboard").first?.tab == .clipboard)
        check("searching words in a summary finds the page", SettingsTab.search("quit apps").contains { $0.tab == .system })
        check("a typo finds nothing", SettingsTab.search("qxzv").isEmpty)
    }
}
