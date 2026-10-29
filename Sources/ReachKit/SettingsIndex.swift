import Foundation

/// One setting that Search Settings can find (S-036): its label as on screen,
/// the page it lives on (a `SettingsTab` raw value) and its section there.
public struct SettingsEntry: Hashable, Sendable, Identifiable {
    public let title: String
    public let page: String
    public let section: String
    /// Other words people may type for it, such as "autostart" for Open at login.
    public let words: String

    public var id: String { "\(page)/\(section)/\(title)" }

    public init(_ title: String, page: String, section: String = "", words: String = "") {
        self.title = title
        self.page = page
        self.section = section
        self.words = words
    }
}

/// Every label in Settings, and the search over them. A new label in a
/// Settings view needs an entry here; `SettingsIndexTests` reads the views
/// and fails for a label that is missing.
public enum SettingsIndex {
    /// Finds settings whose label, section, page or extra words start with every
    /// word of `query`. Labels that start with the query come first.
    public static func search(_ query: String, in entries: [SettingsEntry] = entries,
                              pageTitles: [String: String] = [:]) -> [SettingsEntry] {
        let words = fold(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        let scored: [(SettingsEntry, Int, Int)] = entries.enumerated().compactMap { index, entry in
            let title = fold(entry.title)
            let haystack = [title, fold(entry.section), fold(pageTitles[entry.page] ?? entry.page), fold(entry.words)]
                .joined(separator: " ")
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            guard words.allSatisfy({ word in haystack.contains { $0.hasPrefix(word) } }) else { return nil }
            // A label that starts with the query comes first, then labels with more of its words.
            let titleWords = title.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            let inTitle = words.filter { word in titleWords.contains { $0.hasPrefix(word) } }.count
            let score = title.hasPrefix(fold(query).trimmingCharacters(in: .whitespaces)) ? words.count + 1 : inTitle
            return (entry, score, index)
        }
        var seen = Set<String>()
        return scored.sorted { ($0.1, -$0.2) > ($1.1, -$1.2) }
            .map(\.0)
            .filter { seen.insert($0.id).inserted }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// The fixed labels, page by page, and the labels that come from the
    /// lists in ReachKit (file kinds, system commands, actions).
    public static let entries: [SettingsEntry] = fixed
        + FileMode.allCases.map { SettingsEntry($0.title, page: "search", section: "Keywords", words: "file keyword") }
        + HiddenKind.allCases.map { SettingsEntry($0.title, page: "search", section: "Don't Show", words: "hide exclude file") }
        + ResultType.allCases.map { SettingsEntry($0.title, page: "search", section: "Default Results", words: "file kind") }
        + SystemCommand.allCases.map { SettingsEntry($0.title, page: "system", section: "Commands", words: "keyword confirm") }
        + FileAction.allCases.map { SettingsEntry($0.title, page: "actions", section: "Action Panel", words: "action") }

    private static func page(_ page: String, _ section: String, _ titles: [String], words: String = "") -> [SettingsEntry] {
        titles.map { SettingsEntry($0, page: page, section: section, words: words) }
    }

    private static let fixed: [SettingsEntry] =
        page("general", "Launcher", ["Launcher"])
        + page("general", "Launcher", ["Open at login"], words: "autostart startup boot")
        + page("general", "Launcher", ["Launcher hotkey"], words: "shortcut key")
        + page("general", "Permissions", ["Permissions", "Accessibility", "Grant Permissions…"], words: "privacy access")
        + page("search", "Keywords", ["Keywords"], words: "file open find")
        + page("search", "Don't Show", ["Don't Show"], words: "hide exclude")
        + page("search", "Default Results", ["Default Results"], words: "files kinds")
        + page("search", "Search Scope", ["Search Scope"], words: "folders paths where")
        + page("search", "Fallbacks", ["Fallbacks", "Show fallbacks", "Web searches", "Edit Fallbacks…"], words: "no results")
        + page("web", "Web Search", ["Built-in Searches", "Custom Searches", "Add Custom Search…", "Only show enabled searches"],
               words: "google wikipedia amazon engine")
        + page("web", "URLs", ["URLs", "Recognize URLs", "Treat URL schemes without // as URLs",
                               "Scheme for a domain typed without one"], words: "link web address https")
        + page("web", "URL History", ["URL History", "Remember URLs you open from Reach", "Remove a URL when not used for"],
               words: "link forget clear")
        + page("system", "Commands", ["Commands", "Confirm"], words: "sleep lock restart shut down")
        + page("system", "Sound", ["Sound"], words: "volume mute")
        + page("system", "Apps", ["Apps"], words: "quit hide force")
        + page("system", "Disks", ["Disks"], words: "eject")
        + page("terminal", "Shell Commands", ["Shell Commands", "Prefix", "Application"], words: "terminal shell command iterm >")
        + page("dictionary", "Keywords", ["Keywords", "Spelling language"], words: "define spell word")
        + page("contacts", "Contacts", ["Contacts", "Search contacts", "Email", "Email a Contact"], words: "people person")
        + page("contacts", "Names", ["Names", "Show last name first", "Show title", "Show job title"], words: "people person")
        + page("contacts", "Access", ["Access"], words: "privacy permission")
        + page("clipboard", "History", ["History", "Keep Plain Text", "Keep Images", "Keep File Lists", "Keep for"],
               words: "clipboard copy retention")
        + page("clipboard", "Viewer", ["Viewer", "Show the clipboard viewer"], words: "clipboard hotkey")
        + page("clipboard", "Access", ["Access"], words: "clipboard privacy paste")
        + page("clipboard", "Merging", ["Merging", "Append with ⌘C twice", "Separator", "Play a sound when appending",
                                        "Put the merged text on the clipboard"], words: "clipboard combine")
        + page("clipboard", "Advanced", ["Advanced", "Paste on Return", "Max Clip Size", "Ignore Apps"],
               words: "clipboard exclude size")
        + page("snippets", "Expansion", ["Expansion", "Expand keywords while typing"], words: "snippet text auto")
        + page("snippets", "Access", ["Access"], words: "snippet privacy accessibility")
        + page("actions", "Action Panel", ["Action Panel"], words: "actions")
        + page("actions", "Selection", ["Selection", "Act on the selection"], words: "hotkey selected")
        + page("previews", "Quick Look", ["Quick Look", "Tap ⇧ to Quick Look the selected result"], words: "preview shift")
        + page("previews", "Quick Look", ["Skip These File Types", "Skip These Folders"], words: "preview exclude ignore")
        + page("appearance", "Theme", ["Theme", "Duplicate Theme", "Show on Desktop Picture", "Accent color"],
               words: "look color colour dark light font")
        + page("appearance", "Launcher Options", ["Launcher Options…", "Visible results", "Show subtext",
                                                  "Hide result shortcuts", "Show on", "Show menu bar icon",
                                                  "Results", "Position", "Menu Bar"],
               words: "screen rows icon")
        + page("advanced", "Learning", ["Learning", "Clear Learning…", "Clear Learning"], words: "knowledge ranking forget reset")
        + page("advanced", "Query History", ["Query History", "Remember typed queries", "Restore the last query"],
               words: "previous last typed ctrl up down")
        + page("advanced", "Alternative Actions", ["Alternative Actions", "Nothing"],
               words: "modifier return control option command fallback web search")
        + page("advanced", "Sync", ["Sync", "Sync folder", "Set Folder…", "Reveal", "Stop Syncing", "Restart Now", "Later"],
               words: "icloud drive dropbox another mac share backup")
}
