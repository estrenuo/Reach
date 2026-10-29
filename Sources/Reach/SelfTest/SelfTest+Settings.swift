import AppKit
import ReachKit

extension SelfTest {
    /// S-037: Settings is a sidebar of pages with the features grouped, and
    /// the menu bar has the standard Edit, View and Window menus with Close ⌘W.
    static func checkSettingsWindow(model: AppModel) async {
        check("Settings starts with General and Appearance", SettingsTab.pages == [.general, .appearance])
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
    }
}
