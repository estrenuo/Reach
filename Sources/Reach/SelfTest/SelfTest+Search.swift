import AppKit
import Quartz
import SwiftData
import ReachKit

extension SelfTest {
    /// S-014: the file search keywords, Don't Show, Default Results and the scope.
    /// Settings are not saved in a test run, and reset() puts them back afterwards.
    static func checkSearch(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let settings = SearchSettings.shared
        var ran: [(ActionPanel.Item, [URL])] = []
        lm.perform = { item, urls in ran.append((item, urls)); return true }
        var opened: [URL] = []
        lm.opener = { opened.append($0); return true }
        /// Waits up to 3 s for Spotlight to put a result first that passes `done`.
        func wait(until done: () -> Bool) async {
            for _ in 0..<150 where !done() { try? await Task.sleep(for: .milliseconds(20)) }
        }
        launcher.show()

        lm.query = "in "
        check("in with no words asks for words", lm.results.first?.title == "Type words from inside a file")
        lm.query = "tags "
        check("tags with no tag asks for one", lm.results.first?.title == "Type a tag")

        lm.query = "find BRIEF.md"
        await wait { lm.results.contains { $0.title == "BRIEF.md" } }
        let brief = lm.results.firstIndex { $0.title == "BRIEF.md" }
        check("find finds BRIEF.md", brief != nil, lm.results.map(\.title).joined(separator: ", "))
        if let brief { lm.open(at: brief) }
        check("↩ on a find result reveals it in Finder", ran.last?.0 == .action(.reveal)
              && ran.last?.1.first?.lastPathComponent == "BRIEF.md" && opened.isEmpty, "\(ran.map(\.0))")

        launcher.show()
        settings.keywords[.reveal].isOn = false
        lm.query = "find "
        check("find that is off is a normal search", lm.results.first?.id != "hint:files"
              && settings.queryKind("find x") == .normal("find x"))
        settings.keywords[.reveal].isOn = true
        settings.keywords[.reveal].word = "reveal"
        lm.query = "reveal "
        check("a renamed keyword works under its new word", lm.results.first?.title == "Type a file name")

        settings.hidden.insert(.images)
        lm.query = "open png"
        await wait { lm.results.first?.id != nil && lm.results.first?.id != "hint:files" }
        let images = lm.results.filter { ($0.url?.pathExtension.lowercased() ?? "") == "png" }
        check("Don't Show Images leaves PNG files out", images.isEmpty, images.map(\.title).joined(separator: ", "))

        settings.types = [.folders]
        lm.query = "Documents"
        await wait { lm.results.contains { $0.isFolder && $0.title == "Documents" } }
        check("Default Results with Folders adds folders to a normal query",
              lm.results.contains { $0.isFolder && $0.title == "Documents" }, lm.results.map(\.title).joined(separator: ", "))
        settings.types = []

        settings.scope = ["/System/Applications"]
        await lm.apps.refreshNow()
        let safari = lm.apps.results(for: "safari").contains { $0.0.title == "Safari" }
        let notes = lm.apps.results(for: "notes").contains { $0.0.title == "Notes" || $0.0.title == "Notities" }
        check("the scope decides where apps come from", !safari && notes)

        settings.reset()
        await lm.apps.refreshNow()
        check("Reset puts the standard scope back", settings.scope == SearchSettings.standardScope
              && lm.apps.results(for: "safari").contains { $0.0.title == "Safari" })
        launcher.hide()
    }
}
