import AppKit
import OSLog
import ReachKit

/// `log show --last 10m --predicate 'subsystem == "com.sanderrobijns.reach"'`
let actionLog = Logger(subsystem: "com.sanderrobijns.reach", category: "actions")

/// The action panel for one file, folder or app, or for selected text: its
/// actions, filtered by what is typed, or the apps that can open it after Open With….
@Observable
final class ActionPanel {
    enum Item: Equatable {
        case action(FileAction)
        /// Open the target with this app (from Open With…).
        case app(URL)
        /// An action on selected text, with the text.
        case text(TextAction, String)
        /// A web search for selected text.
        case web(URL)
    }

    let target: LaunchResult
    /// The file, folder or app; nil for selected text.
    let url: URL?
    /// The selected text; nil for a file.
    let text: String?
    /// Opened by the selection hotkey: there are no results to go back to.
    var fromSelection = false
    /// More files were selected; for now the actions apply to the first (S-013 acts on all).
    var others = 0
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
        text = nil
        refresh()
    }

    /// The panel for selected text, from the app called `source`.
    init(text: String, source: String) {
        target = LaunchResult(id: "selection:text", title: TextAction.headline(text),
                              subtitle: "Selected text in \(source)", icon: .symbol("text.quote"), url: nil,
                              kindLabel: "Selected text")
        url = nil
        self.text = text
        fromSelection = true
        refresh()
    }

    /// The path, or where the text came from, for the header.
    var detail: String {
        if let url {
            let path = (url.path as NSString).abbreviatingWithTildeInPath
            return others > 0 ? "\(path) and \(others) more" : path
        }
        return target.subtitle
    }

    var selectedItem: Item? { items.indices.contains(selection) ? items[selection] : nil }

    /// The footer: what the selected action does.
    var footer: String {
        if let failure { return failure }
        switch selectedItem {
        case .action(let action): return action.summary
        case .app(let app): return "Open “\(target.title)” with \(Self.appName(app))"
        case .text(let action, _): return action.summary
        case .web: return "Open the search in your browser"
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
        if let text {
            let actions = TextAction.filtered(by: filter)
            // Short titles, the whole text in the search.
            let short = TextAction.headline(text, limit: 14)
            let searches = Fallbacks.results(for: text).map { search in
                var row = search
                row.title = search.title.replacingOccurrences(of: "“\(text)”", with: "“\(short)”")
                return row
            }.filter { search in
                filter.isEmpty || Matcher.score(query: filter, title: search.title) != nil
            }
            items = actions.map { .text($0, text) } + searches.compactMap { $0.url.map { .web($0) } }
            rows = actions.map { action in
                LaunchResult(id: "text:\(action.rawValue)", title: action.title, subtitle: "",
                             icon: .symbol(action.symbol), url: URL(string: "reach-action://\(action.rawValue)"),
                             kindLabel: "Action")
            } + searches
            if rows.isEmpty { rows = [hint("No actions match “\(filter)”")] }
        } else if choosingApp, let url {
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
            let shown = FileAction.available(isFolder: target.isFolder, off: ActionSettings.shared.off)
            let actions = FileAction.filtered(shown, by: filter)
            items = actions.map { .action($0) }
            rows = actions.map { action in
                LaunchResult(id: "action:\(action.rawValue)", title: action.title, subtitle: "",
                             icon: .symbol(action.symbol), url: url, kindLabel: "Action")
            }
            if rows.isEmpty {
                rows = [hint(shown.isEmpty ? Self.allOff : "No actions match “\(filter)”")]
            }
        }
        selection = 0
    }

    private func hint(_ title: String) -> LaunchResult {
        LaunchResult(id: "hint:actions", title: title, subtitle: "", icon: .symbol("questionmark.circle"), url: nil)
    }

    static let allOff = "All actions are off. Turn them on in Settings > Actions."

    static func appName(_ app: URL) -> String {
        FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
    }
}

/// Runs an action on the system. The self-test swaps in a recorder.
enum ActionRunner {
    /// Why the last action failed, when there is a fix to tell people about.
    static var problem: String?

    static func run(_ item: ActionPanel.Item, on url: URL?) -> Bool {
        problem = nil
        let workspace = NSWorkspace.shared
        switch item {
        case .text(.largeType, let text):
            LargeType.shared.show(text)
            return true
        case .text(.copyPlainText, let text):
            NSPasteboard.general.clearContents()
            return NSPasteboard.general.setString(text, forType: .string)
        case .web(let search):
            return workspace.open(search)
        case .app, .action:
            guard let url else { return false }
            return run(item, onFile: url)
        }
    }

    private static func run(_ item: ActionPanel.Item, onFile url: URL) -> Bool {
        let workspace = NSWorkspace.shared
        switch item {
        case .text, .web:
            return false
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
                do {
                    let trashed = try Trash.move(url, fallback: trashWithFinder)
                    actionLog.notice("trashed \(url.path, privacy: .public) -> \(trashed?.path ?? "?", privacy: .public)")
                    return true
                } catch {
                    actionLog.error("trash failed for \(url.path, privacy: .public): \(String(describing: error), privacy: .public)")
                    return false
                }
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
        (try? tellFinder("""
            activate
            open information window of (POSIX file "\(escaped(url.path))" as alias)
            """)) != nil
    }

    /// Move to Trash through Finder, for folders that refuse a plain trash, like a
    /// Desktop synced by OneDrive or iCloud Drive. Finder trashes through the file provider.
    private static func trashWithFinder(_ url: URL) throws {
        actionLog.notice("\(url.deletingLastPathComponent().path, privacy: .public) refused a plain trash, asking Finder")
        try tellFinder("delete (POSIX file \"\(escaped(url.path))\" as alias)")
    }

    private static func escaped(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Runs `commands` in a `tell application "Finder"` block.
    private static func tellFinder(_ commands: String) throws {
        var error: NSDictionary?
        NSAppleScript(source: "tell application \"Finder\"\n\(commands)\nend tell")?.executeAndReturnError(&error)
        guard let error else { return }
        actionLog.error("Finder: \(String(describing: error), privacy: .public)")
        // -1743: people said no to Reach controlling Finder.
        if error[NSAppleScript.errorNumber] as? Int == -1743 {
            problem = "Allow Reach to control Finder in System Settings > Privacy & Security > Automation."
        }
        throw CocoaError(.fileWriteNoPermission)
    }
}
