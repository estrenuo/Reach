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
        Task {
            try? await Task.sleep(for: .seconds(0.5))
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

            // The launcher hides when another app takes the keyboard, as it should.
            // Name those apps, so a failure caused by someone typing is easy to tell apart.
            var intruders: Set<String> = []
            let watch = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                // Finder: the Quick Look check brings it to the front on purpose.
                if let app, app != .current, app.bundleIdentifier != "com.apple.finder" { MainActor.assumeIsolated { _ = intruders.insert(app.localizedName ?? "?") } }
            }
            await checkLauncher(model: model)
            await checkQuickLook(model: model)
            await checkBuffer(model: model)
            await checkSearch(model: model)
            await checkCalculator(model: model)
            await checkWebSearch(model: model)
            await checkURLs(model: model)
            await checkFallbacks(model: model)
            await checkSystem(model: model)
            await checkApps(model: model)
            await checkShell(model: model)
            await checkDictionary(model: model)
            await checkLargeType(model: model)
            await checkContacts(model: model)
            await checkClipboard(model: model)
            await checkClipboardViewer(model: model)
            await checkMerging(model: model)
            await checkSnippets(model: model)
            await checkSnippetPaste(model: model)
            await checkClipboardLoan(model: model)
            await checkExpansion(model: model)
            await checkThemes(model: model)
            await checkOwnThemes(model: model)
            await checkLauncherOptions(model: model)
            await checkMenuBarIcon(model: model)
            await checkSettingsWindow(model: model)
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

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
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
