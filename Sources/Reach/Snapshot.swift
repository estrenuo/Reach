import AppKit
import IOKit.pwr_mgt
import ReachKit
import SwiftUI

/// Screenshot mode for agents.
///   APP_STORE=/tmp/test.store APP_SNAPSHOT=/tmp/shots ~/Applications/Reach.app/Contents/MacOS/Reach
/// writes <page>-light.png and <page>-dark.png for every sidebar page, and
/// settings-<tab>-light.png and settings-<tab>-dark.png for every Settings tab, then quits.
/// Each PNG gets a <page>-<mode>-layout.json with the grid probes (tools/check-layout.swift).
/// APP_SNAPSHOT_PAGES=all,starred limits the pages. Add "settings" or "launcher" to include those.
/// Add APP_ACCENT=<id> to see the pages in another accent.
enum Snapshot {
    static func runIfRequested(model: AppModel, openSettings: OpenSettingsAction) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"], !dir.isEmpty else { return }
        // Print each line at once, so AppKit's warnings on stderr land between
        // the captures they belong to.
        setvbuf(stdout, nil, _IOLBF, 0)
        // Snapshots never run against the real database.
        guard Store.isOverridden else {
            print("SNAPSHOT refused: set APP_STORE to a file in /tmp")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        Task {
            // A sleeping display gives screencapture nothing. Declaring user
            // activity wakes it; the assertion keeps it on until the run quits.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1.5))
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                for page in SidebarItem.allCases where only?.contains(page.rawValue) ?? true {
                    model.sidebar = page
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/\(page.rawValue)-\(mode).png")
                }
            }
            // Sample URLs for the URL history; the snapshot store is in /tmp.
            for url in ["https://developer.apple.com/documentation/swiftui", "https://en.wikipedia.org/wiki/Bowler_hat",
                        "https://www.example.com/"] {
                if let url = URL(string: url) { model.launcherModel.history.record(url) }
            }
            if only == nil || only?.contains("launcher") == true, let launcher = model.launcher {
                await model.launcherModel.apps.refreshNow()
                // Sample files instead of the person's own: snapshots get shared.
                let samples = SampleFiles.make()
                let sources = model.launcherModel.sources
                model.launcherModel.sources = [model.launcherModel.calculator, model.launcherModel.shell, model.launcherModel.dictionary, model.launcherModel.contacts, model.launcherModel.apps, model.launcherModel.system, model.launcherModel.webSearches, model.launcherModel.typedURLs, model.launcherModel.history, samples, model.launcherModel.paths]
                defer { model.launcherModel.sources = sources }
                // Sample apps for `quit`, not the ones running on this Mac.
                model.launcherModel.system.running = { ["Mail", "Safari", "Music", "Notes"].map {
                    let path = ["/System/Applications/\($0).app", "/Applications/\($0).app"].first(where: FileManager.default.fileExists) ?? ""
                    return RunningApp(name: $0, pid: 0, path: path)
                } }
                // Sample definitions and spellings, the same on every Mac.
                let dictionary = model.launcherModel.dictionary
                dictionary.define = { ["serendipity": "serendipity | ˌserənˈdɪpɪti | noun the occurrence and development of events by chance in a happy or beneficial way ▸ a fortunate stroke of serendipity",
                                       "serendipitous": "serendipitous | ˌserənˈdɪpɪtəs | adjective occurring or discovered by chance in a happy or beneficial way"][$0] }
                dictionary.completions = { word, _ in word.hasPrefix("serendip") ? ["serendipitous"] : [] }
                dictionary.guesses = { word, _ in word == "recieve" ? ["receive", "relieve", "recife"] : [word] }
                // Sample contacts, never the person's own address book.
                model.launcherModel.contacts.use(SelfTest.sampleContacts)
                let states = [("empty", ""), ("results", "co"), ("files", "open brief"), ("fallbacks", "zzqxv nothing"), ("calculator", "=2*21+sqrt(16)"), ("web", "wiki alfred"), ("url", "example.org/docs"), ("history", "bowler"), ("system", "sleep"), ("confirm", "restart"), ("quit", "quit"), ("shell", "> ls -la"), ("define", "define serendipity"), ("spell", "spell recieve"), ("contacts", "sand"), ("contact-card", "sander"), ("email", "email sander"), ("path", SampleFiles.folder), ("actions", "safari"), ("selection", ""), ("buffer", "co"), ("buffer-actions", "co"), ("clipboard-empty", ""), ("clipboard", "")]
                // S-026: sample clips, never what this Mac copied.
                let context = model.container.mainContext
                let clips = ClipboardHistory(pasteboard: .withUniqueName(), context: context)
                let sampleClips = [("Meeting notes\nShip the clipboard viewer on Friday.\nAsk Ada about the snippets.", "Notes", 3),
                               ("https://example.com/docs/clipboard", "Safari", 25),
                               ("/Applications/Safari.app\n/Applications/Mail.app", "Finder", 90),
                               ("let viewer = ClipboardViewer(history: clips)", "Xcode", 300)]
                    .map { text, app, minutes in
                        let item = ClipboardItem(kind: text.hasPrefix("/") ? .files : .text, text: text, sourceApp: app)
                        item.copiedAt = Date.now.addingTimeInterval(TimeInterval(-minutes * 60))
                        context.insert(item)
                        return item
                    }
                defer {
                    sampleClips.forEach(context.delete)
                    try? context.save()
                    ClipboardSettings.shared.reset()
                }
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for (name, query) in states {
                        launcher.show()
                        model.launcherModel.query = query
                        try? await Task.sleep(for: .seconds(1))
                        if name == "selection" {
                            model.launcherModel.showActions(for: .text("""
                                The quick brown fox jumps over the lazy dog.
                                Pack my box with five dozen liquor jugs.
                                """, source: "TextEdit"))
                            try? await Task.sleep(for: .seconds(0.5))
                        }
                        if name == "confirm" { model.launcherModel.openSelected() }
                        if name == "actions" || name == "contact-card" {
                            _ = model.launcherModel.showActions()
                            try? await Task.sleep(for: .seconds(0.5))
                        }
                        if name.hasPrefix("clipboard") {
                            ClipboardSettings.shared.keep[.text] = true
                            model.launcherModel.clipboard = name == "clipboard" ? clips : nil
                            model.launcherModel.showClipboard()
                            try? await Task.sleep(for: .seconds(0.5))
                        }
                        if name.hasPrefix("buffer") {
                            let lm = model.launcherModel
                            for index in 0..<min(3, lm.results.count) {
                                lm.select(index)
                                _ = lm.toggleBuffer()
                            }
                            lm.select(0)
                            if name == "buffer-actions" { _ = lm.showBufferActions() }
                            try? await Task.sleep(for: .seconds(0.5))
                        }
                        capture(to: "\(dir)/launcher-\(name)-\(mode).png", window: launcher.panel)
                        _ = model.launcherModel.clearBuffer()
                        launcher.hide()
                    }
                    // S-023: the Large Type card, from ⌘L on a calculation.
                    LargeType.shared.show("Hallo Sander")
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/large-type-\(mode).png", window: LargeType.shared.window)
                    LargeType.shared.hide()
                }
            }
            if only == nil || only?.contains("settings") == true {
                let main = NSApp.windows.first { $0.canBecomeMain && !$0.isSheet }
                openSettings()
                try? await Task.sleep(for: .seconds(1))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for tab in SettingsTab.allCases {
                        model.settingsTab = tab
                        try? await Task.sleep(for: .seconds(0.8))
                        // Only titled windows: the menu bar icon and the launcher have windows too.
                        let settings = NSApp.windows.first { $0.isVisible && $0 !== main && !$0.isSheet && $0.styleMask.contains(.titled) }
                        capture(to: "\(dir)/settings-\(tab.rawValue)-\(mode).png", window: settings)
                        if tab == .search {
                            // The Fallbacks section sits below the fold.
                            if let scroll = settings?.contentView?.firstDescendant(of: NSScrollView.self),
                               let document = scroll.documentView {
                                document.scroll(NSPoint(x: 0, y: document.isFlipped ? document.bounds.maxY : 0))
                                try? await Task.sleep(for: .seconds(0.5))
                                capture(to: "\(dir)/settings-search-end-\(mode).png", window: settings)
                                document.scroll(NSPoint(x: 0, y: document.isFlipped ? 0 : document.bounds.maxY))
                            }
                            WebSearchSettings.shared.editingFallbacks = true
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-fallbacks-\(mode).png", window: settings?.attachedSheet)
                            WebSearchSettings.shared.editingFallbacks = false
                            try? await Task.sleep(for: .seconds(0.5))
                        }
                        if tab == .web {
                            WebSearchSettings.shared.page = .urls
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-web-urls-\(mode).png", window: settings)
                            WebSearchSettings.shared.page = .searches
                        }
                    }
                }
            }
            print("SNAPSHOT done \(dir)")
            // An open sheet refuses terminate, and the run would wait forever.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    /// Captures the real window with screencapture, so glass, sidebars, and
    /// materials look exactly as on screen. That needs Screen Recording
    /// permission for the app that started this one (your terminal, or Claude).
    /// Without it, falls back to drawing the view hierarchy, which leaves
    /// sidebars and glass blank.
    private static func capture(to path: String, window: NSWindow? = nil) {
        // Another app can hide this one while snapshots run (computer use hides
        // apps it does not control). Hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window = window ?? NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) else {
            print("SNAPSHOT no window")
            return
        }
        // Active, like a window someone is using: real accent colors and focus rings.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        let size = window.contentView?.bounds.size ?? .zero
        GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: size)
        try? FileManager.default.removeItem(atPath: path)
        // The first capture of a run sometimes misses the window. Try three times.
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            // A locked screen gives a tiny blank image instead of the window.
            if let rep = NSImageRep(contentsOfFile: path), CGFloat(rep.pixelsWide) >= window.frame.width {
                print("SNAPSHOT \(path)")
                return
            }
            try? FileManager.default.removeItem(atPath: path)
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback: no Screen Recording permission or a locked screen, sidebars and glass are blank)")
        }
    }
}

/// Made-up files in /tmp for the launcher snapshots, so no real file name from
/// the home folder ends up in a screenshot. Answers file search by name, as
/// Spotlight would; the same folder is browsed for the path snapshot.
final class SampleFiles: ResultSource {
    static let folder = "/tmp/Reach-sample/"
    static let names = ["Project brief.md", "Brief to the board.docx", "Briefing notes.txt", "Q3 report.pdf",
                        "Holiday photo.jpg", "Budget 2027.numbers", "Invoices", "Briefs"]

    /// Creates the folder with empty files (and two folders), and the source that finds them.
    static func make() -> SampleFiles {
        let files = FileManager.default
        try? files.removeItem(atPath: folder)
        for name in names {
            let path = folder + name
            if name.contains(".") {
                try? files.createDirectory(atPath: folder, withIntermediateDirectories: true)
                files.createFile(atPath: path, contents: Data())
            } else {
                try? files.createDirectory(atPath: path, withIntermediateDirectories: true)
            }
        }
        return SampleFiles()
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .files(let search) = query, !search.text.isEmpty else { return [] }
        return Self.names.compactMap { name in
            guard Matcher.score(query: search.text, title: name) != nil else { return nil }
            let path = Self.folder + name
            return Scored(result: LaunchResult(id: path, title: name, subtitle: "~/Documents/" + name,
                                               icon: .file(path), url: URL(fileURLWithPath: path),
                                               isFolder: !name.contains(".")), score: 0)
        }
    }
}


private extension NSView {
    func firstDescendant<T: NSView>(of type: T.Type) -> T? {
        for view in subviews {
            if let match = view as? T ?? view.firstDescendant(of: type) { return match }
        }
        return nil
    }
}
