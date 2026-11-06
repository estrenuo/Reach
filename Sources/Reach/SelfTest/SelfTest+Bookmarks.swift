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

        launcher.show()
        lm.query = "swift"
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
        lm.query = "swift test"
        check("the next query reads the changed file", source.reads == readsBefore + 1 && marks().first?.title == "Swift Testing",
              marks().map(\.title).joined(separator: ", "))
        lm.query = "swift testi"
        check("and the query after it does not", source.reads == readsBefore + 1)

        settings.chromeOn = false
        lm.query = "swift"
        check("with Chrome off, only Safari's bookmarks", Set(marks().map(\.title)) == ["Swift Forums"],
              marks().map(\.title).joined(separator: ", "))
        settings.chromeOn = true

        // Without Full Disk Access macOS refuses the read; an unreadable fixture does the same.
        let safariFile = source.files.safari.path
        try? FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: safariFile)
        launcher.hide()
        await showAgain(launcher)
        lm.query = "swift"
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
    }
}
