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
        /// A line of a contact card (S-024).
        case field(ContactField)

        /// For the log: the action without the text or the search it carries.
        var logName: String {
            switch self {
            case .action(let action): "action \(action.rawValue)"
            case .app(let app): "open with \(app.lastPathComponent)"
            case .text(let action, _): "text \(action.rawValue)"
            case .web(let search): "web search on \(search.host() ?? "?")"
            case .field(let field): "contact \(field.kind.rawValue)"
            }
        }
    }

    let target: LaunchResult
    /// The file, folder or app; the first item for several; nil for selected text.
    let url: URL?
    /// Every item the actions run on: one, or the buffer's (S-013).
    let urls: [URL]
    /// The selected text; nil for a file.
    let text: String?
    /// The contact a card shows; nil for files and text (S-024).
    let contact: Contact?
    /// Opened by the selection hotkey: there are no results to go back to.
    var fromSelection = false
    /// Opened with ⌥→ on the buffer: an action empties it.
    var fromBuffer = false
    var isMany: Bool { urls.count > 1 }
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
        urls = [url]
        text = nil
        contact = nil
        refresh()
    }

    /// The panel for several items: "3 Items", with the first one's icon.
    init(items: [URL]) {
        let folders = items.filter { ActionRunner.folder(of: $0) == $0 }
        target = LaunchResult(id: "items", title: "\(items.count) Items", subtitle: "",
                              icon: .file(items.first?.path ?? "/"), url: items.first, kindLabel: "Items",
                              isFolder: !folders.isEmpty)
        url = items.first
        urls = items
        text = nil
        contact = nil
        refresh()
    }

    /// The names of the items, for the header and the Preview.
    var names: [String] { urls.map { FileManager.default.displayName(atPath: $0.path) } }

    /// The panel for selected text, from the app called `source`.
    init(text: String, source: String) {
        target = LaunchResult(id: "selection:text", title: TextAction.headline(text),
                              subtitle: "Selected text in \(source)", icon: .symbol("text.quote"), url: nil,
                              kindLabel: "Selected text")
        url = nil
        urls = []
        self.text = text
        contact = nil
        fromSelection = true
        refresh()
    }

    /// A contact's card: its fields, then Open in Contacts. `result` is its row in the results.
    init(contact: Contact, result: LaunchResult) {
        target = result
        url = result.url
        urls = result.url.map { [$0] } ?? []
        text = nil
        self.contact = contact
        refresh()
    }

    /// The path, or where the text came from, for the header.
    var detail: String {
        if isMany { return names.joined(separator: ", ") }
        if contact != nil { return target.subtitle.isEmpty ? "Contact" : target.subtitle }
        if let url { return (url.path as NSString).abbreviatingWithTildeInPath }
        return target.subtitle
    }

    var selectedItem: Item? { items.indices.contains(selection) ? items[selection] : nil }

    /// The footer: what the selected action does.
    var footer: String {
        if let failure { return failure }
        switch selectedItem {
        case .action(.open) where contact != nil: return "Open the contact in Contacts (⌘O)"
        case .action(let action): return isMany ? action.summaryForMany : action.summary
        case .field(let field): return field.summary + " (⌘C copies it)"
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
        if let contact {
            let text = filter.trimmingCharacters(in: .whitespaces)
            let fields = contact.fields.filter { field in
                text.isEmpty || Matcher.score(query: text, title: field.value) != nil
                    || Matcher.score(query: text, title: field.label) != nil
            }
            let open = text.isEmpty || Matcher.score(query: text, title: Self.openInContacts) != nil
            items = fields.map { .field($0) } + (open && url != nil ? [.action(.open)] : [])
            rows = fields.map { field in
                LaunchResult(id: "field:\(field.id)", title: field.value.split(whereSeparator: \.isNewline).joined(separator: ", "),
                             subtitle: "", icon: .symbol(Self.symbol(field.kind)), url: URL(string: "reach-field://\(field.kind.rawValue)"),
                             kindLabel: field.kind == .phone ? "Phone" : field.kind.rawValue.capitalized, badge: field.label)
            } + (open && url != nil ? [LaunchResult(id: "contact:open", title: Self.openInContacts, subtitle: "",
                                                    icon: ContactsSource.icon, url: url, kindLabel: "Action")] : [])
            if rows.isEmpty {
                rows = [hint(contact.fields.isEmpty ? "No details for this contact" : "No details match “\(text)”")]
            }
        } else if let text {
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
            // Apps that open every item, in the first item's order.
            let others = urls.dropFirst().map { Set(NSWorkspace.shared.urlsForApplications(toOpen: $0)) }
            let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
                .filter { app in !urls.contains(app) && others.allSatisfy { $0.contains(app) } }
            let text = filter.trimmingCharacters(in: .whitespaces)
            let matching = text.isEmpty ? apps
                : apps.filter { Matcher.score(query: text, title: Self.appName($0)) != nil }
            items = matching.map { .app($0) }
            rows = matching.map { app in
                LaunchResult(id: "app:\(app.path)", title: Self.appName(app), subtitle: "",
                             icon: .file(app.path), url: app, kindLabel: "App")
            }
            if rows.isEmpty {
                let none = isMany ? "No app opens all of these items" : "No other apps open this file"
                rows = [hint(apps.isEmpty ? none : "No apps match “\(text)”")]
            }
        } else {
            let shown = FileAction.available(isFolder: target.isFolder,
                                             quickLook: !isMany && QuickLook.file(for: target) != nil,
                                             many: isMany, off: ActionSettings.shared.off)
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

    static let openInContacts = "Open in Contacts"

    static func symbol(_ kind: ContactField.Kind) -> String {
        switch kind {
        case .email: "envelope"
        case .phone: "phone"
        case .url: "link"
        case .address: "map"
        case .birthday: "gift"
        }
    }

    /// The selected field's value, for ⌘C; nil on Open in Contacts.
    var selectedValue: String? {
        if case .field(let field) = selectedItem { return field.value }
        return nil
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

    /// Runs `item` on every one of `urls` (none for selected text). False when
    /// it failed for any of them; the others still ran.
    static func run(_ item: ActionPanel.Item, on urls: [URL]) -> Bool {
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
        case .field:
            // The model opens or copies fields itself.
            return false
        case .app(let app):
            guard !urls.isEmpty else { return false }
            workspace.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            return true
        case .action(let action):
            guard let first = urls.first else { return false }
            switch action {
            case .open:
                return urls.map(LauncherModel.openInWorkspace).allSatisfy { $0 }
            case .reveal:
                workspace.activateFileViewerSelecting(urls)
                return true
            case .getInfo:
                return urls.map(showInfo).allSatisfy { $0 }
            case .copyPath:
                // One path per line, ready to paste into Terminal or a note.
                NSPasteboard.general.clearContents()
                return NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
            case .copyFile:
                NSPasteboard.general.clearContents()
                return NSPasteboard.general.writeObjects(urls.map { $0 as NSURL })
            case .terminal:
                guard let terminal = workspace.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return false }
                workspace.open([folder(of: first)], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
                return true
            case .trash:
                return urls.map(trash).allSatisfy { $0 }
            case .openWith, .browse, .quickLook:
                // The panel and the model handle these without the system.
                return false
            }
        }
    }

    private static func trash(_ url: URL) -> Bool {
        do {
            let trashed = try Trash.move(url, fallback: trashWithFinder)
            actionLog.notice("trashed \(url.path, privacy: .public) -> \(trashed?.path ?? "?", privacy: .public)")
            return true
        } catch {
            actionLog.error("trash failed for \(url.path, privacy: .public): \(String(describing: error), privacy: .public)")
            return false
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
