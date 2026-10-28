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

    let apps = AppIndex()
    private let files = FileSearch()

    /// Opens a URL and says whether it worked. The self-test swaps in a recorder.
    @ObservationIgnored var opener: @MainActor (URL) -> Bool = { LauncherModel.openInWorkspace($0) }
    @ObservationIgnored var onHide: @MainActor () -> Void = {}
    @ObservationIgnored var onResultsChange: @MainActor () -> Void = {}
    /// Called after a result opened, with the query that found it (Learning, S-004).
    @ObservationIgnored var onOpened: @MainActor (String, LaunchResult) -> Void = { _, _ in }
    /// Set by the launcher view, which can reach SwiftUI's Settings action.
    @ObservationIgnored var openSettings: @MainActor () -> Void = {}

    func didShow() {
        query = ""
        setResults([])
        showCount += 1
        apps.refreshIfStale()
    }

    func didHide() {
        files.cancel()
    }

    func refresh() {
        errors = [:]
        switch QueryKind(query) {
        case .empty:
            files.cancel()
            setResults([])
        case .normal(let text):
            files.cancel()
            let ranked = rank(apps.results(for: text), query: text)
            setResults(ranked.isEmpty ? Fallbacks.results(for: text) : ranked)
        case .files(let name):
            guard !name.isEmpty else {
                files.cancel()
                setResults([LaunchResult(id: "hint:files", title: "Type a file name", subtitle: "",
                                         icon: .symbol("doc.text.magnifyingglass"), url: nil)])
                return
            }
            let asked = query
            files.search(name) { [weak self] found in
                guard let self, self.query == asked else { return }
                let none = LaunchResult(id: "hint:nofiles", title: "No files match “\(name)”", subtitle: "",
                                        icon: .symbol("doc.questionmark"), url: nil)
                self.setResults(found.isEmpty ? [none] + Fallbacks.results(for: name) : found)
            }
        }
    }

    /// Text-match order: best score first, then by name.
    private func rank(_ scored: [(LaunchResult, Int)], query: String) -> [LaunchResult] {
        scored
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.title.localizedStandardCompare($1.0.title) == .orderedAscending }
            .prefix(Self.maxResults)
            .map(\.0)
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
