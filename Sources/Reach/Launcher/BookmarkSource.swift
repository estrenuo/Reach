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
/// never while typing. That read runs off the main thread: the query answers
/// at once from the list it has (or with nothing), and the matches follow
/// through `later` when the read lands.
@Observable
final class BookmarkSource: ResultSource {
    /// Where the browsers keep their bookmarks.
    nonisolated struct Files: Equatable, Sendable {
        var safari: URL
        /// Chrome's folder with a subfolder per profile.
        var chromeRoot: URL

        /// The real files, or for test runs a folder in /tmp that holds only
        /// fixtures: tests, snapshots and the self-test never read the person's own.
        @MainActor static var standard: Files {
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
    nonisolated enum SafariAccess: Equatable, Sendable {
        case unknown, readable, missing
        /// macOS refused the read: Reach needs Full Disk Access.
        case denied
    }

    /// What one read found. Made off the main thread by `load`.
    nonisolated struct Read: Sendable {
        var bookmarks: [WebBookmark]
        var counts: [BookmarkBrowser: Int]
        /// Nil when Safari was off: the last known access stays.
        var safariAccess: SafariAccess?
        /// The files looked at, with their modification dates.
        var stamps: [String: Date]
    }

    nonisolated static let log = Logger(subsystem: "com.sanderrobijns.reach", category: "bookmarks")
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
    /// True when a file changed since the last read: the next query reads again.
    @ObservationIgnored private var stale = false
    /// The browsers that were on for the last read.
    @ObservationIgnored private var readFor: [Bool] = []
    /// The files the last read looked at, with their modification dates.
    @ObservationIgnored private var stamps: [String: Date] = [:]
    @ObservationIgnored private var icons: [BookmarkBrowser: LaunchResult.Icon] = [:]
    /// The read running off the main thread; one at a time.
    @ObservationIgnored private var reading: Task<Void, Never>?
    /// Goes up when the files change, the list is dropped, or `read()` runs:
    /// a background read that started before lands unused.
    @ObservationIgnored private var generation = 0
    /// The query that answered without the read, and where its matches go.
    @ObservationIgnored private var waiting: (later: @MainActor ([Scored]) -> Void, query: QueryKind)?

    init(settings: BookmarkSettings = .shared, files: Files = .standard) {
        self.settings = settings
        self.files = files
    }

    /// Drops what was read; the next query reads the files again.
    func forget() {
        bookmarks = nil
        generation += 1
    }

    /// Called when the launcher shows: a file that changed since the last read
    /// is read again on the next query. Only dates are compared here.
    func checkFiles() {
        guard bookmarks != nil, !stale, currentStamps() != stamps else { return }
        stale = true
    }

    /// True while a read runs off the main thread.
    var isReading: Bool { reading != nil }

    /// Waits for the running read, if any; for the self-test.
    func readDone() async { await reading?.value }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard settings.safariOn || settings.chromeOn, case .normal(let typed) = query,
              let text = WebBookmarks.searchText(in: typed, mode: settings.showMode), !text.isEmpty else { return [] }
        let on = [settings.safariOn, settings.chromeOn]
        if bookmarks == nil || stale || readFor != on {
            waiting = (later, query)
            readInBackground()
        }
        // Until the read lands: the old list, without a browser that is now off.
        let all = (bookmarks ?? []).filter { readFor == on || on[$0.browser == .safari ? 0 : 1] }
        return matches(text, in: all)
    }

    func cancel() { waiting = nil }

    private func matches(_ text: String, in all: [WebBookmark]) -> [Scored] {
        WebBookmarks.matches(text, in: all).prefix(Self.maxResults).map { match in
            Scored(result: row(for: match.bookmark), score: match.score)
        }
    }

    /// Starts one read off the main thread, unless one runs. When it lands,
    /// the query that waited gets its matches through `later`.
    private func readInBackground() {
        guard reading == nil else { return }
        reads += 1
        let started = generation
        let (files, on) = (files, [settings.safariOn, settings.chromeOn])
        reading = Task { [weak self] in
            let read = await Task.detached(priority: .userInitiated) { Self.load(files, safari: on[0], chrome: on[1]) }.value
            guard let self else { return }
            reading = nil
            // Unused when the files or the list changed while it ran.
            if generation == started { use(read, for: on) }
            guard let (later, query) = waiting else { return }
            waiting = nil
            // Starts the next read itself when this one landed unused or the browsers changed.
            later(results(for: query, later: later) ?? [])
        }
    }

    /// Reads the files of the browsers that are on, now, on the main thread.
    /// Settings calls this when its page opens or a browser is switched, to
    /// show the counts and whether Safari's file can be read; the snapshots
    /// call it to capture that page. Neither happens while typing.
    @discardableResult
    func read() -> [WebBookmark] {
        reads += 1
        generation += 1
        let on = [settings.safariOn, settings.chromeOn]
        let read = Self.load(files, safari: on[0], chrome: on[1])
        use(read, for: on)
        return read.bookmarks
    }

    private func use(_ read: Read, for on: [Bool]) {
        readFor = on
        bookmarks = read.bookmarks
        stale = false
        stamps = read.stamps
        if let access = read.safariAccess { safariAccess = access }
        if counts != read.counts { counts = read.counts }
    }

    /// Reads and parses the files; runs on any thread.
    nonisolated static func load(_ files: Files, safari safariOn: Bool, chrome chromeOn: Bool) -> Read {
        var lists: [[WebBookmark]] = []
        var counts: [BookmarkBrowser: Int] = [:]
        var access: SafariAccess?
        if safariOn {
            let (data, found) = load(files.safari)
            access = found
            if let data {
                do {
                    let found = try WebBookmarks.safari(data)
                    lists.append(found)
                    counts[.safari] = found.count
                } catch {
                    log.error("Safari's bookmarks file has an unknown format")
                }
            }
        }
        if chromeOn {
            for file in WebBookmarks.chromeProfiles(in: files.chromeRoot) {
                guard let data = load(file).data else { continue }
                do {
                    let found = try WebBookmarks.chrome(data)
                    lists.append(found)
                    counts[.chrome, default: 0] += found.count
                } catch {
                    log.error("a Chrome bookmarks file has an unknown format")
                }
            }
        }
        let merged = WebBookmarks.merge(lists)
        log.notice("read \(merged.count, privacy: .public) bookmarks")
        return Read(bookmarks: merged, counts: counts, safariAccess: access, stamps: stamps(files, safari: safariOn, chrome: chromeOn))
    }

    /// A file's contents, and whether macOS let Reach read it. Without Full
    /// Disk Access the read fails with a permission error, not "no such file".
    nonisolated static func load(_ url: URL) -> (data: Data?, access: SafariAccess) {
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
        Self.stamps(files, safari: settings.safariOn, chrome: settings.chromeOn)
    }

    /// The modification date of every file a read with these browsers looks at.
    nonisolated static func stamps(_ files: Files, safari: Bool, chrome: Bool) -> [String: Date] {
        var urls: [URL] = []
        if safari { urls.append(files.safari) }
        if chrome { urls += WebBookmarks.chromeProfiles(in: files.chromeRoot) }
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
