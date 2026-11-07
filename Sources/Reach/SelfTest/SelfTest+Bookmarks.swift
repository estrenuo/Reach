import AppKit
import ReachKit

extension SelfTest {
    /// Fixture bookmark files in /tmp, in Safari's and Chrome's own formats:
    /// never the person's own. Also used by the snapshots.
    static func writeBookmarkFixtures(in root: URL, chromeExtra: String = "") -> BookmarkSource.Files {
        let files = BookmarkSource.Files(safari: root.appending(path: "Safari/Bookmarks.plist"), chromeRoot: root.appending(path: "Chrome"))
        let fm = FileManager.default
        try? fm.removeItem(at: root)
        try? fm.createDirectory(at: files.safari.deletingLastPathComponent(), withIntermediateDirectories: true)
        func leaf(_ title: String, _ url: String) -> [String: Any] {
            ["WebBookmarkType": "WebBookmarkTypeLeaf", "URLString": url, "URIDictionary": ["title": title]]
        }
        let safari: [String: Any] = ["WebBookmarkType": "WebBookmarkTypeList", "Title": "", "Children": [
            ["WebBookmarkType": "WebBookmarkTypeList", "Title": "BookmarksBar", "Children": [
                leaf("Swift Forums", "https://forums.swift.org/"),
                leaf("Apple Developer", "https://developer.apple.com/"),
            ]],
            ["WebBookmarkType": "WebBookmarkTypeList", "Title": "com.apple.ReadingList", "Children": [
                leaf("Swift reading list item", "https://example.com/swift-later"),
            ]],
        ]]
        try? PropertyListSerialization.data(fromPropertyList: safari, format: .binary, options: 0).write(to: files.safari)
        writeChrome(files, profile: "Default", [("Swift Forums", "https://forums.swift.org"),
                                                ("Swift Package Index", "https://swiftpackageindex.com/"),
                                                ("SwiftUI Documentation", "https://developer.apple.com/documentation/swiftui")])
        writeChrome(files, profile: "Profile 1", [("Swift Evolution", "https://github.com/swiftlang/swift-evolution")])
        return files
    }

    /// A large Safari file (`count` bookmarks in folders of 100, several MB),
    /// for timing the first query. Chrome stays empty.
    static func writeLargeBookmarkFixture(in root: URL, count: Int) -> BookmarkSource.Files {
        let files = BookmarkSource.Files(safari: root.appending(path: "Safari/Bookmarks.plist"), chromeRoot: root.appending(path: "Chrome"))
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: files.safari.deletingLastPathComponent(), withIntermediateDirectories: true)
        let folders = stride(from: 0, to: count, by: 100).map { start -> [String: Any] in
            let leaves = (start..<min(start + 100, count)).map { n -> [String: Any] in
                ["WebBookmarkType": "WebBookmarkTypeLeaf", "WebBookmarkUUID": UUID().uuidString,
                 "URLString": "https://site\(n).example.com/articles/\(n)/a-long-path-for-realistic-size?ref=bookmarks",
                 "URIDictionary": ["title": "Bookmark number \(n) about topic \(n % 97)"]]
            }
            return ["WebBookmarkType": "WebBookmarkTypeList", "Title": "Folder \(start / 100)", "Children": leaves]
        }
        let safari: [String: Any] = ["WebBookmarkType": "WebBookmarkTypeList", "Title": "", "Children": [
            ["WebBookmarkType": "WebBookmarkTypeList", "Title": "BookmarksBar", "Children": folders],
        ]]
        try? PropertyListSerialization.data(fromPropertyList: safari, format: .binary, options: 0).write(to: files.safari)
        return files
    }

    /// The first query with a large Safari file (20,000 bookmarks, about
    /// 6 MB) answers before the file is read; the read runs off the main
    /// thread, once, and its matches arrive late for the newest query.
    static func checkFirstQueryOffMain(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let source = lm.bookmarks
        let root = URL(fileURLWithPath: "/tmp/Reach-bookmarks-large", isDirectory: true)
        let files = source.files
        source.files = writeLargeBookmarkFixture(in: root, count: 20_000)
        defer {
            source.files = files
            try? FileManager.default.removeItem(at: root)
        }
        func marks() -> [LaunchResult] { lm.results.filter { $0.id.hasPrefix("bookmark:") } }

        launcher.show()
        let readsBefore = source.reads
        let clock = ContinuousClock()
        let first = clock.measure { lm.query = "bm topic 4" }
        check("the first query answers while the files are read off the main thread",
              source.isReading && marks().isEmpty, "\(first), reading: \(source.isReading)")
        print("TIMING first bm query: \(first)")
        let next = clock.measure { lm.query = "bm topic 42" }
        check("typing on starts no second read", source.reads == readsBefore + 1, "\(source.reads - readsBefore) reads, \(next)")
        let waited = clock.now
        await source.readDone()
        print("TIMING read off the main thread: \(clock.now - waited) after the second keystroke")
        check("when the read lands, the newest query's matches arrive",
              marks().count == BookmarkSource.maxResults && marks().allSatisfy { $0.title.hasSuffix("topic 42") },
              marks().map(\.title).joined(separator: ", "))
        let warm = clock.measure { lm.query = "bm topic 43" }
        print("TIMING next bm query: \(warm)")
        check("the query after it uses the list without reading", source.reads == readsBefore + 1 && !source.isReading)
        launcher.hide()
    }

    static func writeChrome(_ files: BookmarkSource.Files, profile: String, _ marks: [(String, String)]) {
        let folder = files.chromeRoot.appending(path: profile)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let children = marks.map { ["name": $0.0, "type": "url", "url": $0.1] }
        let json: [String: Any] = ["roots": ["bookmark_bar": ["name": "Bookmarks bar", "type": "folder", "children": children]]]
        try? JSONSerialization.data(withJSONObject: json).write(to: folder.appending(path: "Bookmarks"))
    }

    /// S-057: bookmarks from Safari and every Chrome profile, once each; ↩
    /// opens them in the default browser or the bookmark's own; a changed file
    /// is read again on the next query after the launcher shows, never while
    /// typing; without Full Disk Access Safari is skipped and Settings says why.
    static func checkBookmarks(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let source = lm.bookmarks
        let settings = BookmarkSettings.shared
        let root = URL(fileURLWithPath: "/tmp/Reach-bookmarks-self", isDirectory: true)
        var opened: [URL] = []
        var openedIn: [(URL, String)] = []
        let (opener, openerIn, files) = (lm.opener, lm.openerIn, source.files)
        lm.opener = { opened.append($0); return true }
        lm.openerIn = { openedIn.append(($0, $1)); return true }
        source.files = writeBookmarkFixtures(in: root)
        defer {
            settings.reset()
            (lm.opener, lm.openerIn) = (opener, openerIn)
            source.files = files
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: root.appending(path: "Safari/Bookmarks.plist").path)
            try? FileManager.default.removeItem(at: root)
        }
        func marks() -> [LaunchResult] { lm.results.filter { $0.id.hasPrefix("bookmark:") } }
        /// Types a query and waits for a read it starts: reads run off the main thread.
        func type(_ text: String) async {
            lm.query = text
            await source.readDone()
        }

        launcher.show()
        await type("swift")
        let rows = marks()
        check("a query finds bookmarks from Safari and every Chrome profile",
              Set(rows.map(\.title)) == ["Swift Forums", "Swift Package Index", "SwiftUI Documentation", "Swift Evolution"],
              rows.map(\.title).joined(separator: ", "))
        check("a page in both browsers shows once", rows.filter { $0.title == "Swift Forums" }.count == 1)
        check("the Reading List stays out", !rows.contains { $0.title.contains("reading list") })
        let forums = rows.first { $0.title == "Swift Forums" }
        check("a bookmark row: title, the address as subtext, the browser's icon",
              forums?.subtitle == "forums.swift.org" && forums?.kindLabel == "Bookmark"
                  && { if case .file(let path) = forums?.icon { path.hasSuffix(".app") } else { false } }(),
              "\(forums?.subtitle ?? "-") \(String(describing: forums?.icon))")
        lm.query = "swiftpackageindex.com"
        check("the address finds a bookmark too", marks().first?.title == "Swift Package Index")

        lm.query = "swift package"
        if let index = lm.results.firstIndex(where: { $0.title == "Swift Package Index" }) { lm.open(at: index) }
        check("↩ opens it in the default browser and hides the launcher",
              opened.last?.absoluteString == "https://swiftpackageindex.com/" && openedIn.isEmpty && !launcher.isVisible)

        settings.openMode = .sourceBrowser
        await showAgain(launcher)
        lm.query = "swift evolution"
        if let index = lm.results.firstIndex(where: { $0.title == "Swift Evolution" }) { lm.open(at: index) }
        check("with Open in set to the bookmark's browser, ↩ opens it in Chrome",
              openedIn.last?.0.absoluteString == "https://github.com/swiftlang/swift-evolution"
                  && openedIn.last?.1 == BookmarkBrowser.chrome.bundleID)
        settings.openMode = .defaultBrowser

        settings.showMode = .keywordOnly
        await showAgain(launcher)
        lm.query = "swift"
        check("With Keyword Only, a plain query finds no bookmark", marks().isEmpty)
        lm.query = "bm swift"
        check("With Keyword Only, “bm swift” finds them", marks().count == 4, marks().map(\.title).joined(separator: ", "))
        settings.showMode = .defaultResults
        lm.query = "bm swift"
        check("“bm” works among the default results too", marks().count == 4)

        // A changed file: not while typing, but on the next query after the launcher shows.
        lm.query = "swi"
        let readsBefore = source.reads
        try? await Task.sleep(for: .milliseconds(1100))  // A newer modification date.
        writeChrome(source.files, profile: "Profile 1", [("Swift Evolution", "https://github.com/swiftlang/swift-evolution"),
                                                         ("Swift Testing", "https://github.com/swiftlang/swift-testing")])
        lm.query = "swift"
        lm.query = "swift t"
        check("while typing, the files are not read again", source.reads == readsBefore && !marks().contains { $0.title == "Swift Testing" },
              "\(source.reads - readsBefore) reads")
        launcher.hide()
        await showAgain(launcher)
        check("showing the launcher does not read them either", source.reads == readsBefore)
        await type("swift test")
        check("the next query reads the changed file", source.reads == readsBefore + 1 && marks().first?.title == "Swift Testing",
              marks().map(\.title).joined(separator: ", "))
        lm.query = "swift testi"
        check("and the query after it does not", source.reads == readsBefore + 1)

        settings.chromeOn = false
        await type("swift")
        check("with Chrome off, only Safari's bookmarks", Set(marks().map(\.title)) == ["Swift Forums"],
              marks().map(\.title).joined(separator: ", "))
        settings.chromeOn = true

        // Without Full Disk Access macOS refuses the read; an unreadable fixture does the same.
        let safariFile = source.files.safari.path
        try? FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: safariFile)
        launcher.hide()
        await showAgain(launcher)
        await type("swift")
        check("without Full Disk Access, Safari is skipped and Chrome still shows",
              source.safariAccess == .denied && !marks().isEmpty && !marks().contains { $0.title == "Apple Developer" },
              "\(source.safariAccess) \(marks().map(\.title).joined(separator: ", "))")
        launcher.hide()

        // The row itself is in the snapshot settings-bookmarks-denied; here its condition and its button.
        check("Settings > Web Bookmarks shows the Full Disk Access row",
              BookmarkSettingsView.showsAccessRow(settings: settings, source: source))
        BookmarkSettingsView.openFullDiskAccess()
        check("Open Full Disk Access… opens the Full Disk Access pane", opened.last == BookmarkSource.fullDiskAccess,
              opened.last?.absoluteString ?? "nothing opened")
        settings.safariOn = false
        check("with Safari off, the row goes away", !BookmarkSettingsView.showsAccessRow(settings: settings, source: source))
        settings.safariOn = true
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: safariFile)
        source.read()
        check("with access back, Safari is read again", source.safariAccess == .readable)

        source.files = files
        await checkFirstQueryOffMain(model: model)
    }
}
