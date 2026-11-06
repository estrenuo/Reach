import AppKit
import ReachKit

/// The launcher's action panel (S-009) and buffer (S-013): → on a result,
/// the selection hotkey, and ⌥↑ ⌥↓ ⌥← ⌥⌫ ⌥→ on the items collected for one action.
extension LauncherModel {
    /// → on a file, folder or app: shows its action panel. False for other results.
    func showActions() -> Bool {
        guard actions == nil, let result = selectedResult else { return false }
        // A contact's card (S-024).
        if let contact = result.contact {
            actions = ActionPanel(contact: contact, result: result)
            onResultsChange()
            return true
        }
        guard let url = result.url, url.isFileURL else { return false }
        actions = ActionPanel(target: result, url: url)
        onResultsChange()
        return true
    }

    /// The selection hotkey: the action panel for the selected files or text,
    /// or a row that says what to do when there is nothing to act on.
    func showActions(for selection: Selection) {
        actions = nil
        switch selection {
        case .files(let urls):
            guard let panel = Self.panel(for: urls) else { return }
            panel.fromSelection = true
            actions = panel
        case .text(let text, let source):
            actions = ActionPanel(text: text, source: source)
        case .nothing:
            setResults([LaunchResult(id: "hint:selection", title: Self.nothingSelected, subtitle: "",
                                     icon: .symbol("selection.pin.in.out"), url: nil)])
        case .noAccess:
            setResults([LaunchResult(id: "hint:access", title: Self.allowAccess,
                                     subtitle: "System Settings > Privacy & Security > Accessibility",
                                     icon: .symbol("lock"), url: SelectionReader.accessibilitySettings)])
        }
        onResultsChange()
    }

    /// The panel for one item, or "3 Items" for several. Nil for none.
    private static func panel(for urls: [URL]) -> ActionPanel? {
        guard let url = urls.first else { return nil }
        guard urls.count == 1 else { return ActionPanel(items: urls) }
        let isFolder = ActionRunner.folder(of: url) == url
        let result = LaunchResult(id: url.path, title: FileManager.default.displayName(atPath: url.path), subtitle: "",
                                  icon: .file(url.path), url: url, kindLabel: isFolder ? "Folder" : "File",
                                  isFolder: isFolder)
        return ActionPanel(target: result, url: url)
    }

    // MARK: Buffer (S-013)

    /// The selected result's file, folder or app; nil for web searches and hints.
    private var selectedFile: URL? {
        guard let url = selectedResult?.url, url.isFileURL else { return nil }
        return url
    }

    /// ⌥↑: the selected item goes in, or out again. False when it has no file.
    func toggleBuffer() -> Bool {
        guard let url = selectedFile else { return false }
        buffer.toggle(url, at: now())
        return true
    }

    /// ⌥↓: the selected item goes in, and the next result is selected.
    func addToBuffer() -> Bool {
        guard let url = selectedFile else { return false }
        buffer.add(url, at: now())
        move(1)
        return true
    }

    /// ⌥←: takes out the last item. False with an empty buffer, so the key moves by word.
    func removeLastFromBuffer() -> Bool {
        buffer.removeLast(at: now())
    }

    /// ⌥⌫: empties the buffer. False when it is empty, so the key deletes a word.
    func clearBuffer() -> Bool {
        guard !buffer.isEmpty else { return false }
        buffer.clear()
        return true
    }

    /// ⌥→: the action panel for every item in the buffer. Items moved or
    /// deleted since they went in are left out.
    func showBufferActions() -> Bool {
        guard actions == nil, !buffer.isEmpty else { return false }
        buffer.touch(at: now())
        let items = buffer.items.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard let panel = Self.panel(for: items) else {
            buffer.clear()
            return true
        }
        panel.fromBuffer = true
        actions = panel
        onResultsChange()
        return true
    }

    static let nothingSelected = "Select files in Finder or text in any app, then press ⌃⌥⌘\\"
    static let allowAccess = "Allow Reach to read selected text"

    /// Back to the results, with the query as it was.
    func closeActions() {
        actions = nil
        onResultsChange()
    }

    /// Esc in the action panel: clears the filter, leaves Open With…, then closes the panel.
    func cancelActions() {
        guard let actions else { return }
        guard !actions.back() else { return }
        // From the selection hotkey there are no results behind the panel.
        if actions.fromSelection { onHide() } else { closeActions() }
    }

    /// Runs action `index` of the panel. Most actions hide the launcher;
    /// Open With… lists apps, Browse in Launcher shows the folder, Quick Look opens beside it.
    func runAction(at index: Int) {
        guard let panel = actions, panel.items.indices.contains(index) else { return }
        panel.select(index)
        let item = panel.items[index]
        let target = panel.target
        // Only the kind of action and the file: selected text and search URLs can hold secrets.
        let on = panel.isMany ? "\(panel.urls.count) items" : panel.url?.path ?? "selected text"
        actionLog.notice("run \(item.logName, privacy: .public) on \(on, privacy: .public)")
        switch item {
        case .action(.openWith):
            panel.chooseApp()
            return
        case .action(.quickLook):
            // Opens beside the panel, like ⇧; the launcher stays.
            _ = QuickLook.shared.toggle(target)
            return
        case .action(.browse):
            guard let url = panel.url else { return }
            let folder = ActionRunner.folder(of: url).path
            actions = nil
            if panel.fromBuffer { buffer.clear() }
            let shown = (folder as NSString).abbreviatingWithTildeInPath
            rewriteQuery(shown.hasSuffix("/") ? shown : shown + "/")
            onResultsChange()
            return
        case .action(.open):
            // Every item, even when one fails.
            let opened = panel.urls.map(opener)
            guard !opened.isEmpty, !opened.contains(false) else { panel.failure = "Unable to open “\(target.title)”."; return }
        case .web(let search):
            guard opener(search) else { panel.failure = "Unable to open the search."; return }
        case .field(let field):
            switch field.action {
            case .email(let url), .open(let url), .map(let url):
                guard opener(url) else { panel.failure = "Unable to open “\(field.value)”."; return }
            case .copy:
                copier(field.value)
            }
            // Using a card's detail picks the contact, for Learning.
            onOpened(query, target)
        case .workflow(let id, _, let trigger, let title, let argument):
            actions = nil
            switch runWorkflowAction(trigger, title: title, in: id, argument: argument) {
            case .failed(let message):
                actions = panel
                panel.failure = message
                return
            case .shows:
                if panel.fromBuffer { buffer.clear() }
                return
            case .done:
                break
            }
        default:
            guard perform(item, panel.urls) else {
                let name = panel.rows.indices.contains(index) ? panel.rows[index].title : "the action"
                panel.failure = "Unable to run “\(name)” on “\(target.title)”."
                    + (ActionRunner.problem.map { " " + $0 } ?? "")
                return
            }
        }
        if panel.fromBuffer { buffer.clear() }
        // Learning ranks one result per query; several items teach it nothing.
        if !panel.isMany, case .action(.open) = item { onOpened(query, target) }
        if !panel.isMany, case .app = item { onOpened(query, target) }
        onUsed(.actions)
        onHide()
    }

    /// ⌘O on a contact, or in its card: opens it in Contacts.app. False for other results.
    func openInContacts() -> Bool {
        guard let result = actions?.contact != nil ? actions?.target : selectedResult,
              result.contact != nil, let url = result.url else { return false }
        guard opener(url) else {
            if let actions { actions.failure = "Unable to open Contacts." } else { showError("Unable to open Contacts.", on: result.id) }
            return true
        }
        onOpened(query, result)
        onHide()
        return true
    }

    /// ⌘C in a contact card: copies the selected detail and hides. False elsewhere.
    func copySelectedField() -> Bool {
        guard let value = actions?.selectedValue else { return false }
        copier(value)
        if let target = actions?.target { onOpened(query, target) }
        onHide()
        return true
    }
}
