import AppKit
import IOKit.pwr_mgt
import ReachKit
import SwiftData
import SwiftUI

/// Screenshot mode for agents.
///   APP_STORE=/tmp/test.store APP_SNAPSHOT=/tmp/shots ~/Applications/Reach.app/Contents/MacOS/Reach
/// writes <page>-light.png and <page>-dark.png for every sidebar page, and
/// settings-<tab>-light.png and settings-<tab>-dark.png for every Settings tab, then quits.
/// Each PNG gets a <page>-<mode>-layout.json with the grid probes (tools/check-layout.swift).
/// APP_SNAPSHOT_PAGES=snippets,collection,snippets-empty limits the pages. Add "settings" or "launcher" to include those.
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
                // S-029: All Snippets, a collection with a snippet selected, and an empty collection.
                let collections = (try? model.container.mainContext.fetch(FetchDescriptor<SnippetCollection>())) ?? []
                let work = collections.first { $0.name == "Work" }
                let pages: [(String, SnippetPage, Snippet?)] = [
                    ("snippets", .all, nil),
                    ("collection", work.map { .collection($0.id) } ?? .all,
                     work?.snippets?.first { $0.name == "Email signature" }),
                    ("snippets-empty", collections.first { $0.name == "Templates" }.map { .collection($0.id) } ?? .all, nil),
                ]
                for (name, page, snippet) in pages where only?.contains(name) ?? true {
                    model.page = page
                    model.selection = snippet?.id
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/\(name)-\(mode).png")
                }
                model.page = .all
                model.selection = nil
            }
            // Sample URLs for the URL history; the snapshot store is in /tmp.
            for url in ["https://developer.apple.com/documentation/swiftui", "https://en.wikipedia.org/wiki/Bowler_hat",
                        "https://www.example.com/"] {
                if let url = URL(string: url) { model.launcherModel.history.record(url) }
            }
            // S-057: fixture bookmark files in /tmp, never the person's own.
            let bookmarkFiles = SelfTest.writeBookmarkFixtures(in: URL(fileURLWithPath: "/tmp/Reach-bookmarks-snap", isDirectory: true))
            model.launcherModel.bookmarks.files = bookmarkFiles
            if only == nil || only?.contains("launcher") == true, model.launcher != nil {
                await model.launcherModel.apps.refreshNow()
                // Sample files instead of the person's own: snapshots get shared.
                let samples = SampleFiles.make()
                let sources = model.launcherModel.sources
                // Only file search is swapped; every other source is the app's own, so snapshots show what the app shows.
                model.launcherModel.sources = sources.map { $0 === model.launcherModel.files ? samples : $0 }
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
                await withSampleClips(model: model) { clips in
                    await captureLauncher(launcherShots(model: model, clips: clips), model: model, dir: dir)
                }
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    // S-023: the Large Type card, from ⌘L on a calculation.
                    LargeType.shared.show("Hallo Sander")
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/large-type-\(mode).png", window: LargeType.shared.window)
                    LargeType.shared.hide()
                }
            }
            if only == nil || only?.contains("workflows") == true {
                await captureWorkflows(model: model, dir: dir)
            }
            if only == nil || only?.contains("music") == true {
                await captureMusic(model: model, dir: dir)
                await captureMiniPlayer(model: model, dir: dir)
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
                        if tab == .contacts {
                            // S-058: the Custom Actions table and its add sheet; the plain page shows it empty.
                            ContactsSettings.shared.actions = SelfTest.sampleContactActions
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-contacts-actions-\(mode).png", window: settings)
                            ContactsSettings.shared.editingAction = ContactAction(kind: .phone, title: "", url: "")
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-contact-action-sheet-\(mode).png", window: settings?.attachedSheet)
                            ContactsSettings.shared.editingAction = nil
                            ContactsSettings.shared.actions = []
                            try? await Task.sleep(for: .seconds(0.5))
                        }
                        if tab == .search {
                            // The Fallbacks section sits below the fold. The page's scroll view is wider than the sidebar's.
                            if let scroll = settings?.contentView?.descendants(of: NSScrollView.self).max(by: { $0.frame.width < $1.frame.width }),
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
                        if tab == .music {
                            MusicSettings.shared.page = .keywords
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-music-keywords-\(mode).png", window: settings)
                            MusicSettings.shared.page = .general
                        }
                        if tab == .clipboard {
                            ClipboardSettings.shared.page = .merging
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-clipboard-merging-off-\(mode).png", window: settings)
                            ClipboardSettings.shared.keep[.text] = true
                            ClipboardSettings.shared.appendsOnDoubleCopy = true
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-clipboard-merging-\(mode).png", window: settings)
                            ClipboardSettings.shared.reset()
                            ClipboardSettings.shared.page = .advanced
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-clipboard-advanced-\(mode).png", window: settings)
                            ClipboardSettings.shared.page = .history
                        }
                        if tab == .appearance {
                            let themes = LauncherThemeStore.shared
                            var own = themes.duplicate(LauncherTheme.named("reach-dark"))
                            own.name = "Sunset"
                            own.selectionColor = ThemeColor(red: 0.98, green: 0.55, blue: 0.2)
                            own.fontName = "Avenir Next"
                            own.cornerRadius = 12
                            themes.update(own)
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-appearance-own-\(mode).png", window: settings)
                            themes.editing = .results
                            try? await Task.sleep(for: .seconds(0.8))
                            let popover = NSApp.windows.first { $0.isVisible && String(describing: type(of: $0)).contains("Popover") }
                            capture(to: "\(dir)/settings-theme-editor-\(mode).png", window: popover)
                            themes.editing = nil
                            themes.themeID = "reach-light"
                            themes.editing = .background
                            try? await Task.sleep(for: .seconds(0.8))
                            let builtIn = NSApp.windows.first { $0.isVisible && String(describing: type(of: $0)).contains("Popover") }
                            capture(to: "\(dir)/settings-theme-built-in-\(mode).png", window: builtIn)
                            themes.editing = nil
                            themes.reset()
                            LauncherOptionsStore.shared.visibleResults = 6
                            LauncherOptionsStore.shared.screen = .activeWindow
                            LauncherOptionsStore.shared.isEditing = true
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-launcher-options-\(mode).png", window: settings?.attachedSheet)
                            LauncherOptionsStore.shared.reset()
                            try? await Task.sleep(for: .seconds(0.5))
                        }
                        if tab == .bookmarks {
                            // S-057: Safari unreadable, as without Full Disk Access.
                            let bookmarks = model.launcherModel.bookmarks
                            try? FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: bookmarkFiles.safari.path)
                            bookmarks.read()
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-bookmarks-denied-\(mode).png", window: settings)
                            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: bookmarkFiles.safari.path)
                            bookmarks.read()
                        }
                        if tab == .web {
                            WebSearchSettings.shared.page = .urls
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/settings-web-urls-\(mode).png", window: settings)
                            WebSearchSettings.shared.page = .searches
                        }
                    }
                    // S-036: Search Settings with a query, and with one that finds nothing.
                    let settings = NSApp.windows.first { $0.isVisible && $0 !== main && !$0.isSheet && $0.styleMask.contains(.titled) }
                    for (name, query) in [("search", "clip"), ("search-empty", "qxzv")] {
                        model.settingsQuery = query
                        try? await Task.sleep(for: .seconds(0.8))
                        capture(to: "\(dir)/settings-\(name)-\(mode).png", window: settings)
                    }
                    model.settingsQuery = ""
                }
            }
            print("SNAPSHOT done \(dir)")
            // An open sheet refuses terminate, and the run would wait forever.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    /// The launcher states, in the order they are captured. A new state is one entry here or in its feature's file.
    private static func launcherShots(model: AppModel, clips: ClipboardHistory) -> [LauncherShot] {
        let typed = [("empty", ""), ("results", "co"), ("files", "open brief"), ("thumbnails", "open o"), ("fallbacks", "zzqxv nothing"),
                     ("calculator", "=2*21+sqrt(16)"), ("web", "wiki alfred"), ("url", "example.org/docs"), ("history", "bowler"),
                     ("system", "sleep")].map { LauncherShot(name: $0.0, query: $0.1) }
        let showActions: @MainActor (AppModel) async -> Void = { model in
            _ = model.launcherModel.showActions()
            try? await Task.sleep(for: .seconds(0.5))
        }
        // The first three results in the buffer, with or without the buffer's actions.
        func buffer(actions: Bool) -> @MainActor (AppModel) async -> Void {
            { model in
                let lm = model.launcherModel
                for index in 0..<min(3, lm.results.count) {
                    lm.select(index)
                    _ = lm.toggleBuffer()
                }
                lm.select(0)
                if actions { _ = lm.showBufferActions() }
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
        // S-058: a card with custom actions, and a phone number's actions after →.
        func contactActions(detail: Bool) -> LauncherShot {
            LauncherShot(name: detail ? "contact-detail-actions" : "contact-custom", query: "sander", prepare: { model in
                ContactsSettings.shared.actions = SelfTest.sampleContactActions
                _ = model.launcherModel.showActions()
                model.launcherModel.actions?.select(2)
                if detail { _ = model.launcherModel.showDetailActions() }
                try? await Task.sleep(for: .seconds(0.5))
            }, cleanUp: { _ in ContactsSettings.shared.actions = [] })
        }
        return typed + [
            LauncherShot(name: "confirm", query: "restart", prepare: { $0.launcherModel.openSelected() }),
            LauncherShot(name: "quit", query: "quit"),
            LauncherShot(name: "shell", query: "> ls -la"),
            LauncherShot(name: "define", query: "define serendipity"),
            LauncherShot(name: "spell", query: "spell recieve"),
            LauncherShot(name: "contacts", query: "sand"),
            LauncherShot(name: "contact-card", query: "sander", prepare: showActions),
            LauncherShot(name: "email", query: "email sander"),
            LauncherShot(name: "path", query: SampleFiles.folder),
            LauncherShot(name: "actions", query: "safari", prepare: showActions),
        ] + workflowShots(model: model) + [
            LauncherShot(name: "selection", prepare: { model in
                model.launcherModel.showActions(for: .text("""
                    The quick brown fox jumps over the lazy dog.
                    Pack my box with five dozen liquor jugs.
                    """, source: "TextEdit"))
                try? await Task.sleep(for: .seconds(0.5))
            }),
            LauncherShot(name: "buffer", query: "co", prepare: buffer(actions: false)),
            LauncherShot(name: "buffer-actions", query: "co", prepare: buffer(actions: true)),
            LauncherShot(name: "clipboard-empty", prepare: clipboardViewer(nil)),
            LauncherShot(name: "clipboard", prepare: clipboardViewer(clips)),
            LauncherShot(name: "snip", query: "snip "),
            LauncherShot(name: "clipboard-snippets", prepare: clipboardViewer(clips, filter: "follow")),
            LauncherShot(name: "bookmarks", query: "swift"),
            contactActions(detail: false),
            contactActions(detail: true),
        ]
    }

    /// Captures the real window with screencapture, so glass, sidebars, and
    /// materials look exactly as on screen. That needs Screen Recording
    /// permission for the app that started this one (your terminal, or Claude).
    /// Without it, falls back to drawing the view hierarchy, which leaves
    /// sidebars and glass blank.
    static func capture(to path: String, window: NSWindow? = nil) {
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
                files.createFile(atPath: path, contents: sampleContents(name))
            } else {
                try? files.createDirectory(atPath: path, withIntermediateDirectories: true)
            }
        }
        return SampleFiles()
    }

    /// A real picture and a real PDF, so their rows show thumbnails (S-056); the rest stay empty.
    private static func sampleContents(_ name: String) -> Data {
        if name.hasSuffix(".jpg") { return SelfTest.samplePNG(hue: 0.55, type: .jpeg) }
        guard name.hasSuffix(".pdf") else { return Data() }
        let data = NSMutableData()
        var page = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data), let pdf = CGContext(consumer: consumer, mediaBox: &page, nil) else { return Data() }
        pdf.beginPDFPage(nil)
        pdf.setFillColor(CGColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1))
        pdf.fill(CGRect(x: 72, y: 600, width: 468, height: 120))
        pdf.setFillColor(CGColor(gray: 0.6, alpha: 1))
        for line in 0..<12 { pdf.fill(CGRect(x: 72, y: 540 - line * 32, width: line % 3 == 2 ? 300 : 468, height: 12)) }
        pdf.endPDFPage()
        pdf.closePDF()
        return data as Data
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
    /// Every view of `type` below this one.
    func descendants<T: NSView>(of type: T.Type) -> [T] {
        subviews.flatMap { view in [view as? T].compactMap { $0 } + view.descendants(of: type) }
    }
}
