import AppKit
import ReachKit

extension SelfTest {
    /// S-026: ⌃⌥⌘C shows the clips in the launcher, typing filters them, and
    /// ↩ pastes the selected one; it moves to the top. A private pasteboard
    /// and a recorder for ⌘V, so neither the real clipboard nor another app is touched.
    static func checkClipboardViewer(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let settings = ClipboardSettings.shared
        let pasteboard = NSPasteboard.withUniqueName()
        let context = model.container.mainContext
        let history = ClipboardHistory(pasteboard: pasteboard, context: context, settings: settings)
        var now = Date.now
        history.frontApp = { ("TextEdit", "com.apple.TextEdit") }
        history.now = { now }
        var pastes = 0
        var opened: [String] = []
        let (paster, openSnippets, openSettings) = (lm.paster, lm.openSnippets, lm.openSettings)
        lm.paster = { pastes += 1 }
        lm.openSnippets = { opened.append("snippets") }
        lm.openSettings = { opened.append("settings") }
        lm.clipboard = history
        defer {
            launcher.hide()
            (lm.paster, lm.openSnippets, lm.openSettings) = (paster, openSnippets, openSettings)
            lm.clipboard = nil
            history.items.forEach(context.delete)
            try? context.save()
            settings.reset()
            AppModel.shared.settingsTab = .general
            pasteboard.releaseGlobally()
        }

        check("the clipboard hotkey is ⌃⌥⌘C", KeyCombo.clipboard.display(key: "C") == "⌃⌥⌘C")
        launcher.toggleClipboard()
        var viewer = lm.viewer
        check("⌃⌥⌘C shows the clipboard viewer in the launcher", launcher.isVisible && viewer != nil)
        check("with the history off: All Snippets, then Turn On Clipboard History…",
              viewer?.rows.map(\.title) == [ClipboardViewer.allSnippets, ClipboardViewer.turnOn],
              viewer?.rows.map(\.title).joined(separator: ", ") ?? "no viewer")
        check("the empty viewer hints at snippets and filtering",
              viewer?.selected?.row.title == ClipboardViewer.allSnippets && viewer?.footer == ClipboardViewer.filterHint)
        lm.useClip(at: 1)
        check("↩ on Turn On… opens Settings > Clipboard",
              opened.last == "settings" && AppModel.shared.settingsTab == .clipboard && !launcher.isVisible)
        await showAgain(launcher)
        launcher.toggleClipboard()
        lm.useClip(at: 0)
        check("↩ on All Snippets opens the snippets window", opened.last == "snippets" && !launcher.isVisible)

        settings.keep[.text] = true
        for text in ["First clip", "Second clip\nwith a second line", "Third clip"] {
            now += 60
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(text, forType: .string)
            history.poll()
        }
        await showAgain(launcher)
        launcher.toggleClipboard()
        viewer = lm.viewer
        check("the clips show newest first, below All Snippets, the newest selected",
              viewer?.rows.map(\.title) == [ClipboardViewer.allSnippets, "Third clip", "Second clip", "First clip"]
                && viewer?.selected?.clip?.text == "Third clip",
              viewer?.rows.map(\.title).joined(separator: ", ") ?? "no viewer")
        check("the footer says where the clip came from", viewer?.footer.hasSuffix("from TextEdit") == true, viewer?.footer ?? "")
        viewer?.filter = "second line"
        check("typing filters the clips by their whole text",
              viewer?.rows.map(\.title) == ["Second clip"] && viewer?.selected?.clip?.text.hasPrefix("Second") == true,
              viewer?.rows.map(\.title).joined(separator: ", ") ?? "")
        viewer?.filter = "zzqx"
        check("a filter without clips says so", viewer?.rows.first?.title == "No clips match “zzqx”")
        viewer?.filter = "second"
        let before = history.items.count
        lm.useClip(at: viewer?.selection ?? 0)
        check("↩ puts the clip on the clipboard and pastes it",
              pasteboard.string(forType: .string) == "Second clip\nwith a second line" && pastes == 1 && !launcher.isVisible)
        check("the used clip moves to the top, without a copy of it",
              history.items.first?.text.hasPrefix("Second") == true && history.items.count == before && !history.poll())

        settings.pastesOnReturn = false
        await showAgain(launcher)
        launcher.toggleClipboard()
        lm.viewer?.select(3)
        lm.useClip(at: 3)
        check("with Paste on Return off, ↩ only copies", pasteboard.string(forType: .string) == "First clip" && pastes == 1)
        settings.pastesOnReturn = true
        await showAgain(launcher)
        launcher.toggleClipboard()
        lm.viewer?.select(2)
        check("⌘C copies the clip without pasting",
              lm.copySelectedClip() && pasteboard.string(forType: .string) == "Second clip\nwith a second line" && pastes == 1)

        await showAgain(launcher)
        launcher.toggleClipboard()
        lm.viewer?.filter = "third"
        lm.cancelClipboard()
        check("Esc clears the filter first", lm.viewer?.filter == "" && launcher.isVisible)
        lm.cancelClipboard()
        check("then Esc hides the viewer opened with the hotkey", !launcher.isVisible)
        await showAgain(launcher)
        launcher.toggleClipboard()
        launcher.toggleClipboard()
        check("⌃⌥⌘C again hides it", !launcher.isVisible)

        await showAgain(launcher)
        lm.query = "clipb"
        let row = lm.results.firstIndex { $0.title == ClipboardSource.title }
        check("typing “clipb” offers Clipboard History", row != nil, lm.results.map(\.title).joined(separator: ", "))
        if let row { lm.open(at: row) }
        check("↩ on it opens the viewer", lm.viewer?.fromLauncher == true && launcher.isVisible)
        lm.cancelClipboard()
        check("Esc goes back to the results, query kept", lm.viewer == nil && lm.query == "clipb" && launcher.isVisible)
    }
}
