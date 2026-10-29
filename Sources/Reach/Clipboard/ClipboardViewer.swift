import Foundation
import ReachKit

/// The clipboard viewer (S-026): the clips, newest first, filtered by what is
/// typed, with All Snippets above them. ↩ pastes the selected clip.
@Observable
final class ClipboardViewer {
    /// One row of the list and what ↩ does on it.
    struct Entry {
        enum Kind {
            /// Opens the snippets window.
            case snippets
            /// Opens Settings > Clipboard, while no kind is kept.
            case turnOn
            case clip(ClipboardItem)
            /// A snippet the filter found (S-030): ↩ pastes it.
            case snippet(Snippet)
            /// "No clips match": a hint, ↩ does nothing.
            case noMatch
        }

        var kind: Kind
        var row: LaunchResult

        var clip: ClipboardItem? {
            if case .clip(let item) = kind { item } else { nil }
        }
    }

    static let allSnippets = "All Snippets"
    static let snippetsHint = "View all snippets and collections"
    static let filterHint = "Type to filter clipboard and snippets"
    static let turnOn = "Turn On Clipboard History…"
    static let isOff = "Clipboard history is off"

    let history: ClipboardHistory?
    /// The snippets a filter finds, best first.
    let findSnippets: (String) -> [Snippet]
    let settings: ClipboardSettings
    /// Opened from the launcher's Clipboard History row: Esc goes back to the results.
    let fromLauncher: Bool
    var filter = "" {
        didSet { if filter != oldValue { refresh() } }
    }
    private(set) var entries: [Entry] = []
    private(set) var selection = 0

    init(history: ClipboardHistory?, snippets: @escaping (String) -> [Snippet] = { _ in [] },
         settings: ClipboardSettings = .shared, fromLauncher: Bool = false) {
        self.history = history
        findSnippets = snippets
        self.settings = settings
        self.fromLauncher = fromLauncher
        refresh()
    }

    var rows: [LaunchResult] { entries.map(\.row) }
    var selected: Entry? { entries.indices.contains(selection) ? entries[selection] : nil }

    func move(_ delta: Int) { select(selection + delta) }

    func select(_ index: Int) {
        guard entries.indices.contains(index) else { return }
        selection = index
    }

    /// The footer: when and where the selected clip was copied, or how to filter.
    var footer: String {
        guard let selected else { return Self.filterHint }
        switch selected.kind {
        case .clip(let item):
            let when = item.copiedAt.formatted(date: .abbreviated, time: .shortened)
            return item.sourceApp.isEmpty ? "Copied \(when)" : "Copied \(when) from \(item.sourceApp)"
        case .turnOn: return "Choose what Reach keeps in Settings > Clipboard."
        case .snippet(let snippet): return "Snippet in \(snippet.collection?.name ?? AppModel.defaultCollection)"
        case .snippets, .noMatch: return Self.filterHint
        }
    }

    /// The newest clip is selected, so ↩ pastes what was copied last; with
    /// only snippets found, the best snippet.
    private func refresh() {
        let clips = (history?.items ?? []).filter { ClipboardPolicy.matches(filter, text: $0.text, app: $0.sourceApp) }
        var list: [Entry] = []
        if filter.isEmpty || Matcher.score(query: filter, title: Self.allSnippets) != nil {
            list.append(Entry(kind: .snippets, row: LaunchResult(id: "clipboard:snippets", title: Self.allSnippets, subtitle: "",
                                                                 icon: .symbol("text.quote"), url: nil, acts: true)))
        }
        if !settings.isOn, filter.isEmpty {
            list.append(Entry(kind: .turnOn, row: LaunchResult(id: "clipboard:turn-on", title: Self.turnOn, subtitle: "",
                                                               icon: .symbol("gearshape"), url: nil, acts: true)))
        }
        list += clips.map { Entry(kind: .clip($0), row: Self.row(for: $0)) }
        if !filter.isEmpty {
            list += findSnippets(filter).map { Entry(kind: .snippet($0), row: SnippetSource.row(for: $0)) }
        }
        if list.isEmpty {
            list.append(Entry(kind: .noMatch, row: LaunchResult(id: "clipboard:none", title: "No clips match “\(filter)”",
                                                                subtitle: "", icon: .symbol("magnifyingglass"), url: nil)))
        }
        entries = list
        selection = list.firstIndex { $0.clip != nil } ?? list.firstIndex {
            if case .snippet = $0.kind { true } else { false }
        } ?? 0
    }

    private static func row(for item: ClipboardItem) -> LaunchResult {
        let kind = item.clipKind
        let icon: LaunchResult.Icon = switch kind {
        case .text: .symbol("doc.plaintext")
        case .image: .symbol("photo")
        case .files: .file(item.text.split(separator: "\n").first.map(String.init) ?? "/")
        }
        return LaunchResult(id: "clip:\(item.persistentModelID.hashValue)", title: ClipboardPolicy.title(kind: kind, text: item.text),
                            subtitle: item.sourceApp.isEmpty ? "" : "From \(item.sourceApp)", icon: icon, url: nil,
                            kindLabel: kind.title, badge: badge(item.copiedAt), acts: true)
    }

    /// "14:02" for today, "28 Oct" before.
    static func badge(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.day().month(.abbreviated))
    }
}
