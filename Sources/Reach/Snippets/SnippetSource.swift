import AppKit
import ReachKit
import SwiftData

/// `snip <name>` (S-030): snippets by name or keyword. Return pastes one into
/// the app in front; `snip` alone lists them all by name.
final class SnippetSource: ResultSource {
    static let keyword = "snip"
    static let icon = LaunchResult.Icon.symbol("text.quote")
    static let noSnippets = "No Snippets"
    /// Set at launch; nil leaves `snip` without snippets.
    var context: ModelContext?

    /// Every snippet, by name.
    func all() -> [Snippet] {
        guard let context else { return [] }
        let order = [SortDescriptor(\Snippet.name, comparator: .localizedStandard)]
        return (try? context.fetch(FetchDescriptor<Snippet>(sortBy: order))) ?? []
    }

    /// The snippets `text` finds, best first, equal scores by name; all of them for an empty text.
    func matches(_ text: String) -> [Snippet] {
        let snippets = all()
        guard !text.isEmpty else { return snippets }
        return snippets.enumerated()
            .compactMap { index, snippet in
                SnippetSearch.score(text, name: snippet.name, keyword: snippet.keyword).map { (snippet, $0, index) }
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }
            .map(\.0)
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        let words = text.lowercased() == Self.keyword ? "" : DictionaryLookup.word(in: text, keyword: Self.keyword)
        guard let words else { return offer(text) }
        let found = matches(words)
        guard !found.isEmpty else {
            return words.isEmpty || context == nil
                ? [hint(Self.noSnippets, subtitle: "Add snippets in the Reach window")]
                : [hint("No snippet matches “\(words)”")]
        }
        return found.prefix(LauncherModel.maxResults).map { Scored(result: Self.row(for: $0), score: 0) }
    }

    static func row(for snippet: Snippet) -> LaunchResult {
        LaunchResult(id: "snippet:\(snippet.uuid)", title: snippet.name, subtitle: SnippetText.preview(snippet.text),
                     icon: icon, url: nil, kindLabel: "Snippet", isPinned: true, badge: snippet.keyword, pastes: snippet.text)
    }

    /// Part of the keyword (`sni`): a row that completes to `snip `.
    private func offer(_ text: String) -> [Scored] {
        guard text.count >= 2, text.count < Self.keyword.count, Self.keyword.hasPrefix(text.lowercased()),
              let score = Matcher.score(query: text, title: Self.keyword), score >= SystemCommands.minimumScore else { return [] }
        return [Scored(result: LaunchResult(id: "snippets:offer", title: "Paste a Snippet…", subtitle: "Press ↩ to type a name",
                                            icon: Self.icon, url: nil, kindLabel: "Snippet",
                                            completes: Self.keyword + " "), score: score)]
    }

    private func hint(_ title: String, subtitle: String = "") -> Scored {
        Scored(result: LaunchResult(id: "hint:snippets", title: title, subtitle: subtitle, icon: Self.icon, url: nil), score: 0)
    }
}

extension LauncherModel {
    /// Return on a snippet: fills in its placeholders, pastes it into the app in
    /// front, and puts the clipboard from before back once the paste is done.
    /// The snippet is marked transient, so no clipboard history keeps it.
    /// A private copy, like a password, is neither filled in nor put back: the
    /// clipboard is left empty, so the password manager's own clearing still holds.
    func pasteSnippet(_ text: String) {
        let board = pasteboard
        let isPrivate = SnippetClipboard.isPrivate(board)
        let filled = SnippetText.expand(text, date: .now, clipboard: isPrivate ? nil : board.string(forType: .string))
        let saved = isPrivate ? [] : SnippetClipboard.save(board)
        board.clearContents()
        let item = NSPasteboardItem()
        item.setString(filled, forType: .string)
        item.setData(Data(), forType: SnippetClipboard.transient)
        board.writeObjects([item])
        let ours = board.changeCount
        onHide()
        paster()
        Task { [weak self, restoreDelay] in
            try? await Task.sleep(for: restoreDelay)
            // Something copied in the meantime wins.
            guard board.changeCount == ours else { return }
            SnippetClipboard.restore(saved, to: board)
            self?.clipboard?.skipCurrent()
        }
    }
}

/// Keeps a copy of the clipboard while a snippet passes through it.
enum SnippetClipboard {
    static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    /// Marked private or machine-made (nspasteboard.org), like a password.
    static func isPrivate(_ board: NSPasteboard) -> Bool {
        !Set(board.types?.map(\.rawValue) ?? []).isDisjoint(with: ClipboardPolicy.ignoredTypes)
    }

    /// Copies every item's data now: the items themselves die with `clearContents`.
    static func save(_ board: NSPasteboard) -> [NSPasteboardItem] {
        (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    static func restore(_ items: [NSPasteboardItem], to board: NSPasteboard) {
        board.clearContents()
        if !items.isEmpty { board.writeObjects(items) }
    }
}
