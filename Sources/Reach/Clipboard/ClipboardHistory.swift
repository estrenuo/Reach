import AppKit
import OSLog
import ReachKit
import SwiftData

/// `log show --last 10m --predicate 'subsystem == "com.sanderrobijns.reach"'`
/// Only kinds and counts: what people copy never goes to the log.
let clipboardLog = Logger(subsystem: "com.sanderrobijns.reach", category: "clipboard")

/// Settings > Clipboard (S-025): which kinds are kept, and for how long.
/// Everything is off until people turn a kind on. Saved in `Store.settings`.
@Observable
final class ClipboardSettings {
    static let shared = ClipboardSettings()

    var keep: [ClipboardPolicy.Kind: Bool] {
        didSet { for (kind, on) in keep { Store.settings.set(on, forKey: "clipboard.keep." + kind.rawValue) } }
    }
    var retention: [ClipboardPolicy.Kind: ClipboardPolicy.Retention] {
        didSet { for (kind, days) in retention { Store.settings.set(days.rawValue, forKey: "clipboard.retention." + kind.rawValue) } }
    }

    private init() {
        let defaults = Store.settings
        keep = Dictionary(uniqueKeysWithValues: ClipboardPolicy.Kind.allCases.map {
            ($0, defaults.bool(forKey: "clipboard.keep." + $0.rawValue))
        })
        retention = Dictionary(uniqueKeysWithValues: ClipboardPolicy.Kind.allCases.map { kind in
            let saved = ClipboardPolicy.Retention(rawValue: defaults.integer(forKey: "clipboard.retention." + kind.rawValue))
            return (kind, saved ?? ClipboardPolicy.standardRetention(kind))
        })
    }

    var kindsOn: Set<ClipboardPolicy.Kind> { Set(keep.filter(\.value).keys) }
    var isOn: Bool { !kindsOn.isEmpty }

    func retention(_ kind: ClipboardPolicy.Kind) -> ClipboardPolicy.Retention {
        retention[kind] ?? ClipboardPolicy.standardRetention(kind)
    }

    /// Apps whose copies are never kept. Settings lists them in S-027.
    var ignoredApps: Set<String> { ClipboardPolicy.standardIgnoredApps }

    /// Everything off, standard retention; the self-test leaves no trace this way.
    func reset() {
        keep = Dictionary(uniqueKeysWithValues: ClipboardPolicy.Kind.allCases.map { ($0, false) })
        retention = Dictionary(uniqueKeysWithValues: ClipboardPolicy.Kind.allCases.map { ($0, ClipboardPolicy.standardRetention($0)) })
    }
}

/// Watches a pasteboard and stores what is copied, per the settings (S-025).
/// It looks at the pasteboard's types first, which macOS allows without
/// asking, and reads the contents only for a kind that is kept.
final class ClipboardHistory {
    static let pollInterval: TimeInterval = 0.5
    let pasteboard: NSPasteboard
    let context: ModelContext
    let settings: ClipboardSettings
    /// The app in front, which copied it. The self-test swaps in a fake.
    var frontApp: () -> (name: String, bundleID: String)? = {
        NSWorkspace.shared.frontmostApplication.map { ($0.localizedName ?? "", $0.bundleIdentifier ?? "") }
    }
    /// The time, for retention. The self-test moves it forward.
    var now: () -> Date = { Date.now }
    private var changeCount: Int
    private var poller: Timer?
    private var purger: Timer?

    init(pasteboard: NSPasteboard = .general, context: ModelContext, settings: ClipboardSettings = .shared) {
        self.pasteboard = pasteboard
        self.context = context
        self.settings = settings
        // What was copied before launch is not new.
        changeCount = pasteboard.changeCount
    }

    /// Purges expired clips, then watches the pasteboard and purges every hour.
    func start() {
        purge()
        poller = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        purger = Timer.scheduledTimer(withTimeInterval: ClipboardPolicy.purgeInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.purge() }
        }
    }

    func stop() {
        poller?.invalidate()
        purger?.invalidate()
        poller = nil
        purger = nil
    }

    var isRunning: Bool { poller != nil }
    var purgesHourly: Bool { purger?.timeInterval == ClipboardPolicy.purgeInterval }

    /// Stores the pasteboard's contents when they changed and are kept. True when a clip was stored.
    @discardableResult
    func poll() -> Bool {
        let count = pasteboard.changeCount
        guard count != changeCount else { return false }
        changeCount = count
        // With every kind off, nothing is read at all: no macOS paste alert.
        guard settings.isOn else { return false }
        let types = pasteboard.types?.map(\.rawValue) ?? []
        let app = frontApp()
        guard let kind = ClipboardPolicy.keep(types: types, from: app?.bundleID,
                                              ignoredApps: settings.ignoredApps, on: settings.kindsOn) else { return false }
        guard let clip = read(kind) else { return false }
        store(clip, kind: kind, app: app)
        return true
    }

    private func read(_ kind: ClipboardPolicy.Kind) -> (text: String, image: Data?)? {
        switch kind {
        case .text:
            guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return nil }
            return (text, nil)
        case .image:
            guard let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) else { return nil }
            return ("", data)
        case .files:
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            guard !urls.isEmpty else { return nil }
            return (urls.map(\.path).joined(separator: "\n"), nil)
        }
    }

    /// The same text or file list as a stored clip moves that clip to the top.
    private func store(_ clip: (text: String, image: Data?), kind: ClipboardPolicy.Kind, app: (name: String, bundleID: String)?) {
        let raw = kind.rawValue
        if clip.image == nil {
            let text = clip.text
            var same = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.kind == raw && $0.text == text })
            same.fetchLimit = 1
            if let existing = try? context.fetch(same).first {
                existing.copiedAt = now()
                existing.sourceApp = app?.name ?? ""
                existing.sourceBundleID = app?.bundleID ?? ""
                save()
                clipboardLog.notice("moved a \(raw, privacy: .public) clip to the top")
                return
            }
        }
        let item = ClipboardItem(kind: kind, text: clip.text, imageData: clip.image,
                                 sourceApp: app?.name ?? "", sourceBundleID: app?.bundleID ?? "")
        item.copiedAt = now()
        context.insert(item)
        save()
        clipboardLog.notice("kept a \(raw, privacy: .public) clip")
    }

    /// Deletes the clips past their kind's retention. Clipboard history is
    /// meant to forget; this is the retention people chose in Settings.
    @discardableResult
    func purge() -> Int {
        let items = (try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? []
        let now = now()
        let expired = items.filter {
            ClipboardPolicy.isExpired($0.copiedAt, kind: $0.clipKind, retention: settings.retention, now: now)
        }
        expired.forEach(context.delete)
        if !expired.isEmpty {
            save()
            clipboardLog.notice("purged \(expired.count, privacy: .public) expired clips")
        }
        return expired.count
    }

    var items: [ClipboardItem] {
        (try? context.fetch(FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.copiedAt, order: .reverse)]))) ?? []
    }

    private func save() {
        do { try context.save() } catch { clipboardLog.error("saving clips failed: \(String(describing: error), privacy: .public)") }
    }

    /// What macOS does when Reach reads the clipboard: asks, allows or denies (macOS 15.4 and later).
    static var access: NSPasteboard.AccessBehavior { NSPasteboard.general.accessBehavior }
    static let privacySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard")
}
