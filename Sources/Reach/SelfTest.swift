import AppKit
import SwiftData
import ReachKit

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/Reach-self.store ~/Applications/Reach.app/Contents/MacOS/Reach --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            let context = model.container.mainContext
            func snippets() -> [Snippet] { (try? context.fetch(FetchDescriptor<Snippet>())) ?? [] }

            let before = snippets().count
            model.addSnippet()
            check("New Snippet adds one snippet", snippets().count == before + 1)
            check("the new snippet is selected", model.selection != nil)

            if let snippet = snippets().first(where: { $0.id == model.selection }) {
                snippet.isStarred.toggle()
                check("starring a snippet marks it starred", snippet.isStarred)
                context.delete(snippet)
                try? context.save()
                check("deleting the snippet removes it", snippets().count == before)
            }
            check("names are cleaned", SnippetName.clean("  Email   signature ") == "Email signature")

            await checkLauncher(model: model)

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    /// S-001 to S-007: the launcher, driven with real key events.
    private static func checkLauncher(model: AppModel) async {
        guard let launcher = model.launcher else {
            check("the launcher exists", false)
            return
        }
        let lm = model.launcherModel
        var opened: [URL] = []
        lm.opener = { opened.append($0); return true }
        await lm.apps.refreshNow()
        func key(_ code: UInt16, _ characters: String, command: Bool = false) -> Bool {
            guard let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: command ? .command : [],
                timestamp: 0, windowNumber: launcher.panel.windowNumber, context: nil,
                characters: characters, charactersIgnoringModifiers: characters,
                isARepeat: false, keyCode: code) else { return false }
            return launcher.handle(event)
        }

        // S-001
        HotkeyCenter.shared.onPress()
        check("the hotkey shows the launcher", launcher.isVisible)
        check("the launcher opens empty", lm.query.isEmpty && lm.results.isEmpty)
        HotkeyCenter.shared.onPress()
        check("the hotkey again hides it", !launcher.isVisible)
        launcher.show()
        lm.query = "saf"
        _ = key(53, "\u{1b}")
        check("Esc clears the query first", launcher.isVisible && lm.query.isEmpty)
        _ = key(53, "\u{1b}")
        check("Esc on an empty query hides it", !launcher.isVisible)
        launcher.show()
        launcher.panel.resignKey()
        check("a click outside hides it", !launcher.isVisible)
        launcher.show()
        check("the launcher is a non-activating panel", launcher.panel.styleMask.contains(.nonactivatingPanel))

        // S-002
        lm.query = "safari"
        check("typing finds Safari first", lm.results.first?.title == "Safari", lm.results.first?.title ?? "none")
        lm.query = "a"
        check("at most nine results", lm.results.count == LauncherModel.maxResults, "\(lm.results.count)")
        let start = Date.now
        for query in ["s", "sy", "sys", "syst", "syse"] { lm.query = query }
        let perKey = Date.now.timeIntervalSince(start) / 5
        check("results update within 50 ms a keystroke", perKey < 0.05, String(format: "%.1f ms", perKey * 1000))

        // S-003
        lm.query = "a"
        _ = key(126, "")
        check("↑ on the first result does nothing", lm.selection == 0)
        for _ in 0..<12 { _ = key(125, "") }
        check("↓ stops at the last result", lm.selection == lm.results.count - 1)
        let third = lm.results[2].url
        check("⌘3 is handled", key(20, "3", command: true))
        check("⌘3 opens result 3 and hides", opened.last == third && !launcher.isVisible)
        launcher.show()
        lm.query = "safari"
        _ = key(36, "\r")
        check("Return opens the selected result", opened.last?.lastPathComponent == "Safari.app" && !launcher.isVisible)
        launcher.show()
        lm.opener = { _ in false }
        lm.query = "safari"
        _ = key(36, "\r")
        let error = lm.errors.values.first ?? ""
        check("a failed open shows the error and stays open", launcher.isVisible && error.hasPrefix("Unable to open “Safari”"), error)
        lm.opener = { opened.append($0); return true }

        // S-005
        lm.query = "open "
        check("a bare file keyword shows the hint", lm.results.first?.title == "Type a file name" && lm.results.first?.isOpenable == false)
        let asked = Date.now
        lm.query = "open BRIEF.md"
        var waited = 0.0
        while lm.results.first?.isOpenable != true, waited < 3 {
            try? await Task.sleep(for: .milliseconds(20))
            waited = Date.now.timeIntervalSince(asked)
        }
        check("file search finds BRIEF.md", lm.results.contains { $0.title == "BRIEF.md" },
              lm.results.map(\.title).joined(separator: ", "))
        check("file search answers within 200 ms", waited < 0.2, String(format: "%.0f ms", waited * 1000))
        _ = key(36, "\r")
        check("Return opens the file", opened.last?.lastPathComponent == "BRIEF.md")
        launcher.show()
        lm.query = "'zzqxvnothing"
        for _ in 0..<150 where lm.results.first?.id != "hint:nofiles" { try? await Task.sleep(for: .milliseconds(20)) }
        check("no file matches says so, with the fallbacks", lm.results.first?.id == "hint:nofiles" && lm.results.count == 4)

        // S-006
        lm.query = "zzqxv nothing"
        check("no results shows three fallbacks", lm.results.count == 3 && lm.results.first?.title == "Search Google for “zzqxv nothing”")
        check("the fallback URL is encoded", lm.results.first?.url?.absoluteString.hasSuffix("q=zzqxv%20nothing") == true)
        // S-007: ⌘, in the launcher opens Settings.
        check("⌘, is handled", key(43, ",", command: true))
        try? await Task.sleep(for: .seconds(1))
        let settings = NSApp.windows.first { $0.isVisible && $0.identifier?.rawValue.contains("Settings") == true }
        check("⌘, hides the launcher and opens Settings", !launcher.isVisible && settings != nil)
        settings?.close()

        // S-007, with test hotkeys: the user's own hotkey belongs to the real app.
        let hotkeys = HotkeyCenter.shared
        let first = KeyCombo(keyCode: 40, modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.command | KeyCombo.shift)
        let second = KeyCombo(keyCode: 37, modifiers: first.modifiers)
        check("a new hotkey is taken", hotkeys.change(to: first, keyName: "K") && hotkeys.combo == first)
        _ = hotkeys.change(to: second, keyName: "L")
        check("the old hotkey stops working", hotkeys.isFree(first) && !hotkeys.isFree(second))
        hotkeys.suspend()
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
