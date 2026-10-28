import AppKit
import Quartz
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

            // The launcher hides when another app takes the keyboard, as it should.
            // Name those apps, so a failure caused by someone typing is easy to tell apart.
            var intruders: Set<String> = []
            let watch = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                if let app, app != .current { MainActor.assumeIsolated { _ = intruders.insert(app.localizedName ?? "?") } }
            }
            await checkLauncher(model: model)
            await checkQuickLook(model: model)
            await checkBuffer(model: model)
            NSWorkspace.shared.notificationCenter.removeObserver(watch)
            if failures > 0, !intruders.isEmpty {
                print("NOTE \(intruders.sorted().joined(separator: ", ")) came to the front during the run. "
                      + "Focus checks fail then; run again without using the Mac.")
            }

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    /// S-001 to S-011: the launcher, driven with real key events.
    private static func checkLauncher(model: AppModel) async {
        guard let launcher = model.launcher else {
            check("the launcher exists", false)
            return
        }
        let lm = model.launcherModel
        var opened: [URL] = []
        lm.opener = { opened.append($0); return true }
        await lm.apps.refreshNow()
        /// Lets SwiftUI put the query in the field, so the cursor sits at its end.
        func settle() async { try? await Task.sleep(for: .milliseconds(100)) }
        // Like the real keyboard: arrow keys carry .numericPad and .function.
        func flags(_ code: UInt16, command: Bool) -> NSEvent.ModifierFlags {
            var flags: NSEvent.ModifierFlags = command ? .command : []
            if (123...126).contains(code) { flags.formUnion([.numericPad, .function]) }
            return flags
        }
        func key(_ code: UInt16, _ characters: String, command: Bool = false) -> Bool {
            guard let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: flags(code, command: command),
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

        // S-002 on the real app index: Safari ships with every Mac.
        lm.query = "safari"
        check("typing finds Safari first", lm.results.first?.title == "Safari", lm.results.first?.title ?? "none")
        let start = Date.now
        for query in ["s", "sy", "sys", "syst", "syse"] { lm.query = query }
        let perKey = Date.now.timeIntervalSince(start) / 5
        check("results update within 50 ms a keystroke", perKey < 0.05, String(format: "%.1f ms", perKey * 1000))

        // From here a fake source with fixed apps, so the checks run the same on any Mac.
        let realSources = lm.sources
        let fakeApps = FakeSource(["Console", "Contacts", "ColorSync Utility", "Visual Studio Code", "Calculator",
                                   "Calendar", "Chess", "Clock", "Compass", "Camera", "Cards", "Capture"])
        lm.sources = [fakeApps]
        lm.query = "c"
        check("at most nine results", lm.results.count == LauncherModel.maxResults, "\(lm.results.count)")

        // S-003
        _ = key(126, "")
        check("↑ on the first result does nothing", lm.selection == 0)
        for _ in 0..<12 { _ = key(125, "") }
        check("↓ stops at the last result", lm.selection == lm.results.count - 1)
        let third = lm.results[2].url
        check("⌘3 is handled", key(20, "3", command: true))
        check("⌘3 opens result 3 and hides", opened.last == third && !launcher.isVisible)
        launcher.show()
        lm.query = "console"
        _ = key(36, "\r")
        check("Return opens the selected result", opened.last == FakeSource.url("Console") && !launcher.isVisible)
        launcher.show()
        lm.opener = { _ in false }
        lm.query = "console"
        _ = key(36, "\r")
        let error = lm.errors.values.first ?? ""
        check("a failed open shows the error and stays open", launcher.isVisible && error.hasPrefix("Unable to open “Console”"), error)
        lm.opener = { opened.append($0); return true }

        // S-004: Console starts with "co"; open Visual Studio Code twice and it leads.
        lm.query = "co"
        check("without Learning the better text match leads", lm.results.first?.title == "Console")
        for _ in 0..<2 {
            launcher.show()
            lm.query = "co"
            if let index = lm.results.firstIndex(where: { $0.title == "Visual Studio Code" }) { lm.open(at: index) }
        }
        launcher.show()
        lm.query = "co"
        check("after two picks the result comes first", lm.results.first?.title == "Visual Studio Code",
              lm.results.first?.title ?? "none")
        let reopened = try? ModelContainer(for: Snippet.self, LearningEntry.self,
                                           configurations: ModelConfiguration(url: Store.url))
        let saved = (try? reopened?.mainContext.fetch(FetchDescriptor<LearningEntry>())) ?? []
        check("Learning survives a restart", saved.contains { $0.query == "co" && $0.count == 2 })

        // Result sources: a slow one keeps the previous results up until it answers.
        let shown = lm.results.map(\.title)
        lm.sources = [fakeApps, FakeSource(["Conveyor"], delay: .milliseconds(300))]
        lm.query = "con"
        check("a slow source keeps the previous results", lm.results.map(\.title) == shown)
        try? await Task.sleep(for: .milliseconds(500))
        check("then shows every source's answer", lm.results.contains { $0.title == "Conveyor" }
              && lm.results.contains { $0.title == "Console" })
        lm.sources = realSources

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
        // S-008 on a folder made for the test: browse with → and ←.
        let root = "/tmp/Reach-browse-selftest/"
        let fm = FileManager.default
        try? fm.removeItem(atPath: root)
        for folder in ["Alpha", "Beta", "Empty"] {
            try? fm.createDirectory(atPath: root + folder, withIntermediateDirectories: true)
        }
        for file in ["notes.txt", ".hidden", "Beta/inner.txt"] {
            fm.createFile(atPath: root + file, contents: Data("test".utf8))
        }
        lm.query = root
        check("a path lists the folder A to Z, without hidden files",
              lm.browsing != nil && lm.results.map(\.title) == ["Alpha", "Beta", "Empty", "notes.txt"],
              lm.results.map(\.title).joined(separator: ", "))
        check("browsing offers no web fallbacks", !lm.results.contains { $0.id.hasPrefix("fallback:") })
        lm.query = root + "no"
        check("typing a name filters the folder", lm.results.map(\.title) == ["notes.txt"])
        check("Tab completes a file name", key(48, "\t") && lm.query == root + "notes.txt")
        check("← drops the typed name", key(123, "") && lm.query == root)
        _ = key(125, "")
        check("→ enters the selected folder", key(124, "") && lm.query == root + "Beta/"
              && lm.results.map(\.title) == ["inner.txt"], lm.query)
        try? await Task.sleep(for: .milliseconds(100))
        let field = launcher.panel.firstResponder as? NSTextView
        check("after → the cursor is at the end of the path",
              field.map { $0.selectedRange() == NSRange(location: ($0.string as NSString).length, length: 0) } == true,
              field.map { NSStringFromRange($0.selectedRange()) } ?? "no editor")
        _ = key(124, "")
        check("→ on a file stays in the folder", lm.query == root + "Beta/")
        lm.closeActions()
        check("← goes to the parent folder", key(123, "") && lm.query == root)
        lm.query = root + "Empty/"
        check("an empty folder says so", lm.results.first?.title == "“Empty” is empty" && lm.results.count == 1)
        lm.query = root + "Nope/"
        check("a missing folder says so", lm.results.first?.title == "No folder at “/tmp/Reach-browse-selftest/Nope”")
        lm.query = "~/"
        check("← from the home folder goes to its parent", key(123, "")
              && lm.query == (NSHomeDirectory() as NSString).deletingLastPathComponent + "/", lm.query)
        lm.query = root
        _ = key(36, "\r")
        check("↩ on a folder opens it", opened.last?.resolvingSymlinksInPath() == URL(fileURLWithPath: root + "Alpha").resolvingSymlinksInPath() && !launcher.isVisible,
              "\(opened.last?.path ?? "nothing"), visible: \(launcher.isVisible)")
        // S-009: the action panel, with a recorder instead of the system.
        var performed: [ActionPanel.Item] = []
        lm.perform = { item, _ in performed.append(item); return true }
        launcher.show()
        lm.query = root + "notes"
        await settle()
        let editor = launcher.panel.firstResponder as? NSTextView
        let caret = "\(editor?.string ?? "no editor") \(editor.map { NSStringFromRange($0.selectedRange()) } ?? "")"
        check("→ on a file opens its action panel", key(124, "") && lm.actions?.target.title == "notes.txt",
              "\(lm.results.map(\.title)) caret: \(caret)")
        check("a file has every action", lm.actions?.rows.count == FileAction.allCases.count)
        lm.actions?.filter = "copy"
        check("typing filters the actions", lm.actions?.rows.map(\.title) == ["Copy Path", "Copy File"])
        _ = key(53, "\u{1b}")
        check("Esc clears the filter first", lm.actions?.filter == "" && lm.actions?.rows.count == FileAction.allCases.count)
        _ = key(53, "\u{1b}")
        check("Esc again returns to the results, query kept", lm.actions == nil && lm.query == root + "notes"
              && launcher.isVisible)
        _ = key(124, "")
        lm.actions?.filter = "path"
        _ = key(36, "\r")
        check("↩ runs the selected action and hides", performed.last == .action(.copyPath) && !launcher.isVisible)
        launcher.show()
        lm.query = root + "notes"
        await settle()
        _ = key(124, "")
        // Row 4 runs through perform; Open With… and Quick Look stay in the launcher.
        let fourth = lm.actions?.items.dropFirst(3).first
        check("⌘4 runs action 4", key(21, "4", command: true) && fourth != nil && performed.last == fourth, "\(performed)")
        launcher.show()
        lm.query = root + "notes"
        await settle()
        _ = key(124, "")
        lm.actions?.filter = "open with"
        _ = key(36, "\r")
        check("Open With… lists the apps that open the file", lm.actions?.choosingApp == true
              && lm.actions?.rows.contains { $0.title == "TextEdit" } == true,
              lm.actions?.rows.map(\.title).joined(separator: ", ") ?? "no panel")
        _ = key(53, "\u{1b}")
        check("Esc leaves the app list", lm.actions?.choosingApp == false)
        lm.actions?.filter = "browse"
        _ = key(36, "\r")
        check("Browse in Launcher shows the file's folder", lm.actions == nil && lm.browsing != nil
              && lm.query.hasSuffix("Reach-browse-selftest/"), lm.query)
        _ = key(124, "")
        check("← on an empty filter returns to the results", key(123, "") && lm.actions == nil)
        lm.query = "zzqxv nothing"
        check("→ on a web search does nothing", !key(124, "") && lm.actions == nil)
        lm.perform = { _, _ in false }
        lm.query = root + "notes"
        await settle()
        _ = key(124, "")
        lm.actions?.filter = "trash"
        _ = key(36, "\r")
        check("a failed action says so and the panel stays",
              lm.actions?.footer == "Unable to run “Move to Trash” on “notes.txt”." && launcher.isVisible,
              lm.actions?.footer ?? "no panel")
        lm.closeActions()
        // S-010: actions switched off in Settings leave the panel.
        let actionSettings = ActionSettings.shared
        let savedBefore = UserDefaults.standard.stringArray(forKey: "actions.off")
        actionSettings.set(.trash, on: false)
        launcher.show()
        lm.query = root + "notes"
        await settle()
        _ = key(124, "")
        check("a switched-off action is not in the panel", lm.actions?.rows.contains { $0.title == "Move to Trash" } == false
              && lm.actions?.rows.count == FileAction.allCases.count - 1)
        lm.actions?.filter = "trash"
        check("not even when the filter matches it", lm.actions?.rows.first?.title == "No actions match “trash”")
        lm.closeActions()
        actionSettings.off = Set(FileAction.allCases)
        _ = key(124, "")
        check("with every action off the panel says where to turn them on", lm.actions?.rows.first?.title == ActionPanel.allOff)
        lm.closeActions()
        actionSettings.off = []
        check("test runs leave the saved action settings alone",
              UserDefaults.standard.stringArray(forKey: "actions.off") == savedBefore)

        // S-011: the selection hotkey, with a fake selection.
        lm.perform = { item, _ in performed.append(item); return true }
        func pick(_ selection: Selection) { lm.readSelection = { selection } }
        pick(.files([URL(fileURLWithPath: root + "notes.txt")]))
        HotkeyCenter.shared.onSelection()
        try? await Task.sleep(for: .milliseconds(200))
        check("a Finder selection gives file actions", launcher.isVisible && lm.actions?.target.title == "notes.txt"
              && lm.actions?.rows.count == FileAction.allCases.count, lm.actions?.target.title ?? "no panel")
        _ = key(53, "\u{1b}")
        check("Esc on a selection panel hides the launcher", !launcher.isVisible)
        pick(.text("hello world", source: "TextEdit"))
        HotkeyCenter.shared.onSelection()
        try? await Task.sleep(for: .milliseconds(200))
        let textRows = lm.actions?.rows.map(\.title) ?? []
        check("selected text gives text actions", textRows.starts(with: ["Show in Large Type", "Copy as Plain Text"])
              && textRows.contains("Search Google for “hello world”") && lm.actions?.detail == "Selected text in TextEdit",
              textRows.joined(separator: ", "))
        lm.actions?.filter = "plain"
        _ = key(36, "\r")
        check("Copy as Plain Text runs on the text", performed.last == .text(.copyPlainText, "hello world") && !launcher.isVisible)
        HotkeyCenter.shared.onSelection()
        try? await Task.sleep(for: .milliseconds(200))
        lm.actions?.filter = "google"
        _ = key(36, "\r")
        check("a web search opens the search URL", opened.last?.absoluteString.hasSuffix("q=hello%20world") == true)
        pick(.nothing)
        HotkeyCenter.shared.onSelection()
        try? await Task.sleep(for: .milliseconds(200))
        check("nothing selected says what to do", lm.actions == nil && lm.results.first?.title == LauncherModel.nothingSelected)
        pick(.noAccess)
        HotkeyCenter.shared.onSelection()
        try? await Task.sleep(for: .milliseconds(200))
        check("without Accessibility it offers System Settings", lm.results.first?.title == LauncherModel.allowAccess
              && lm.results.first?.url?.scheme == "x-apple.systempreferences")
        launcher.hide()
        // Large Type, the real window: Esc closes it.
        LargeType.shared.show("Large")
        try? await Task.sleep(for: .milliseconds(200))
        check("Large Type shows the text", LargeType.shared.isVisible && LargeType.shared.text == "Large")
        LargeType.shared.hide()
        check("and closes", !LargeType.shared.isVisible)
        pick(.nothing)

        // The whole path through NSApp, like the keyboard: focus must reach
        // the filter field, so typed letters filter and ↩ runs the match.
        var ranWith: [ActionPanel.Item] = []
        lm.perform = { item, _ in ranWith.append(item); return true }
        launcher.show()
        lm.query = root + "notes"
        try? await Task.sleep(for: .milliseconds(300))
        func send(_ code: UInt16, _ chars: String) async {
            if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags(code, command: false),
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: launcher.panel.windowNumber, context: nil,
                characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code) {
                NSApp.sendEvent(event)
            }
            try? await Task.sleep(for: .milliseconds(150))
        }
        await send(124, "\u{F703}")
        for (code, char) in [(17, "t"), (15, "r"), (0, "a"), (1, "s"), (4, "h")] { await send(UInt16(code), char) }
        check("typed letters reach the filter field", lm.actions?.filter == "trash", lm.actions?.filter ?? "no panel")
        await send(36, "\r")
        check("↩ runs the action you typed", ranWith.last == .action(.trash), "\(ranWith)")
        launcher.show()
        lm.query = root + "notes"
        try? await Task.sleep(for: .milliseconds(300))
        await send(124, "\u{F703}")
        await send(53, "\u{1b}")
        await send(1, "s")
        check("after Esc typing goes to the search field again", lm.actions == nil && lm.query == root + "notess", lm.query)
        lm.perform = { _, _ in true }
        launcher.hide()

        try? fm.removeItem(atPath: root)
        launcher.show()
        lm.query = "zzqxv nothing"

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

    /// S-012: a tap on ⇧ or ⌘Y opens Quick Look on the selected file; a second
    /// tap or Esc closes it. Real key and modifier events, a real Quick Look panel.
    private static func checkQuickLook(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let quickLook = QuickLook.shared
        let settings = PreviewSettings.shared
        let fm = FileManager.default
        let root = NSTemporaryDirectory() + "reach-quicklook/"
        try? fm.removeItem(atPath: root)
        try? fm.createDirectory(atPath: root, withIntermediateDirectories: true)
        fm.createFile(atPath: root + "notes.txt", contents: Data("Quick Look".utf8))
        var clock = ProcessInfo.processInfo.systemUptime
        func event(_ type: NSEvent.EventType, _ code: UInt16, _ flags: NSEvent.ModifierFlags, _ chars: String = "") -> NSEvent? {
            clock += 0.08
            return NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: clock,
                                    windowNumber: launcher.panel.windowNumber, context: nil, characters: chars,
                                    charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)
        }
        func send(_ e: NSEvent?) { if let e { _ = launcher.handle(e) } }
        func state() -> String {
            "launcher \(launcher.isVisible ? "shown" : "hidden"), key \(NSApp.keyWindow.map { String(describing: type(of: $0)) } ?? "none"), "
                + "Quick Look \(quickLook.isOpen ? "open" : "closed"), app \(NSApp.isActive ? "active" : "inactive")"
        }
        func tapShift() async {
            clock += 1  // well after any typing
            send(event(.flagsChanged, 56, .shift))
            send(event(.flagsChanged, 56, []))
            try? await Task.sleep(for: .milliseconds(400))
        }

        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(400))
        check("the test file is selected", lm.selectedResult?.title == "notes.txt", lm.selectedResult?.title ?? "none")
        await tapShift()
        check("a tap on ⇧ opens Quick Look on the selected file",
              quickLook.isOpen && quickLook.url?.lastPathComponent == "notes.txt")
        check("the launcher stays open and keeps the keyboard", launcher.isVisible && launcher.panel.isKeyWindow, state())
        await tapShift()
        check("a second tap closes it", !quickLook.isOpen, state())
        await tapShift()
        send(event(.keyDown, 53, [], "\u{1b}"))
        try? await Task.sleep(for: .milliseconds(500))
        check("Esc closes only Quick Look", !quickLook.isOpen && launcher.isVisible && lm.query == root, state())
        clock += 1
        send(event(.flagsChanged, 56, .shift))
        send(event(.keyDown, 0, .shift, "A"))
        send(event(.flagsChanged, 56, []))
        try? await Task.sleep(for: .milliseconds(300))
        check("⇧ held for a capital opens nothing", !quickLook.isOpen)
        lm.query = root
        try? await Task.sleep(for: .milliseconds(300))
        send(event(.keyDown, 16, .command, "y"))
        try? await Task.sleep(for: .milliseconds(400))
        check("⌘Y opens Quick Look", quickLook.isOpen)
        send(event(.keyDown, 16, .command, "y"))
        try? await Task.sleep(for: .milliseconds(500))
        check("and closes it", !quickLook.isOpen, state())
        settings.skips.types = ["public.text"]
        await tapShift()
        check("a skipped file type gets no Quick Look", !quickLook.isOpen)
        settings.skips = PreviewSkips(folders: [URL(fileURLWithPath: root).resolvingSymlinksInPath().path])
        await tapShift()
        check("nor does a file in a skipped folder", !quickLook.isOpen)
        settings.skips = PreviewSkips()
        settings.quickLook = false
        await tapShift()
        check("nor anything with Quick Look off in Settings", !quickLook.isOpen)
        settings.quickLook = true
        await tapShift()
        launcher.hide()
        try? await Task.sleep(for: .milliseconds(500))
        check("hiding the launcher closes Quick Look", !quickLook.isOpen, state())
        // Hidden while Quick Look is still opening, as after a tap on ⇧ and a click elsewhere.
        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(400))
        clock += 1
        send(event(.flagsChanged, 56, .shift))
        send(event(.flagsChanged, 56, []))
        launcher.hide()
        try? await Task.sleep(for: .milliseconds(1000))
        check("hiding it mid-animation closes Quick Look too", !quickLook.isOpen, state())

        // As in real use: another app in front, and ⇧ tapped on the real keyboard,
        // so the event takes the system's path through the key monitor.
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            finder.activate()
            try? await Task.sleep(for: .milliseconds(500))
        }
        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(500))
        func realShift() async {
            let source = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 56, keyDown: true)
            down?.flags = .maskShift
            down?.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(60))
            let up = CGEvent(keyboardEventSource: source, virtualKey: 56, keyDown: false)
            up?.flags = []
            up?.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(700))
        }
        await realShift()
        check("with another app in front, a real ⇧ tap opens Quick Look and the launcher stays", quickLook.isOpen && launcher.isVisible, state())
        await realShift()
        check("and a second real tap closes it", !quickLook.isOpen, state())
        launcher.hide()

        // In the action panel: ⇧, ⌘Y and the Quick Look row preview the panel's file.
        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(400))
        _ = lm.showActions()
        let row = lm.actions?.items.firstIndex(of: .action(.quickLook))
        check("the action panel lists Quick Look", row == 1, "\(lm.actions?.items ?? [])")
        await tapShift()
        check("a tap on ⇧ in the action panel opens Quick Look on its file",
              quickLook.isOpen && quickLook.url?.lastPathComponent == "notes.txt" && lm.actions != nil && launcher.isVisible, state())
        send(event(.keyDown, 53, [], "\u{1b}"))
        try? await Task.sleep(for: .milliseconds(500))
        check("Esc closes Quick Look first, the action panel stays", !quickLook.isOpen && lm.actions != nil, state())
        send(event(.keyDown, 16, .command, "y"))
        try? await Task.sleep(for: .milliseconds(400))
        check("⌘Y in the action panel opens Quick Look", quickLook.isOpen, state())
        send(event(.keyDown, 16, .command, "y"))
        try? await Task.sleep(for: .milliseconds(500))
        check("and closes it", !quickLook.isOpen, state())
        if let row { lm.runAction(at: row) }
        try? await Task.sleep(for: .milliseconds(400))
        check("↩ on Quick Look opens it, and the launcher stays", quickLook.isOpen && launcher.isVisible && lm.actions != nil, state())
        quickLook.close()
        lm.closeActions()
        settings.skips.types = ["public.text"]
        _ = lm.showActions()
        check("a skipped file type gets no Quick Look row", lm.actions?.items.contains(.action(.quickLook)) == false)
        settings.skips = PreviewSkips()
        lm.closeActions()
        lm.query = "zzqxv nothing"
        try? await Task.sleep(for: .milliseconds(300))
        launcher.hide()
        check("test runs leave the saved preview settings alone",
              UserDefaults.standard.object(forKey: "previews.skipTypes") as? [String] != ["public.text"])
        try? fm.removeItem(atPath: root)
    }

    /// S-013: ⌥↑ collects items in the buffer, ⌥→ runs one action on all of them.
    private static func checkBuffer(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let fm = FileManager.default
        let root = NSTemporaryDirectory() + "reach-buffer/"
        try? fm.removeItem(atPath: root)
        try? fm.createDirectory(atPath: root, withIntermediateDirectories: true)
        let names = ["a.txt", "b.txt", "c.txt"]
        for name in names { fm.createFile(atPath: root + name, contents: Data(name.utf8)) }
        func titles(_ urls: [URL]) -> [String] { urls.map(\.lastPathComponent) }
        var ran: [(ActionPanel.Item, [URL])] = []
        lm.perform = { item, urls in ran.append((item, urls)); return true }
        var clock = ProcessInfo.processInfo.systemUptime
        lm.now = { clock }
        // ⌥ with an arrow, as the real keyboard sends it.
        func option(_ code: UInt16, _ chars: String) -> Bool {
            var flags: NSEvent.ModifierFlags = .option
            if (123...126).contains(code) { flags.formUnion([.numericPad, .function]) }
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: launcher.panel.windowNumber,
                    context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false,
                    keyCode: code) else { return false }
            return launcher.handle(event)
        }
        let up = "\u{F700}", down = "\u{F701}", left = "\u{F702}", right = "\u{F703}"

        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(400))
        check("with an empty buffer ⌥← and ⌥⌫ stay with the text field", !option(123, left) && !option(51, "\u{7f}"))
        _ = option(126, up)
        check("⌥↑ puts the selected item in the buffer", titles(lm.buffer.items) == ["a.txt"], "\(titles(lm.buffer.items))")
        _ = option(126, up)
        check("⌥↑ again takes it out", lm.buffer.isEmpty)
        _ = option(125, down)
        _ = option(125, down)
        check("⌥↓ adds and moves to the next result", titles(lm.buffer.items) == ["a.txt", "b.txt"]
              && lm.selectedResult?.title == "c.txt", "\(titles(lm.buffer.items)), selected \(lm.selectedResult?.title ?? "none")")
        _ = option(126, up)
        check("⌥← takes out the last item", option(123, left) && titles(lm.buffer.items) == ["a.txt", "b.txt"])
        launcher.hide()
        launcher.show()
        check("hiding the launcher keeps the buffer", lm.buffer.items.count == 2)
        lm.query = "zzqxv nothing"
        try? await Task.sleep(for: .milliseconds(300))
        check("⌥↑ on a web search adds nothing", option(126, up) && lm.buffer.items.count == 2)
        check("⌥→ opens the action panel for every item", option(124, right) && lm.actions?.isMany == true
              && lm.actions?.target.title == "2 Items", lm.actions?.target.title ?? "no panel")
        let items = lm.actions?.items ?? []
        check("several items skip Browse, Terminal and Quick Look",
              !items.contains(.action(.browse)) && !items.contains(.action(.terminal)) && !items.contains(.action(.quickLook)))
        lm.cancelActions()
        check("Esc goes back to the results with the buffer kept", lm.actions == nil && lm.buffer.items.count == 2)
        _ = option(124, right)
        if let copy = lm.actions?.items.firstIndex(of: .action(.copyPath)) { lm.runAction(at: copy) }
        check("the action runs on every item", ran.last.map { titles($0.1) } == ["a.txt", "b.txt"], "\(ran.last.map { titles($0.1) } ?? [])")
        check("and then the buffer is empty", lm.buffer.isEmpty)

        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(400))
        _ = option(125, down)
        check("⌥⌫ empties the buffer", option(51, "\u{7f}") && lm.buffer.isEmpty)
        _ = option(126, up)
        launcher.hide()
        clock += FileBuffer.idle + 1
        launcher.show()
        check("5 minutes unused empties the buffer", lm.buffer.isEmpty)
        launcher.hide()

        lm.perform = { _, _ in true }
        lm.now = { ProcessInfo.processInfo.systemUptime }
        try? fm.removeItem(atPath: root)
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

/// A source with fixed titles and optional delay, so launcher checks do not
/// depend on the apps on this Mac and slow sources can be tested.
private final class FakeSource: ResultSource {
    private let titles: [String]
    private let delay: Duration?

    init(_ titles: [String], delay: Duration? = nil) {
        self.titles = titles
        self.delay = delay
    }

    static func url(_ title: String) -> URL {
        URL(string: "reach-test://app/\(title.replacingOccurrences(of: " ", with: "-"))")!
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        let found = titles.compactMap { title in
            Matcher.score(query: text, title: title).map {
                Scored(result: LaunchResult(id: "fake:\(title)", title: title, subtitle: "Test app",
                                            icon: .symbol("app"), url: Self.url(title)), score: $0)
            }
        }
        guard let delay else { return found }
        Task {
            try? await Task.sleep(for: delay)
            later(found)
        }
        return nil
    }
}
