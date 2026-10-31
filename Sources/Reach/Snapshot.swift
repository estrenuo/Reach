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
            if only == nil || only?.contains("launcher") == true, let launcher = model.launcher {
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
                let states = [("empty", ""), ("results", "co"), ("files", "open brief"), ("fallbacks", "zzqxv nothing"), ("calculator", "=2*21+sqrt(16)"), ("web", "wiki alfred"), ("url", "example.org/docs"), ("history", "bowler"), ("system", "sleep"), ("confirm", "restart"), ("quit", "quit"), ("shell", "> ls -la"), ("define", "define serendipity"), ("spell", "spell recieve"), ("contacts", "sand"), ("contact-card", "sander"), ("email", "email sander"), ("path", SampleFiles.folder), ("actions", "safari"), ("file-actions", ""), ("file-filter", ""), ("workflow-fallback", ""), ("selection-universal", ""), ("selection", ""), ("buffer", "co"), ("buffer-actions", "co"), ("clipboard-empty", ""), ("clipboard", ""), ("snip", "snip "), ("clipboard-snippets", "")]
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
                        // S-052: a sample workflow's Universal Action on selected text, filtered by "a".
                        if name == "selection-universal" {
                            let library = WorkflowLibrary.shared
                            let folder = library.folder.appending(path: "snapshot-universal.workflow", directoryHint: .isDirectory)
                            let plist: [String: Any] = ["name": "ChatGPT", "objects": [
                                ["uid": "UA", "type": WorkflowUniversalAction.type, "config": ["name": "Ask ChatGPT", "acceptstext": true]],
                            ]]
                            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                            try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                                .write(to: folder.appending(path: "info.plist"))
                            library.reload()
                            model.launcherModel.showActions(for: .text("The quick brown fox jumps over the lazy dog.", source: "TextEdit"))
                            model.launcherModel.actions?.filter = "a"
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/launcher-\(name)-\(mode).png", window: launcher.panel)
                            try? FileManager.default.removeItem(at: folder)
                            library.reload()
                            launcher.hide()
                            continue
                        }
                        // S-052: a sample workflow's Fallback Search below the web searches.
                        if name == "workflow-fallback" {
                            let library = WorkflowLibrary.shared
                            let folder = library.folder.appending(path: "snapshot-fallback.workflow", directoryHint: .isDirectory)
                            let plist: [String: Any] = ["name": "Shimmering Obsidian", "objects": [
                                ["uid": "FB", "type": WorkflowFallback.type, "config": ["text": "Search Vault: '{query}'"]],
                            ]]
                            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                            try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                                .write(to: folder.appending(path: "info.plist"))
                            library.reload()
                            model.launcherModel.query = "zzqxv meeting notes"
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/launcher-\(name)-\(mode).png", window: launcher.panel)
                            try? FileManager.default.removeItem(at: folder)
                            library.reload()
                            launcher.hide()
                            continue
                        }
                        // S-051: a sample workflow's File Filter, with the sample files for Spotlight's answer.
                        if name == "file-filter" {
                            let library = WorkflowLibrary.shared
                            let folder = library.folder.appending(path: "snapshot-filefilter.workflow", directoryHint: .isDirectory)
                            let plist: [String: Any] = ["name": "Visual Studio Code", "objects": [
                                ["uid": "FF", "type": FileFilter.type, "config": [
                                    "keyword": "codef", "withspace": true, "title": "Find and open with Visual Studio Code",
                                    "subtext": "Open files and folders",
                                ]],
                            ]]
                            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                            try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                                .write(to: folder.appending(path: "info.plist"))
                            library.reload()
                            let lm = model.launcherModel
                            let realFind = lm.workflows.findFiles
                            let samples = ((try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: SampleFiles.folder),
                                                                                         includingPropertiesForKeys: nil)) ?? [])
                                .sorted { $0.path < $1.path }.prefix(4)
                            lm.workflows.findFiles = { _, _, _, done in
                                done(samples.map { url in
                                    LaunchResult(id: url.path, title: url.lastPathComponent,
                                                 subtitle: (url.path as NSString).abbreviatingWithTildeInPath, icon: .file(url.path), url: url)
                                })
                            }
                            lm.query = "codef brief"
                            try? await Task.sleep(for: .seconds(0.8))
                            capture(to: "\(dir)/launcher-\(name)-\(mode).png", window: launcher.panel)
                            lm.workflows.findFiles = realFind
                            try? FileManager.default.removeItem(at: folder)
                            library.reload()
                            launcher.hide()
                            continue
                        }
                        // S-050: a sample workflow's File Action after Reach's own, filtered by "op".
                        if name == "file-actions" {
                            let library = WorkflowLibrary.shared
                            let folder = library.folder.appending(path: "snapshot-fileaction.workflow", directoryHint: .isDirectory)
                            let plist: [String: Any] = ["name": "Image Tools", "objects": [
                                ["uid": "FA", "type": WorkflowFileAction.type, "config": ["name": "Optimize Images", "acceptsmulti": 1]],
                            ]]
                            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                            try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                                .write(to: folder.appending(path: "info.plist"))
                            library.reload()
                            let sample = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: SampleFiles.folder),
                                                                                       includingPropertiesForKeys: nil))?
                                .filter { !$0.hasDirectoryPath }.sorted { $0.path < $1.path }.first
                            if let sample { model.launcherModel.showActions(for: .files([sample])) }
                            model.launcherModel.actions?.filter = "op"
                            try? await Task.sleep(for: .seconds(0.5))
                            capture(to: "\(dir)/launcher-\(name)-\(mode).png", window: launcher.panel)
                            try? FileManager.default.removeItem(at: folder)
                            library.reload()
                            launcher.hide()
                            continue
                        }
                        if name == "actions" || name == "contact-card" {
                            _ = model.launcherModel.showActions()
                            try? await Task.sleep(for: .seconds(0.5))
                        }
                        if name.hasPrefix("clipboard") {
                            ClipboardSettings.shared.keep[.text] = true
                            model.launcherModel.clipboard = name == "clipboard-empty" ? nil : clips
                            model.launcherModel.showClipboard()
                            if name == "clipboard-snippets" { model.launcherModel.viewer?.filter = "follow" }
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
            if only == nil || only?.contains("workflows") == true {
                await captureWorkflows(model: model, dir: dir)
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

    /// S-042: the Workflows window with nothing selected and with sample workflows.
    private static func captureWorkflows(model: AppModel, dir: String) async {
        let library = WorkflowLibrary.shared
        // The launcher view hands over openWindow when it first shows.
        model.launcher?.show()
        try? await Task.sleep(for: .seconds(0.5))
        model.launcher?.hide()
        let saved = library.workflows.map(\.folder)
        // Only sample workflows in the shots, in the /tmp library.
        let parked = FileManager.default.temporaryDirectory.appending(path: "Reach-parked-workflows-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: parked, withIntermediateDirectories: true)
        for folder in saved { try? FileManager.default.moveItem(at: folder, to: parked.appending(path: folder.lastPathComponent)) }
        library.reload()
        defer {
            for folder in library.workflows.map(\.folder) { try? FileManager.default.removeItem(at: folder) }
            for folder in saved { try? FileManager.default.moveItem(at: parked.appending(path: folder.lastPathComponent), to: folder) }
            try? FileManager.default.removeItem(at: parked)
            library.selection = nil
            library.reload()
        }
        model.launcherModel.openWorkflows()
        try? await Task.sleep(for: .seconds(1))
        let window = { NSApp.windows.first { $0.isVisible && $0.identifier?.rawValue.hasPrefix(WorkflowLibrary.windowID) == true } }
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            library.selection = nil
            try? await Task.sleep(for: .seconds(0.8))
            capture(to: "\(dir)/workflows-empty-\(mode).png", window: window())
        }
        library.addExample()
        if let folder = try? WorkflowFolder.addExample(into: library.folder) {
            try? WorkflowFolder.update(folder) {
                $0["name"] = "GitHub Repos"
                $0["createdby"] = "Ada Lovelace"
                $0["version"] = "2.1"
                $0["description"] = "Search your repositories."
                $0["disabled"] = true
            }
        }
        library.reload()
        library.selection = library.workflows.first { $0.name == "Hello World" }?.id
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            try? await Task.sleep(for: .seconds(0.8))
            capture(to: "\(dir)/workflows-\(mode).png", window: window())
        }
        // Configure Workflow… (S-043): as installed, then with the required field emptied.
        for (name, greeting) in [("workflow-configure", nil), ("workflow-configure-missing", "")] as [(String, String?)] {
            guard let example = library.selected else { break }
            if let greeting { library.saveConfiguration(["greeting": greeting], for: example) }
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                library.configuring = library.selected
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/\(name)-\(mode).png", window: window()?.attachedSheet)
                library.configuring = nil
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
        // Workflow Info… (S-046): each tab, and Variables before and after one is added.
        let tabs: [(String, WorkflowInfoSheet.Tab)] = [("about", .about), ("readme", .readme), ("variables-empty", .variables)]
        for (name, tab) in tabs + [("variables", .variables)] {
            if name == "variables", let example = library.selected {
                var info = WorkflowInfo(example)
                info.variables = [WorkflowVariable(name: "api_key", value: "sk-12345", dontExport: true),
                                  WorkflowVariable(name: "user", value: "ada")]
                library.saveInfo(info, for: example)
            }
            library.infoTab = tab
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                library.editingInfo = library.selected
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/workflow-info-\(name)-\(mode).png", window: window()?.attachedSheet)
                library.editingInfo = nil
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
        library.infoTab = .about
        // Hotkeys… (S-049): one set, one empty, one on Reach's launcher hotkey.
        if let example = library.selected {
            try? WorkflowFolder.update(example.folder) {
                $0["objects"] = ($0["objects"] as? [[String: Any]] ?? []) + [
                    ["uid": "HKSET", "type": WorkflowHotkey.type, "config": ["argument": 1]],
                    ["uid": "HKEMPTY", "type": WorkflowHotkey.type, "config": ["argument": 2]],
                    ["uid": "HKTAKEN", "type": WorkflowHotkey.type, "config": ["argument": 0]],
                ]
            }
            library.reload()
            let hotkeys = WorkflowHotkeys.shared
            if let current = library.selected {
                hotkeys.set(.init(combo: KeyCombo(keyCode: 40, modifiers: KeyCombo.control | KeyCombo.option), keyName: "K"),
                            for: current, uid: "HKSET")
                hotkeys.set(.init(combo: HotkeyCenter.shared.combo, keyName: "Space"), for: current, uid: "HKTAKEN")
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    library.editingHotkeys = current
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/workflow-hotkeys-\(mode).png", window: window()?.attachedSheet)
                    library.editingHotkeys = nil
                    try? await Task.sleep(for: .seconds(0.5))
                }
                hotkeys.set(nil, for: current, uid: "HKSET")
                hotkeys.set(nil, for: current, uid: "HKTAKEN")
            }
        }
        // The debugger (S-045) with a run that printed and one that failed.
        if let example = library.selected {
            library.log.clear()
            library.record(example, object: "Script Filter", input: "hello Ada",
                           result: ScriptResult(output: Data(#"{"items":[{"title":"Hello, Ada","arg":"Hello, Ada"}]}"#.utf8)))
            library.record(example, object: "Run Script", input: nil,
                           result: ScriptResult(errors: "say: command not found", status: 127))
            library.debugging = true
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/workflows-debugger-\(mode).png", window: window())
            }
            library.debugging = false
            library.log.clear()
        }
        window()?.close()
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
    /// Every view of `type` below this one.
    func descendants<T: NSView>(of type: T.Type) -> [T] {
        subviews.flatMap { view in [view as? T].compactMap { $0 } + view.descendants(of: type) }
    }
}
