import AppKit
import ReachKit

/// The action panel for one file, folder or app: its actions, filtered by
/// what is typed, or the apps that can open it after Open With….
@Observable
final class ActionPanel {
    enum Item: Equatable {
        case action(FileAction)
        /// Open the target with this app (from Open With…).
        case app(URL)
    }

    let target: LaunchResult
    let url: URL
    var filter = "" {
        didSet { if filter != oldValue { refresh() } }
    }
    private(set) var choosingApp = false
    private(set) var items: [Item] = []
    /// What the list shows: one row per item, or a hint row when there are none.
    private(set) var rows: [LaunchResult] = []
    private(set) var selection = 0
    /// Set when an action failed; replaces the footer text.
    var failure: String?

    init(target: LaunchResult, url: URL) {
        self.target = target
        self.url = url
        refresh()
    }

    var selectedItem: Item? { items.indices.contains(selection) ? items[selection] : nil }

    /// The footer: what the selected action does.
    var footer: String {
        if let failure { return failure }
        switch selectedItem {
        case .action(let action): return action.summary
        case .app(let app): return "Open “\(target.title)” with \(Self.appName(app))"
        case nil: return ""
        }
    }

    func move(_ delta: Int) {
        let next = selection + delta
        guard items.indices.contains(next) else { return }
        selection = next
    }

    func select(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selection = index
    }

    /// Open With…: the list becomes the apps that can open the target.
    func chooseApp() {
        choosingApp = true
        filter = ""
        refresh()
    }

    /// Esc: clears the filter, then leaves the app list. False when there is nothing left to undo here.
    func back() -> Bool {
        if !filter.isEmpty { filter = ""; return true }
        if choosingApp { choosingApp = false; refresh(); return true }
        return false
    }

    private func refresh() {
        failure = nil
        if choosingApp {
            let apps = NSWorkspace.shared.urlsForApplications(toOpen: url).filter { $0 != url }
            let text = filter.trimmingCharacters(in: .whitespaces)
            let matching = text.isEmpty ? apps
                : apps.filter { Matcher.score(query: text, title: Self.appName($0)) != nil }
            items = matching.map { .app($0) }
            rows = matching.map { app in
                LaunchResult(id: "app:\(app.path)", title: Self.appName(app), subtitle: "",
                             icon: .file(app.path), url: app, kindLabel: "App")
            }
            if rows.isEmpty {
                rows = [hint(apps.isEmpty ? "No other apps open this file" : "No apps match “\(text)”")]
            }
        } else {
            let actions = FileAction.filtered(FileAction.available(isFolder: target.isFolder), by: filter)
            items = actions.map { .action($0) }
            rows = actions.map { action in
                LaunchResult(id: "action:\(action.rawValue)", title: action.title, subtitle: "",
                             icon: .symbol(action.symbol), url: url, kindLabel: "Action")
            }
            if rows.isEmpty { rows = [hint("No actions match “\(filter)”")] }
        }
        selection = 0
    }

    private func hint(_ title: String) -> LaunchResult {
        LaunchResult(id: "hint:actions", title: title, subtitle: "", icon: .symbol("questionmark.circle"), url: nil)
    }

    static func appName(_ app: URL) -> String {
        FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
    }
}

/// Runs an action on the system. The self-test swaps in a recorder.
enum ActionRunner {
    static func run(_ item: ActionPanel.Item, on url: URL) -> Bool {
        let workspace = NSWorkspace.shared
        switch item {
        case .app(let app):
            workspace.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            return true
        case .action(let action):
            switch action {
            case .open:
                return LauncherModel.openInWorkspace(url)
            case .reveal:
                workspace.activateFileViewerSelecting([url])
                return true
            case .getInfo:
                return showInfo(url)
            case .copyPath:
                NSPasteboard.general.clearContents()
                return NSPasteboard.general.setString(url.path, forType: .string)
            case .copyFile:
                NSPasteboard.general.clearContents()
                return NSPasteboard.general.writeObjects([url as NSURL])
            case .terminal:
                guard let terminal = workspace.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return false }
                workspace.open([folder(of: url)], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
                return true
            case .trash:
                return (try? Trash.move(url)) != nil
            case .openWith, .browse:
                // The panel and the model handle these without the system.
                return false
            }
        }
    }

    /// The folder itself, or the folder a file is in.
    static func folder(of url: URL) -> URL {
        let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let isPackage = (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) == true
        return isFolder && !isPackage ? url : url.deletingLastPathComponent()
    }

    /// Finder's Info window, through Apple Events (asks for permission once).
    private static func showInfo(_ url: URL) -> Bool {
        let path = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Finder"
            activate
            open information window of (POSIX file "\(path)" as alias)
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil
    }
}
