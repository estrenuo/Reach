import AppKit
import ReachKit

/// The launcher's state: the query, its results, and the selected result.
/// The panel and the self-test drive the same functions.
@Observable
final class LauncherModel {
    static let maxResults = 9
    static let openError = "Unable to open “%@”. It may have been moved or deleted."

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            if !walkingHistory { queryHistory.resetWalk() }
            refresh()
        }
    }
    /// The queries typed before, for ⌃↑/⌃↓ and restoring the last one (S-038).
    /// Kept in memory only: a query can hold anything.
    @ObservationIgnored var queryHistory = QueryHistory()
    @ObservationIgnored private var walkingHistory = false
    @ObservationIgnored var advanced: AdvancedOptions = .shared
    private(set) var results: [LaunchResult] = []
    private(set) var selection = 0 {
        didSet { if selection != oldValue { onSelectionChange() } }
    }
    /// An inline error under a result that failed to open, by result id.
    private(set) var errors: [String: String] = [:]
    /// Goes up every time the launcher shows: the view refocuses and replays its entrance.
    private(set) var showCount = 0
    /// Set while the query is a path (`~/`, `/`): the launcher shows the
    /// folder's contents in their own order, with the Preview beside them.
    private(set) var browsing: PathQuery?
    /// The action panel for the selected result, opened with → (S-009).
    private(set) var actions: ActionPanel?
    /// Goes up when the launcher, not the person, rewrites the query (→, ←, Tab):
    /// the view then puts the text cursor at the end, so typing adds to the path.
    private(set) var queryRewrites = 0
    /// Items collected with ⌥↑ for one action on all of them (S-013). Kept while
    /// the launcher hides; emptied by an action, ⌥⌫, or 5 minutes unused.
    private(set) var buffer = FileBuffer()
    /// The command a confirmation row stands for, while it shows (S-019).
    /// Return runs it; Esc or typing goes back to the results.
    private(set) var confirming: LaunchResult?
    /// The clipboard viewer while it shows (S-026), from ⌃⌥⌘C or the Clipboard History row.
    /// Set in LauncherModel+Clipboard.swift.
    var viewer: ClipboardViewer?

    let apps: AppIndex
    let files: FileSearch
    let paths: PathBrowser
    let calculator: CalculatorSource
    let webSearches: WebSearchSource
    let typedURLs = TypedURLSource()
    let history = URLHistory()
    let system: SystemSource
    let shell: ShellSource
    let dictionary = DictionarySource()
    let contacts = ContactsSource()
    let clipboardRow = ClipboardSource()
    let settingsRow = SettingsSource()
    let snippets = SnippetSource()
    let workflows = WorkflowSource()
    /// Every source is asked for every query; equal scores keep this order.
    @ObservationIgnored var sources: [any ResultSource]
    /// Set at launch; nil keeps plain text-match order.
    @ObservationIgnored var learning: Learning?
    /// Each source's answer for the current query; nil while it is still searching.
    @ObservationIgnored private var answers: [[Scored]?] = []
    @ObservationIgnored private var generation = 0

    /// Opens a URL and says whether it worked. The self-test swaps in a recorder.
    @ObservationIgnored var opener: @MainActor (URL) -> Bool = { LauncherModel.openInWorkspace($0) }
    /// Puts an answer on the clipboard. The self-test swaps in a recorder.
    @ObservationIgnored var copier: @MainActor (String) -> Void = { Paster.copy($0) }
    /// Presses ⌘V in the app behind the launcher once it has hidden.
    @ObservationIgnored var paster: @MainActor () -> Void = { Paster.pressPaste() }
    /// Where a snippet goes on its way into the app in front (S-030). The self-test uses its own.
    @ObservationIgnored var pasteboard: NSPasteboard = .general
    /// How long after ⌘V the clipboard from before a snippet comes back.
    @ObservationIgnored var restoreDelay: Duration = .milliseconds(800)
    /// Runs a system command. The self-test and snapshots swap in a recorder.
    @ObservationIgnored var runSystem: @MainActor (SystemRun) -> Bool = { SystemRunner.run($0) }
    /// Runs a shell command in the terminal app. The self-test and snapshots swap in a recorder.
    @ObservationIgnored var runShell: @MainActor (ShellRun) -> Bool = { ShellRunner.run($0) }
    /// Shows text in Large Type. The self-test swaps in a recorder.
    @ObservationIgnored var largeType: @MainActor (String) -> Void = { LargeType.shared.show($0) }
    /// Reads the clipboard's text for a workflow hotkey (S-049). The self-test swaps in a fake.
    @ObservationIgnored var readClipboard: @MainActor () -> String? = { NSPasteboard.general.string(forType: .string) }
    /// Plays a workflow's sound: a system sound's name or a file's path (S-048). The self-test swaps in a recorder.
    @ObservationIgnored var playSound: @MainActor (String) -> Void = { sound in
        (sound.hasPrefix("/") ? NSSound(contentsOfFile: sound, byReference: true) : NSSound(named: NSSound.Name(sound)))?.play()
    }
    /// Posts a workflow's notification (S-048). The self-test swaps in a recorder.
    @ObservationIgnored var notify: @MainActor (Workflow, String, String) -> Void = { workflow, title, text in
        WorkflowNotifier.post(title: title, text: text) {
            WorkflowLibrary.shared.log.failed(workflow: workflow.name,
                                              text: "Notifications for Reach are off in System Settings > Notifications.")
        }
    }
    /// Runs an action from the action panel. The self-test swaps in a recorder.
    @ObservationIgnored var perform: @MainActor (ActionPanel.Item, [URL]) -> Bool = { ActionRunner.run($0, on: $1) }
    /// Seconds for the buffer's 5 minutes. The self-test moves it forward.
    @ObservationIgnored var now: @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    /// Reads the macOS selection for the selection hotkey. The self-test swaps in a fake.
    @ObservationIgnored var readSelection: @MainActor () async -> Selection = { await SelectionReader.read() }
    @ObservationIgnored var onHide: @MainActor () -> Void = {}
    /// Shows the launcher when it is hidden, for a workflow that shows a list again (S-047).
    @ObservationIgnored var onShow: @MainActor () -> Void = {}
    @ObservationIgnored var onResultsChange: @MainActor () -> Void = {}
    /// Called when another result is selected, or the results change under it (Quick Look follows).
    @ObservationIgnored var onSelectionChange: @MainActor () -> Void = {}
    /// Called after a result opened, with the query that found it (Learning, S-004).
    @ObservationIgnored var onOpened: @MainActor (String, LaunchResult) -> Void = { _, _ in }
    /// Called for each use, by kind, for the Usage page (S-040).
    @ObservationIgnored var onUsed: @MainActor (UsageKind) -> Void = { _ in }
    /// Called after a typed or remembered URL opened (the URL history, S-017).
    @ObservationIgnored var onURLOpened: @MainActor (URL) -> Void = { _ in }
    /// Set by the launcher view, which can reach SwiftUI's Settings action.
    @ObservationIgnored var openSettings: @MainActor () -> Void = {}
    /// The launcher's view has appeared and set `openSettings`.
    @ObservationIgnored var canOpenSettings = false
    /// Opens the snippets window; set by the launcher view, which can reach openWindow.
    @ObservationIgnored var openSnippets: @MainActor () -> Void = {}
    /// Opens the Workflows window (S-042); set by the launcher view too.
    @ObservationIgnored var openWorkflows: @MainActor () -> Void = {}
    /// The history the clipboard viewer lists. Nil in test runs, which bring their own.
    @ObservationIgnored var clipboard: ClipboardHistory?

    init(apps: AppIndex = AppIndex(), files: FileSearch = FileSearch(), paths: PathBrowser = PathBrowser(),
         calculator: CalculatorSource = CalculatorSource(), webSearches: WebSearchSource = WebSearchSource(),
         system: SystemSource = SystemSource(), shell: ShellSource = ShellSource()) {
        self.apps = apps
        self.files = files
        self.paths = paths
        self.calculator = calculator
        self.webSearches = webSearches
        self.system = system
        self.shell = shell
        sources = [calculator, shell, workflows, dictionary, typedURLs, contacts, snippets, apps, system, clipboardRow, settingsRow, history, webSearches, files, paths]
    }

    func didShow() {
        actions = nil
        viewer = nil
        confirming = nil
        if buffer.isStale(at: now()) { buffer.clear() }
        query = ""
        setResults([])
        if advanced.restoresLastQuery, let last = queryHistory.restorable(at: now()) { query = last }
        showCount += 1
        apps.refreshIfStale()
        workflows.library.reloadIfStale()
        workflows.forget()
    }

    func didHide() {
        rememberQuery()
        actions = nil
        viewer = nil
        confirming = nil
        sources.forEach { $0.cancel() }
    }

    func refresh() {
        errors = [:]
        confirming = nil
        generation += 1
        let asked = generation
        let kind = files.settings.queryKind(query, shellPrefix: shell.settings.prefix)
        if case .path(let path) = kind { browsing = path } else { browsing = nil }
        sources.forEach { $0.cancel() }
        webSearches.typed = query
        workflows.typed = query
        answers = sources.enumerated().map { index, source in
            source.results(for: kind) { [weak self] late in
                guard let self, self.generation == asked else { return }
                self.answers[index] = late
                self.publish(kind)
            }
        }
        publish(kind)
    }

    /// Shows the merged answers once every source has answered, so the
    /// previous results stay on screen while Spotlight searches.
    /// Order: hints, then pinned results (a calculation's answer, a typed URL),
    /// then openable results ranked with Learning, then fallbacks: when nothing
    /// openable came back, or always below the results (S-018).
    private func publish(_ kind: QueryKind) {
        guard answers.allSatisfy({ $0 != nil }) else { return }
        let all = answers.compactMap { $0 }.joined()
        let hints = all.filter { !$0.result.isOpenable }.map(\.result)
        let pinned = all.filter { $0.result.isOpenable && $0.result.isPinned }.map(\.result)
        let openable = all.filter { $0.result.isOpenable && !$0.result.isPinned }
        if browsing != nil {
            // A folder listing keeps its own order (A to Z, or best match).
            setResults(hints + openable.prefix(PathBrowser.limit).map(\.result))
            return
        }
        let byID = Dictionary(openable.map { ($0.result.id, $0.result) }, uniquingKeysWith: { first, _ in first })
        let ranked = Ranking.order(openable.map { (id: $0.result.id, score: $0.score) },
                                   learned: learning?.picks(for: query) ?? [:])
            .compactMap { byID[$0] }
        let found = pinned + ranked
        let fallbacks = Fallbacks.results(for: kind.text) + workflows.fallbacks(for: kind.text)
        let split = FallbackList.split(found: found.count, fallbacks: fallbacks.count,
                                       mode: webSearches.settings.fallbackMode,
                                       limit: LauncherOptions.clampedVisible(LauncherOptionsStore.shared.visibleResults))
        setResults(hints + found.prefix(split.results) + fallbacks.prefix(split.fallbacks))
    }

    private func setResults(_ new: [LaunchResult]) {
        results = new
        // The first openable result is selected, so Return skips a hint row.
        let first = new.firstIndex(where: \.isOpenable) ?? 0
        if selection == first { onSelectionChange() } else { selection = first }
        onResultsChange()
    }

    // MARK: Query history and alternative actions (S-038)

    /// Saves the query in the history. Shell commands stay out: they can hold passwords.
    private func rememberQuery() {
        guard advanced.remembersQueries, !query.hasPrefix(shell.settings.prefix) else { return }
        queryHistory.add(query, at: now())
    }

    /// ⌃↑ (`older`) or ⌃↓: puts a query from the history in the field. False when there is none.
    func walkHistory(older: Bool) -> Bool {
        guard advanced.remembersQueries else { return false }
        if older, queryHistory.position == nil { rememberQuery() }
        guard let text = older ? queryHistory.older() : queryHistory.newer() else { return false }
        walkingHistory = true
        rewriteQuery(text)
        walkingHistory = false
        return true
    }

    /// ⌃↩, ⌥↩ or ⌘↩: runs the web search chosen for that modifier with the
    /// typed text. False when none is chosen, so the key does what it did before.
    func runAlternative(_ modifier: ReturnModifier) -> Bool {
        if let result = selectedResult, let run = result.workflow, runWorkflow(run, result: result, modifier: modifier) {
            return true
        }
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty,
              let search = modifier.search(in: advanced.alternatives, from: webSearches.settings.searches),
              let url = WebSearchURL.make(template: search.url, query: text) else { return false }
        guard opener(url) else {
            if let selected = selectedResult { errors[selected.id] = "Unable to open the search." }
            return true
        }
        rememberQuery()
        onHide()
        return true
    }

    /// Shows `message` under the result with this id; the launcher stays open.
    func showError(_ message: String, on id: String) {
        errors[id] = message
    }

    /// Moves the selection without wrapping around.
    func move(_ delta: Int) {
        let next = selection + delta
        guard results.indices.contains(next) else { return }
        selection = next
    }

    func select(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selection = index
    }

    func openSelected() { open(at: selection) }

    var selectedResult: LaunchResult? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    /// → while browsing: into the selected folder. False when there is none.
    func enter() -> Bool {
        guard let browsing, let result = selectedResult, result.isFolder else { return false }
        rewriteQuery(browsing.entering(result.title))
        return true
    }

    /// ← while browsing: drops the typed name, then goes up one folder.
    func back() -> Bool {
        guard let browsing else { return false }
        rewriteQuery(browsing.back(home: paths.home))
        return true
    }

    /// Tab while browsing: enters a folder, or completes a file's name.
    func complete() -> Bool {
        guard let browsing, let result = selectedResult, result.isOpenable else { return false }
        if enter() { return true }
        rewriteQuery(browsing.folder + result.title)
        return true
    }

    /// Opens result `index`, then hides the launcher. On failure the launcher
    /// stays open with the error as the result's subtitle.
    func open(at index: Int) {
        guard results.indices.contains(index) else { return }
        let result = results[index]
        if let answer = result.answer {
            copier(answer)
            onHide()
            return
        }
        if let completion = result.completes {
            rewriteQuery(completion)
            return
        }
        if let run = result.workflow {
            runWorkflow(run, result: result)
            return
        }
        if let text = result.pastes {
            onOpened(query, result)
            pasteSnippet(text)
            return
        }
        if result.opensSettings {
            onOpened(query, result)
            onHide()
            openSettings()
            return
        }
        if result.opensSnippets {
            onOpened(query, result)
            onHide()
            openSnippets()
            return
        }
        if result.opensClipboard {
            selection = index
            showClipboard(fromLauncher: true)
            return
        }
        if result.contact != nil {
            selection = index
            _ = showActions()
            return
        }
        if let run = result.system {
            runCommand(run, result: result)
            return
        }
        if let run = result.shell {
            // Not passed to Learning: the command can hold paths and passwords.
            guard runShell(run) else {
                errors[result.id] = "Unable to open \(run.app.title)."
                return
            }
            onHide()
            return
        }
        guard let url = result.url else { return }
        let missing = url.isFileURL && !FileManager.default.fileExists(atPath: url.path)
        let worked = !missing && (result.reveals ? perform(.action(.reveal), [url]) : opener(url))
        guard worked else {
            selection = index
            errors[result.id] = String(format: Self.openError, result.title)
            return
        }
        if result.remembers { onURLOpened(url) }
        onOpened(query, result)
        onHide()
    }

    /// A command with Confirm on shows one row that asks first; Return on that
    /// row runs it. A failed command stays on screen with the error under it.
    private func runCommand(_ run: SystemRun, result: LaunchResult) {
        if run.confirms, confirming == nil {
            confirming = result
            var row = result
            row.id = "confirm:\(result.id)"
            row.title = run.command.question(run.target)
            row.subtitle = run.command.confirmHelp
            row.system?.confirms = false
            setResults([row])
            return
        }
        let shown = confirming ?? result
        guard runSystem(run) else {
            errors[results[selection].id] = "Unable to run “\(shown.title)”."
            return
        }
        confirming = nil
        onOpened(query, shown)
        onHide()
    }

    /// ⌘↩ on a calculation: copies the answer and pastes it into the app
    /// behind the launcher. False for other results, so ⌘↩ opens them.
    func pasteSelected() -> Bool {
        guard let answer = selectedResult?.answer else { return false }
        copier(answer)
        onHide()
        paster()
        return true
    }

    /// What ⌘L shows (S-023): what the selected result stands for, like a
    /// calculation's answer, a spelling or a command; ⌘⌥L (`typed`) and a
    /// hint or web search show the query. Nil when there is nothing to show.
    func largeTypeText(typed: Bool = false) -> String? {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !typed, let result = selectedResult, result.isOpenable,
              !result.id.hasPrefix("fallback:"), !result.id.hasPrefix("web:"), result.completes == nil else {
            return query.isEmpty ? nil : query
        }
        // A calculation shows the answer as its row does, with grouping: 1,234.
        if result.answer != nil { return result.title }
        if let shell = result.shell { return shell.command }
        if let url = result.url, !url.isFileURL { return TypedURL.display(url.absoluteString) }
        return result.title
    }

    /// ⌘L: hides the launcher and shows the text in Large Type. False when there is none.
    func showLargeType(typed: Bool = false) -> Bool {
        guard let text = largeTypeText(typed: typed) else { return false }
        onHide()
        largeType(text)
        return true
    }

    private func rewriteQuery(_ new: String) {
        query = new
        queryRewrites += 1
    }

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
        case .workflow(let id, _, let action):
            actions = nil
            switch runFileAction(action, in: id, on: panel.urls) {
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
            if let actions { actions.failure = "Unable to open Contacts." } else { errors[result.id] = "Unable to open Contacts." }
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

    /// Esc on a confirmation row goes back to the results. Otherwise it clears
    /// the query; with an empty query it hides the launcher.
    func cancel() {
        if confirming != nil {
            refresh()
            return
        }
        if query.isEmpty { onHide() } else { query = "" }
    }

    static func openInWorkspace(_ url: URL) -> Bool {
        if url.pathExtension == "app" {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return true
        }
        return NSWorkspace.shared.open(url)
    }
}
