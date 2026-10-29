import AppKit
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
            await checkSearch(model: model)
            await checkCalculator(model: model)
            await checkWebSearch(model: model)
            await checkURLs(model: model)
            NSWorkspace.shared.notificationCenter.removeObserver(watch)
            if failures > 0, !intruders.isEmpty {
                print("NOTE \(intruders.sorted().joined(separator: ", ")) came to the front during the run. "
                      + "Focus checks fail then; run again without using the Mac.")
            }

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
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
