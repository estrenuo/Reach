import AppKit
import IOKit.pwr_mgt
import Quartz
import SwiftData
import ReachKit

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/Reach-self.store ~/Applications/Reach.app/Contents/MacOS/Reach --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic, in the
/// section file for its milestone (SelfTest+Launcher, +QuickLook, +Buffer, +Search).
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0
    /// Keeps the display awake: with it asleep no window can take the keyboard.
    private static var awake: NSObjectProtocol?

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        // A sleeping display or a locked screen fails every focus check (FIXLOG).
        awake = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated],
                                                      reason: "Reach self-test needs a window with the keyboard")
        var blockers: Set<String> = []
        if screenIsLocked { blockers.insert("the screen was locked") }
        if CGDisplayIsAsleep(CGMainDisplayID()) != 0 {
            // Wakes the display, as a key press would; it cannot unlock the screen.
            var id = IOPMAssertionID(0)
            _ = IOPMAssertionDeclareUserActivity("Reach self-test" as CFString, kIOPMUserActiveLocal, &id)
        }
        let center = NSWorkspace.shared.notificationCenter
        let sleeps = [(NSWorkspace.screensDidSleepNotification, "the display slept"),
                      (NSWorkspace.sessionDidResignActiveNotification, "the screen was locked")].map { name, reason in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { _ = blockers.insert(reason) }
            }
        }
        // APP_SELFTEST_ONLY=workflows,launcher runs only those groups (tools/selftest.sh workflows).
        let only = groupsAsked()
        if let only, let unknown = only.first(where: { name in !groups.contains { $0.name == name } }) {
            print("SELFTEST refused: no group “\(unknown)”. Groups: \(groups.map(\.name).joined(separator: ", "))")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            // The launcher hides when another app takes the keyboard, as it should.
            // Name those apps, so a failure caused by someone typing is easy to tell apart.
            var intruders: Set<String> = []
            let watch = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                // Finder: the Quick Look check brings it to the front on purpose.
                if let app, app != .current, app.bundleIdentifier != "com.apple.finder" { MainActor.assumeIsolated { _ = intruders.insert(app.localizedName ?? "?") } }
            }
            for group in groups where only?.contains(group.name) ?? true {
                await group.run(model)
            }
            NSWorkspace.shared.notificationCenter.removeObserver(watch)
            sleeps.forEach(center.removeObserver)
            if screenIsLocked { blockers.insert("the screen was locked") }
            if failures > 0, !blockers.isEmpty {
                print("NOTE \(blockers.sorted().joined(separator: " and ").capitalizedFirst) during the run. "
                      + "Focus checks fail then; run again with the Mac unlocked.")
            }
            if failures > 0, !intruders.isEmpty {
                print("NOTE \(intruders.sorted().joined(separator: ", ")) came to the front during the run. "
                      + "Focus checks fail then; run again without using the Mac.")
            }

            let ran = only.map { $0.joined(separator: ", ") } ?? "all groups"
            print(failures == 0 ? "SELFTEST PASS \(count) checks (\(ran))" : "SELFTEST FAIL \(failures) of \(count) checks (\(ran))")
            finish(code: failures == 0 ? 0 : 1)
        }
    }


    /// The check groups in run order, by the short name APP_SELFTEST_ONLY takes.
    static let groups: [(name: String, run: @MainActor (AppModel) async -> Void)] = [
        ("basics", { checkBasics(model: $0) }),
        ("launcher", { await checkLauncher(model: $0) }),
        ("quicklook", { await checkQuickLook(model: $0) }),
        ("buffer", { await checkBuffer(model: $0) }),
        ("search", { await checkSearch(model: $0) }),
        ("calculator", { await checkCalculator(model: $0) }),
        ("websearch", { await checkWebSearch(model: $0) }),
        ("urls", { await checkURLs(model: $0) }),
        ("fallbacks", { await checkFallbacks(model: $0) }),
        ("system", { await checkSystem(model: $0) }),
        ("apps", { await checkApps(model: $0) }),
        ("shell", { await checkShell(model: $0) }),
        ("dictionary", { await checkDictionary(model: $0) }),
        ("largetype", { await checkLargeType(model: $0) }),
        ("contacts", { await checkContacts(model: $0) }),
        ("clipboard", { await checkClipboard(model: $0) }),
        ("clipboardviewer", { await checkClipboardViewer(model: $0) }),
        ("merging", { await checkMerging(model: $0) }),
        ("snippets", { await checkSnippets(model: $0) }),
        ("snippetpaste", { await checkSnippetPaste(model: $0) }),
        ("clipboardloan", { await checkClipboardLoan(model: $0) }),
        ("expansion", { await checkExpansion(model: $0) }),
        ("themes", { await checkThemes(model: $0) }),
        ("ownthemes", { await checkOwnThemes(model: $0) }),
        ("launcheroptions", { await checkLauncherOptions(model: $0) }),
        ("menubaricon", { await checkMenuBarIcon(model: $0) }),
        ("settings", { await checkSettingsWindow(model: $0) }),
        ("advanced", { await checkAdvanced(model: $0) }),
        ("sync", { checkSync(model: $0) }),
        ("usage", { checkUsage(model: $0) }),
        ("workflows", { await checkWorkflows(model: $0) }),
        ("workflowlist", { await checkWorkflowList(model: $0) }),
    ]

    /// The group names in APP_SELFTEST_ONLY, lowercased; nil runs every group.
    private static func groupsAsked() -> [String]? {
        let names = (ProcessInfo.processInfo.environment["APP_SELFTEST_ONLY"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        return names.isEmpty ? nil : names
    }

    /// New Snippet and snippet names: the first checks, from before the groups had files.
    private static func checkBasics(model: AppModel) {
        let context = model.container.mainContext
        func snippets() -> [Snippet] { (try? context.fetch(FetchDescriptor<Snippet>())) ?? [] }

        let before = snippets().count
        model.addSnippet()
        check("New Snippet adds one snippet", snippets().count == before + 1)
        check("the new snippet is selected", model.selection != nil)

        if let snippet = snippets().first(where: { $0.id == model.selection }) {
            check("a new snippet always has a collection", snippet.collection != nil)
            context.delete(snippet)
            try? context.save()
            check("deleting the snippet removes it", snippets().count == before)
        }
        check("names are cleaned", SnippetName.clean("  Email   signature ") == "Email signature")
    }

    /// Shows the launcher again after a check hid it. Hide, show and a query in
    /// one run loop turn trip an AppKit assertion in the field editor (FIXLOG),
    /// so this waits for the hide to settle and for the show to lay out.
    static func showAgain(_ launcher: LauncherController) async {
        try? await Task.sleep(for: .milliseconds(150))
        launcher.show()
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// True while the login window covers the screen.
    private static var screenIsLocked: Bool {
        (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool == true
    }

    static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
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

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// A value the self-test changes after handing a closure that reads it to
/// the code under test. The self-test runs on the main actor only.
final class Shared<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}
