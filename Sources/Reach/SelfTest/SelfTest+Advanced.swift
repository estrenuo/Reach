import AppKit
import ReachKit

extension SelfTest {
    /// S-038: Clear Learning, ⌃↑/⌃↓ through the typed queries, the last query
    /// back within 5 minutes, and ⌃↩/⌥↩/⌘↩ running the chosen web search.
    static func checkAdvanced(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let options = AdvancedOptions.shared
        options.reset()
        let saved = (lm.opener, lm.now)
        defer { (lm.opener, lm.now) = saved; options.reset(); lm.queryHistory.clear() }
        var opened: [URL] = []
        lm.opener = { opened.append($0); return true }
        let clock = Shared(ProcessInfo.processInfo.systemUptime)
        lm.now = { clock.value }
        func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags) -> Bool {
            var flags = flags
            if (123...126).contains(code) { flags.formUnion([.numericPad, .function]) }
            let chars = code == 36 ? "\r" : code == 126 ? "\u{F700}" : "\u{F701}"
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: launcher.panel.windowNumber,
                    context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false,
                    keyCode: code) else { return false }
            return launcher.handle(event)
        }

        // Learning
        let learning = Learning(container: model.container)
        learning.record(query: "selftest-adv", resultID: "a")
        check("Learning remembers a pick", learning.count > 0)
        learning.clear()
        check("Clear Learning empties the ranking store", learning.count == 0 && learning.picks(for: "selftest-adv").isEmpty)

        // Query history
        lm.queryHistory.clear()
        for query in ["first query", "second query"] {
            launcher.show()
            lm.query = query
            launcher.hide()
        }
        launcher.show()
        check("the launcher opens empty with Restore off", lm.query.isEmpty, lm.query)
        _ = key(126, .control)
        check("⌃↑ brings back the last query", lm.query == "second query", lm.query)
        _ = key(126, .control)
        check("⌃↑ again the one before", lm.query == "first query", lm.query)
        _ = key(125, .control)
        _ = key(125, .control)
        check("⌃↓ walks back to an empty field", lm.query.isEmpty, lm.query)
        launcher.hide()

        options.restoresLastQuery = true
        launcher.show()
        check("with Restore on, the last query comes back", lm.query == "second query", lm.query)
        launcher.hide()
        clock.value += QueryHistory.restoreWindow + 1
        launcher.show()
        check("after 5 minutes it does not", lm.query.isEmpty, lm.query)
        launcher.hide()
        options.remembersQueries = false
        launcher.show()
        check("with the history off, ⌃↑ brings nothing back", !lm.walkHistory(older: true) && lm.query.isEmpty, lm.query)
        launcher.hide()
        options.reset()

        // Alternative actions
        let searches = WebSearchSettings.shared.searches.filter(\.takesQuery)
        guard let search = searches.first else { return check("a web search to map", false) }
        launcher.show()
        lm.query = "bowler hat"
        try? await Task.sleep(for: .milliseconds(300))
        check("⌥↩ with nothing chosen keeps what Return did", !lm.runAlternative(.option) && opened.isEmpty)
        options.alternatives[ReturnModifier.option.rawValue] = search.id
        check("⌥↩ runs the chosen search with the query", key(36, .option)
              && opened.last == WebSearchURL.make(template: search.url, query: "bowler hat"),
              opened.last?.absoluteString ?? "nothing opened")
        check("and hides the launcher", !launcher.isVisible)
        launcher.hide()
    }
}
