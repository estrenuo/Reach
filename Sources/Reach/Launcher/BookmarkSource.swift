import AppKit
import OSLog
import ReachKit

/// Settings > Web Bookmarks (S-057): which browsers, where bookmarks show,
/// and which browser opens them. Saved in `Store.settings`.
@Observable
final class BookmarkSettings {
    static let shared = BookmarkSettings()

    var safariOn: Bool { didSet { save(safariOn, "safari") } }
    var chromeOn: Bool { didSet { save(chromeOn, "chrome") } }
    var showMode: BookmarkShowMode { didSet { save(showMode.rawValue, "show") } }
    var openMode: BookmarkOpenMode { didSet { save(openMode.rawValue, "open") } }

    private init() {
        let defaults = Store.settings
        safariOn = defaults.object(forKey: "bookmarks.safari") as? Bool ?? true
        chromeOn = defaults.object(forKey: "bookmarks.chrome") as? Bool ?? true
        showMode = defaults.string(forKey: "bookmarks.show").flatMap(BookmarkShowMode.init) ?? .defaultResults
        openMode = defaults.string(forKey: "bookmarks.open").flatMap(BookmarkOpenMode.init) ?? .defaultBrowser
    }

    private func save(_ value: Any, _ key: String) { Store.settings.set(value, forKey: "bookmarks." + key) }

    /// Back to the standard settings; the self-test leaves no trace this way.
    func reset() {
        safariOn = true
        chromeOn = true
        showMode = .defaultResults
        openMode = .defaultBrowser
    }
}

extension BookmarkShowMode {
    var title: String {
        switch self {
        case .defaultResults: "In Default Results"
        case .keywordOnly: "With Keyword Only"
        }
    }
}

extension BookmarkOpenMode {
    var title: String {
        switch self {
        case .defaultBrowser: "Default Browser"
        case .sourceBrowser: "The Bookmark’s Browser"
        }
    }
}

/// Web bookmarks from Safari and every Chrome profile (S-057), found by title
/// or address. The files are read on the first query that needs them, and
/// again on the first query after the launcher shows with a file changed:
/// never while typing.
@Observable
final class BookmarkSource: ResultSource {
    /// Where the browsers keep their bookmarks.
    struct Files: Equatable {
        var safari: URL
        /// Chrome's folder with a subfolder per profile.
        var chromeRoot: URL

        /// The real files, or for test runs a folder in /tmp that holds only
        /// fixtures: tests, snapshots and the self-test never read the person's own.
        static var standard: Files {
            if Store.isOverridden {
                let root = URL(fileURLWithPath: "/tmp/Reach-bookmarks", isDirectory: true)
                return Files(safari: root.appending(path: "Safari/Bookmarks.plist"), chromeRoot: root.appending(path: "Chrome"))
            }
            let home = FileManager.default.homeDirectoryForCurrentUser
            return Files(safari: home.appending(path: "Library/Safari/Bookmarks.plist"),
                         chromeRoot: home.appending(path: "Library/Application Support/Google/Chrome"))
        }
    }

    /// Whether Safari's file could be read.
    enum SafariAccess: Equatable {
        case unknown, readable, missing
        /// macOS refused the read: Reach needs Full Disk Access.
        case denied
    }

    static let log = Logger(subsystem: "com.sanderrobijns.reach", category: "bookmarks")
    static let fullDiskAccess = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    static let maxResults = 9

    @ObservationIgnored let settings: BookmarkSettings
    @ObservationIgnored var files: Files { didSet { forget() } }
    /// What the last read found, for Settings.
    private(set) var safariAccess = SafariAccess.unknown
    private(set) var counts: [BookmarkBrowser: Int] = [:]
    /// How many times the files were read; the self-test checks it.
    @ObservationIgnored private(set) var reads = 0
    @ObservationIgnored private var bookmarks: [WebBookmark]?
    /// The browsers that were on for the last read.
    @ObservationIgnored private var readFor: [Bool] = []
    /// The files the last read looked at, with their modification dates.
    @ObservationIgnored private var stamps: [String: Date] = [:]
    @ObservationIgnored private var icons: [BookmarkBrowser: LaunchResult.Icon] = [:]

    init(settings: BookmarkSettings = .shared, files: Files = .standard) {
        self.settings = settings
        self.files = files
    }

    /// Drops what was read; the next query reads the files again.
    func forget() { bookmarks = nil }

    /// Called when the launcher shows: a file that changed since the last read
    /// is read again on the next query. Only dates are compared here.
    func checkFiles() {
        guard bookmarks != nil, currentStamps() != stamps else { return }
        forget()
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard settings.safariOn || settings.chromeOn, case .normal(let typed) = query,
              let text = WebBookmarks.searchText(in: typed, mode: settings.showMode), !text.isEmpty else { return [] }
        let on = [settings.safariOn, settings.chromeOn]
        let all = bookmarks.flatMap { readFor == on ? $0 : nil } ?? read()
        return WebBookmarks.matches(text, in: all).prefix(Self.maxResults).map { match in
            Scored(result: row(for: match.bookmark), score: match.score)
        }
    }

    /// Reads the files of the browsers that are on, now. Settings also calls
    /// this, to show whether Safari's file can be read.
    @discardableResult
    func read() -> [WebBookmark] {
        reads += 1
        readFor = [settings.safariOn, settings.chromeOn]
        var lists: [[WebBookmark]] = []
        var counts: [BookmarkBrowser: Int] = [:]
        if settings.safariOn {
            let (data, access) = Self.load(files.safari)
            safariAccess = access
            if let data {
                do {
                    let found = try WebBookmarks.safari(data)
                    lists.append(found)
                    counts[.safari] = found.count
                } catch {
                    Self.log.error("Safari's bookmarks file has an unknown format")
                }
            }
        }
        if settings.chromeOn {
            for file in WebBookmarks.chromeProfiles(in: files.chromeRoot) {
                guard let data = Self.load(file).data else { continue }
                do {
                    let found = try WebBookmarks.chrome(data)
                    lists.append(found)
                    counts[.chrome, default: 0] += found.count
                } catch {
                    Self.log.error("a Chrome bookmarks file has an unknown format")
                }
            }
        }
        let merged = WebBookmarks.merge(lists)
        Self.log.notice("read \(merged.count, privacy: .public) bookmarks")
        bookmarks = merged
        stamps = currentStamps()
        if self.counts != counts { self.counts = counts }
        return merged
    }

    /// A file's contents, and whether macOS let Reach read it. Without Full
    /// Disk Access the read fails with a permission error, not "no such file".
    static func load(_ url: URL) -> (data: Data?, access: SafariAccess) {
        do {
            return (try Data(contentsOf: url), .readable)
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            return (nil, .denied)
        } catch let error as NSError {
            let posix = (error.userInfo[NSUnderlyingErrorKey] as? NSError)?.code
            return (nil, posix == Int(EPERM) || posix == Int(EACCES) ? .denied : .missing)
        }
    }

    private func currentStamps() -> [String: Date] {
        var urls: [URL] = []
        if settings.safariOn { urls.append(files.safari) }
        if settings.chromeOn { urls += WebBookmarks.chromeProfiles(in: files.chromeRoot) }
        var stamps: [String: Date] = [:]
        for url in urls {
            stamps[url.path] = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date ?? .distantPast
        }
        return stamps
    }

    func row(for bookmark: WebBookmark) -> LaunchResult {
        var result = LaunchResult(id: "bookmark:\(bookmark.key)", title: bookmark.title, subtitle: bookmark.address,
                                  icon: icon(bookmark.browser), url: URL(string: bookmark.url), kindLabel: "Bookmark")
        if settings.openMode == .sourceBrowser { result.opensIn = bookmark.browser.bundleID }
        return result
    }

    /// The browser's own icon; a bookmark symbol when it is not installed.
    private func icon(_ browser: BookmarkBrowser) -> LaunchResult.Icon {
        if let icon = icons[browser] { return icon }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID)
            .map { LaunchResult.Icon.file($0.path) } ?? .symbol("bookmark")
        icons[browser] = icon
        return icon
    }

    /// Opens `url` in the app with this bundle id; false when it is not installed.
    static func open(_ url: URL, in bundleID: String) -> Bool {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return false }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        return true
    }
}
