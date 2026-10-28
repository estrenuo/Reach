import AppKit
import ReachKit

/// The launcher's state: the query, its results, and the selected result.
/// The panel and the self-test drive the same functions.
@Observable
final class LauncherModel {
    static let maxResults = 9
    static let openError = "Unable to open “%@”. It may have been moved or deleted."

    var query = "" {
        didSet { if query != oldValue { refresh() } }
    }
    private(set) var results: [LaunchResult] = []
    private(set) var selection = 0
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

    let apps: AppIndex
    let files: FileSearch
    let paths: PathBrowser
    /// Every source is asked for every query; equal scores keep this order.
    @ObservationIgnored var sources: [any ResultSource]
    /// Set at launch; nil keeps plain text-match order.
    @ObservationIgnored var learning: Learning?
    /// Each source's answer for the current query; nil while it is still searching.
    @ObservationIgnored private var answers: [[Scored]?] = []
    @ObservationIgnored private var generation = 0

    /// Opens a URL and says whether it worked. The self-test swaps in a recorder.
    @ObservationIgnored var opener: @MainActor (URL) -> Bool = { LauncherModel.openInWorkspace($0) }
    /// Runs an action from the action panel. The self-test swaps in a recorder.
    @ObservationIgnored var perform: @MainActor (ActionPanel.Item, URL) -> Bool = { ActionRunner.run($0, on: $1) }
    @ObservationIgnored var onHide: @MainActor () -> Void = {}
    @ObservationIgnored var onResultsChange: @MainActor () -> Void = {}
    /// Called after a result opened, with the query that found it (Learning, S-004).
    @ObservationIgnored var onOpened: @MainActor (String, LaunchResult) -> Void = { _, _ in }
    /// Set by the launcher view, which can reach SwiftUI's Settings action.
    @ObservationIgnored var openSettings: @MainActor () -> Void = {}

    init(apps: AppIndex = AppIndex(), files: FileSearch = FileSearch(), paths: PathBrowser = PathBrowser()) {
        self.apps = apps
        self.files = files
        self.paths = paths
        sources = [apps, files, paths]
    }

    func didShow() {
        actions = nil
        query = ""
        setResults([])
        showCount += 1
        apps.refreshIfStale()
    }

    func didHide() {
        actions = nil
        sources.forEach { $0.cancel() }
    }

    func refresh() {
        errors = [:]
        generation += 1
        let asked = generation
        let kind = QueryKind(query)
        if case .path(let path) = kind { browsing = path } else { browsing = nil }
        sources.forEach { $0.cancel() }
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
    /// Order: hints, then openable results ranked with Learning, then
    /// fallbacks when nothing openable came back.
    private func publish(_ kind: QueryKind) {
        guard answers.allSatisfy({ $0 != nil }) else { return }
        let all = answers.compactMap { $0 }.joined()
        let hints = all.filter { !$0.result.isOpenable }.map(\.result)
        let openable = all.filter(\.result.isOpenable)
        if browsing != nil {
            // A folder listing keeps its own order (A to Z, or best match).
            setResults(hints + openable.prefix(PathBrowser.limit).map(\.result))
            return
        }
        let byID = Dictionary(openable.map { ($0.result.id, $0.result) }, uniquingKeysWith: { first, _ in first })
        let ranked = Ranking.order(openable.map { (id: $0.result.id, score: $0.score) },
                                   learned: learning?.picks(for: query) ?? [:])
            .prefix(Self.maxResults)
            .compactMap { byID[$0] }
        setResults(hints + ranked + (ranked.isEmpty ? Fallbacks.results(for: kind.text) : []))
    }

    private func setResults(_ new: [LaunchResult]) {
        results = new
        // The first openable result is selected, so Return skips a hint row.
        selection = new.firstIndex(where: \.isOpenable) ?? 0
        onResultsChange()
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
        guard results.indices.contains(index), let url = results[index].url else { return }
        let result = results[index]
        let missing = url.isFileURL && !FileManager.default.fileExists(atPath: url.path)
        guard !missing, opener(url) else {
            selection = index
            errors[result.id] = String(format: Self.openError, result.title)
            return
        }
        onOpened(query, result)
        onHide()
    }

    private func rewriteQuery(_ new: String) {
        query = new
        queryRewrites += 1
    }

    /// → on a file, folder or app: shows its action panel. False for other results.
    func showActions() -> Bool {
        guard actions == nil, let result = selectedResult, let url = result.url, url.isFileURL else { return false }
        actions = ActionPanel(target: result, url: url)
        onResultsChange()
        return true
    }

    /// Back to the results, with the query as it was.
    func closeActions() {
        actions = nil
        onResultsChange()
    }

    /// Esc in the action panel: clears the filter, leaves Open With…, then closes the panel.
    func cancelActions() {
        guard let actions else { return }
        if !actions.back() { closeActions() }
    }

    /// Runs action `index` of the panel. Most actions hide the launcher;
    /// Open With… lists apps, Browse in Launcher shows the folder.
    func runAction(at index: Int) {
        guard let panel = actions, panel.items.indices.contains(index) else { return }
        panel.select(index)
        let item = panel.items[index]
        let target = panel.target
        switch item {
        case .action(.openWith):
            panel.chooseApp()
            return
        case .action(.browse):
            let folder = ActionRunner.folder(of: panel.url).path
            actions = nil
            let shown = (folder as NSString).abbreviatingWithTildeInPath
            rewriteQuery(shown.hasSuffix("/") ? shown : shown + "/")
            onResultsChange()
            return
        case .action(.open):
            guard opener(panel.url) else { panel.failure = "Unable to open “\(target.title)”."; return }
        default:
            guard perform(item, panel.url) else {
                let name = panel.rows.indices.contains(index) ? panel.rows[index].title : "the action"
                panel.failure = "Unable to run “\(name)” on “\(target.title)”."
                return
            }
        }
        if case .action(.open) = item { onOpened(query, target) }
        if case .app = item { onOpened(query, target) }
        onHide()
    }

    /// Esc clears the query; with an empty query it hides the launcher.
    func cancel() {
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
