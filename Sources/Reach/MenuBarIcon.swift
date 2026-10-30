import AppKit

/// The menu bar icon and its menu, shown or hidden by Launcher Options >
/// Show menu bar icon (S-035). An NSStatusItem, not a MenuBarExtra: a Scene
/// body does not follow the option while the app runs, and binding
/// `isInserted` to @AppStorage hung the app at launch.
final class MenuBarIcon: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    var isVisible: Bool { item.isVisible }

    override init() {
        super.init()
        // macOS keeps the icon's place and visibility under this name; test runs keep theirs apart.
        item.autosaveName = AppModel.isTestRun ? "ReachTestRun" : "Reach"
        item.button?.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Reach")
        item.menu = makeMenu()
        follow()
    }

    /// Shows or hides the icon to match the option, now and whenever it changes.
    private func follow() {
        withObservationTracking {
            item.isVisible = LauncherOptionsStore.shared.showsMenuBarIcon
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.follow() }
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(entry("Show Launcher", #selector(showLauncher)))
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        // No action, so the menu shows it dimmed.
        menu.addItem(NSMenuItem(title: "Version \(version)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(entry("Snippets…", #selector(openSnippets)))
        menu.addItem(entry("Workflows…", #selector(openWorkflows)))
        menu.addItem(entry("Settings…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func entry(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        return entry
    }

    @objc private func showLauncher() { AppModel.shared.launcher?.show() }
    @objc private func openSettings() { AppModel.shared.launcher?.openSettings() }
    @objc private func openSnippets() { AppModel.shared.launcher?.openFromOutside { $0.openSnippets() } }
    @objc private func openWorkflows() { AppModel.shared.launcher?.openFromOutside { $0.openWorkflows() } }
}
