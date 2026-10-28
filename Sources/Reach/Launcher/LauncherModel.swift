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

    let apps: AppIndex
    let files: FileSearch
    /// Every source is asked for every query; equal scores keep this order.
    @ObservationIgnored var sources: [any ResultSource]
    /// Set at launch; nil keeps plain text-match order.
    @ObservationIgnored var learning: Learning?
    /// Each source's answer for the current query; nil while it is still searching.
    @ObservationIgnored private var answers: [[Scored]?] = []
    @ObservationIgnored private var generation = 0

    /// Opens a URL and says whether it worked. The self-test swaps in a recorder.
    @ObservationIgnored var opener: @MainActor (URL) -> Bool = { LauncherModel.openInWorkspace($0) }
    @ObservationIgnored var onHide: @MainActor () -> Void = {}
    @ObservationIgnored var onResultsChange: @MainActor () -> Void = {}
    /// Called after a result opened, with the query that found it (Learning, S-004).
    @ObservationIgnored var onOpened: @MainActor (String, LaunchResult) -> Void = { _, _ in }
    /// Set by the launcher view, which can reach SwiftUI's Settings action.
    @ObservationIgnored var openSettings: @MainActor () -> Void = {}

    init(apps: AppIndex = AppIndex(), files: FileSearch = FileSearch()) {
        self.apps = apps
        self.files = files
        sources = [apps, files]
    }

    func didShow() {
        query = ""
        setResults([])
        showCount += 1
        apps.refreshIfStale()
    }

    func didHide() {
        sources.forEach { $0.cancel() }
    }

    func refresh() {
        errors = [:]
        generation += 1
        let asked = generation
        let kind = QueryKind(query)
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

    /// Esc clears the query; with an empty query it hides the launcher.
    func cancel() {
        if query.isEmpty { onHide() } else { query = "" }
    }

    private static func openInWorkspace(_ url: URL) -> Bool {
        if url.pathExtension == "app" {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return true
        }
        return NSWorkspace.shared.open(url)
    }
}
