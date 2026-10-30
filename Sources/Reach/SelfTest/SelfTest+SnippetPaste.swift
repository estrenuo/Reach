import AppKit
import ReachKit
import SwiftData

extension SelfTest {
    /// S-030: `snip <name>` finds snippets and ↩ pastes one with its
    /// placeholders filled in; the clipboard from before comes back. A private
    /// pasteboard and a recorder for ⌘V, so neither the real clipboard nor another app is touched.
    static func checkSnippetPaste(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let context = model.container.mainContext
        let pasteboard = NSPasteboard.withUniqueName()
        let settings = ClipboardSettings.shared
        let history = ClipboardHistory(pasteboard: pasteboard, context: context, settings: settings)
        history.frontApp = { ("TextEdit", "com.apple.TextEdit") }
        var pastes = 0
        let (paster, board, delay) = (lm.paster, lm.pasteboard, lm.restoreDelay)
        lm.paster = { pastes += 1 }
        lm.pasteboard = pasteboard
        lm.restoreDelay = .milliseconds(100)
        lm.clipboard = history
        let collection = SnippetCollection(name: "Paste test")
        context.insert(collection)
        func add(_ name: String, keyword: String, text: String) {
            let snippet = Snippet(name: name)
            snippet.keyword = keyword
            snippet.text = text
            snippet.collection = collection
            context.insert(snippet)
        }
        add("Zebra greeting", keyword: "zgr", text: "Hallo {clipboard}, het is {date}.\nTweede regel")
        add("Zebra address", keyword: "zad", text: "Stationsplein 1")
        try? context.save()
        defer {
            launcher.hide()
            (lm.paster, lm.pasteboard, lm.restoreDelay) = (paster, board, delay)
            lm.clipboard = nil
            context.delete(collection)
            history.items.forEach(context.delete)
            try? context.save()
            settings.reset()
            pasteboard.releaseGlobally()
        }

        await showAgain(launcher)
        lm.query = "sni"
        check("typing “sni” offers Paste a Snippet…", lm.results.first?.completes == "snip ",
              lm.results.map(\.title).joined(separator: ", "))
        lm.query = "snip"
        let names = lm.results.filter { $0.pastes != nil }.map(\.title)
        check("“snip” alone lists the snippets by name, the first one selected",
              names.firstIndex(of: "Zebra address").map { names.firstIndex(of: "Zebra greeting") == $0 + 1 } == true
                && lm.selection == 0 && lm.results.first?.pastes != nil,
              names.joined(separator: ", "))
        // Snippets: typing "snippets" offers the Reach window; ↩ opens it.
        let openSnippets = lm.openSnippets
        var opened = 0
        lm.openSnippets = { opened += 1 }
        lm.query = "snippets"
        let edit = lm.results.firstIndex { $0.opensSnippets }
        check("typing “snippets” offers the Snippets window", edit != nil, lm.results.map(\.title).joined(separator: ", "))
        if let edit {
            lm.open(at: edit)
            check("↩ on Snippets opens the Reach window", opened == 1 && !launcher.isVisible)
        }
        lm.openSnippets = openSnippets
        await showAgain(launcher)

        lm.query = "snip zgr"
        let row = lm.results.first
        check("the keyword finds the snippet, first, with its first line and keyword",
              row?.title == "Zebra greeting" && row?.subtitle == "Hallo {clipboard}, het is {date}." && row?.badge == "zgr",
              lm.results.map(\.title).joined(separator: ", "))
        lm.query = "snip zebra add"
        check("the name finds it too", lm.results.first?.title == "Zebra address")
        lm.query = "snip zzqx"
        check("a name without snippets says so", lm.results.first?.title == "No snippet matches “zzqx”")

        settings.keep[.text] = true
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("Ada", forType: .string)
        history.poll()
        let clips = history.items.count
        lm.query = "snip zgr"
        lm.open(at: 0)
        let today = SnippetText.expand("{date}", date: .now, clipboard: nil)
        check("↩ pastes the snippet with {clipboard} and {date} filled in",
              pasteboard.string(forType: .string) == "Hallo Ada, het is \(today).\nTweede regel" && pastes == 1 && !launcher.isVisible,
              pasteboard.string(forType: .string) ?? "nothing")
        check("the pasted snippet is not kept in Clipboard History", !history.poll() && history.items.count == clips)
        try? await Task.sleep(for: .milliseconds(300))
        check("then the clipboard from before comes back", pasteboard.string(forType: .string) == "Ada")
        check("and is not kept again as a new copy", !history.poll() && history.items.count == clips)

        await showAgain(launcher)
        lm.query = "snip zad"
        lm.open(at: 0)
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("copied meanwhile", forType: .string)
        try? await Task.sleep(for: .milliseconds(300))
        check("a copy made right after the paste is kept, not overwritten",
              pasteboard.string(forType: .string) == "copied meanwhile" && pastes == 2)

        await showAgain(launcher)
        pasteboard.declareTypes([.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")], owner: nil)
        pasteboard.setString("secret-password", forType: .string)
        lm.query = "snip zgr"
        lm.open(at: 0)
        check("a private copy is not filled in for {clipboard}",
              pasteboard.string(forType: .string)?.hasPrefix("Hallo , het is") == true && pastes == 3)
        try? await Task.sleep(for: .milliseconds(300))
        check("nor put back afterwards: the clipboard is left empty",
              pasteboard.string(forType: .string) == nil && pasteboard.pasteboardItems?.isEmpty != false)

        await showAgain(launcher)
        launcher.toggleClipboard()
        lm.viewer?.filter = "zebra gr"
        let viewer = lm.viewer
        check("the clipboard viewer finds snippets when you type",
              viewer?.selected?.row.title == "Zebra greeting" && viewer?.footer == "Snippet in Paste test",
              viewer?.rows.map(\.title).joined(separator: ", ") ?? "no viewer")
        lm.useClip(at: viewer?.selection ?? 0)
        check("↩ on a snippet there pastes it", pastes == 4 && pasteboard.string(forType: .string)?.hasPrefix("Hallo") == true)
        try? await Task.sleep(for: .milliseconds(300))
    }
}
