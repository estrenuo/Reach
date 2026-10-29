import AppKit
import os
import ReachKit

let systemLog = Logger(subsystem: "com.sanderrobijns.reach", category: "system")

/// The settings of the system commands (S-019), saved as one list.
@Observable
final class SystemSettings {
    static let shared = SystemSettings()
    private static let key = "system.commands"

    var commands: [SystemCommandSetting] {
        didSet { Store.settings.set(try? JSONEncoder().encode(commands), forKey: Self.key) }
    }

    private init() {
        let saved = Store.settings.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([SystemCommandSetting].self, from: $0) } ?? []
        // Commands added in a later version join with their first settings.
        commands = SystemCommandSetting.standard.map { standard in
            saved.first { $0.command == standard.command } ?? standard
        }
    }

    subscript(command: SystemCommand) -> SystemCommandSetting {
        get { commands.first { $0.command == command } ?? SystemCommandSetting(command: command) }
        set {
            guard let index = commands.firstIndex(where: { $0.command == command }) else { return }
            commands[index] = newValue
        }
    }

    /// Back to the commands Reach starts with; the self-test leaves no trace this way.
    func reset() {
        commands = SystemCommandSetting.standard
    }
}

/// A disk Eject can offer: a mounted volume that is not the startup disk.
struct Disk: Equatable {
    var name: String
    var url: URL

    /// Removable drives, disk images and network volumes under /Volumes.
    /// Time Machine snapshots and hidden volumes stay out.
    static func ejectable() -> [Disk] {
        let keys: [URLResourceKey] = [.volumeLocalizedNameKey, .volumeIsRootFileSystemKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.volumeIsRootFileSystem != true, url.path.hasPrefix("/Volumes/"),
                  !url.path.contains("com.apple.TimeMachine"), !url.path.hasSuffix(".backup") else { return nil }
            return Disk(name: values?.volumeLocalizedName ?? url.lastPathComponent, url: url)
        }
    }
}

/// A running app that Hide, Quit and Force Quit can offer (S-020).
struct RunningApp: Equatable {
    var name: String
    var pid: pid_t
    /// The app bundle, for its icon. Nil for an app without one.
    var path: String?

    static let finder = "com.apple.finder"

    /// Apps with a Dock icon, last used first. Reach itself stays out.
    @MainActor static func current(recency: AppRecency = .shared) -> [RunningApp] {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated
        }
        return recency.sorted(apps).map {
            RunningApp(name: $0.localizedName ?? $0.bundleURL?.deletingPathExtension().lastPathComponent ?? "App",
                       pid: $0.processIdentifier, path: $0.bundleURL?.path)
        }
    }
}

/// The order apps were last used in, from activation notifications, so
/// `quit` lists the app you just left first.
@MainActor final class AppRecency {
    static let shared = AppRecency()
    private var order: [pid_t] = []
    private var observer: NSObjectProtocol?

    private init() {
        if let front = NSWorkspace.shared.frontmostApplication { order = [front.processIdentifier] }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let pid = app?.processIdentifier else { return }
            MainActor.assumeIsolated { AppRecency.shared.used(pid) }
        }
    }

    func used(_ pid: pid_t) {
        order.removeAll { $0 == pid }
        order.insert(pid, at: 0)
    }

    /// Apps used since launch first, newest first; the rest keep macOS's order.
    func sorted(_ apps: [NSRunningApplication]) -> [NSRunningApplication] {
        apps.enumerated().sorted { a, b in
            let ia = order.firstIndex(of: a.element.processIdentifier) ?? Int.max
            let ib = order.firstIndex(of: b.element.processIdentifier) ?? Int.max
            return ia != ib ? ia < ib : a.offset < b.offset
        }.map(\.element)
    }
}

/// What Return does for a system command: which one, on which disk or app,
/// and whether a confirmation row comes first.
struct SystemRun: Equatable {
    var command: SystemCommand
    var disk: URL?
    var app: pid_t?
    /// The disk or app name, for the confirmation row.
    var target: String?
    var confirms = false
}

/// System commands by keyword (S-019): `sleep`, `lock`, `restart`, `eject`.
/// They rank among the apps; Eject lists each disk.
final class SystemSource: ResultSource {
    let settings: SystemSettings
    /// The disks Eject offers. The self-test swaps in fakes.
    var disks: () -> [Disk] = { Disk.ejectable() }
    /// The apps Hide, Quit and Force Quit offer. The self-test swaps in fakes.
    var running: @MainActor () -> [RunningApp] = { RunningApp.current() }

    init(settings: SystemSettings = .shared) {
        self.settings = settings
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        let matches = SystemCommands.matches(text, in: settings.commands)
        guard !matches.isEmpty else { return [] }
        let disks = matches.contains { [.eject, .ejectAll].contains($0.setting.command) } ? self.disks() : []
        let running = matches.contains { $0.setting.command.takesTarget && $0.setting.command != .eject } ? self.running() : []
        return matches.flatMap { match -> [Scored] in
            let command = match.setting.command
            switch command {
            case .eject:
                return eject(match, disks: disks)
            case .hide, .quit, .forceQuit:
                return apps(match, running: running)
            case .ejectAll where disks.isEmpty:
                return []
            default:
                return [Scored(result: row(command, confirms: match.setting.confirms), score: match.score)]
            }
        }
    }

    private func row(_ command: SystemCommand, confirms: Bool) -> LaunchResult {
        LaunchResult(id: "system:\(command.rawValue)", title: command.title, subtitle: command.help,
                     icon: .symbol(command.symbol), url: nil, kindLabel: "System command",
                     system: SystemRun(command: command, confirms: confirms))
    }

    /// One row per disk whose name matches the words after `eject`; a hint when there are none.
    private func eject(_ match: SystemCommands.Match, disks: [Disk]) -> [Scored] {
        let words = match.target ?? ""
        let shown = SystemCommands.pick(words, from: disks, name: \.name).map { ($0.item, match.score + $0.bonus) }
        guard !shown.isEmpty else {
            // Only once the keyword is typed in full: "ej" should not say there are no disks.
            guard match.score >= 1000 else { return [] }
            let title = disks.isEmpty ? Self.noDisks : "No disks match “\(words)”"
            return [Scored(result: LaunchResult(id: "hint:eject", title: title, subtitle: "",
                                                icon: .symbol("eject"), url: nil), score: 0)]
        }
        return shown.map { disk, score in
            Scored(result: LaunchResult(id: "system:eject:\(disk.url.path)", title: "Eject “\(disk.name)”",
                                        subtitle: SystemCommand.eject.help, icon: .file(disk.url.path), url: nil,
                                        kindLabel: "System command", system: SystemRun(command: .eject, disk: disk.url)),
                   score: score)
        }
    }

    /// `quit` and `quit saf`: one row per running app that matches. Part of
    /// the keyword (`qui`) offers the command; Return completes it to `quit `.
    private func apps(_ match: SystemCommands.Match, running: [RunningApp]) -> [Scored] {
        let setting = match.setting
        let command = setting.command
        guard match.target != nil || match.score >= 1000 else {
            return [Scored(result: LaunchResult(id: "system:\(command.rawValue)", title: "\(command.title)…",
                                                subtitle: "Press ↩ to pick a running app", icon: .symbol(command.symbol),
                                                url: nil, kindLabel: "System command", completes: setting.keyword + " "),
                           score: match.score)]
        }
        let words = match.target ?? ""
        let shown = SystemCommands.pick(words, from: running, name: \.name)
        guard !shown.isEmpty else {
            let title = words.isEmpty ? "No apps are running" : "No running app matches “\(words)”"
            return [Scored(result: LaunchResult(id: "hint:\(command.rawValue)", title: title, subtitle: "",
                                                icon: .symbol(command.symbol), url: nil), score: 0)]
        }
        return shown.map { app, bonus in
            let run = SystemRun(command: command, app: app.pid, target: app.name, confirms: setting.confirms)
            return Scored(result: LaunchResult(id: "system:\(command.rawValue):\(app.name)", title: "\(command.title) \(app.name)",
                                               subtitle: command.help, icon: app.path.map { .file($0) } ?? .symbol(command.symbol),
                                               url: nil, kindLabel: "System command", system: run),
                          score: match.score + bonus)
        }
    }

    static let noDisks = "No disks to eject"
}

/// Runs a system command. Every command but Eject asks macOS to do it, so
/// it works without extra permissions where it can: pmset for sleep, the
/// login framework for lock, Apple Events for log out, restart and shut down.
enum SystemRunner {
    static func run(_ run: SystemRun) -> Bool {
        systemLog.notice("run \(run.command.rawValue, privacy: .public)")
        switch run.command {
        case .screenSaver:
            return NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
        case .showTrash:
            guard let trash = try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return false }
            return NSWorkspace.shared.open(trash)
        case .emptyTrash:
            return script("tell application \"Finder\" to empty trash")
        case .logOut:
            return script("tell application \"loginwindow\" to «event aevtrlgo»")
        case .restart:
            return script("tell application \"loginwindow\" to «event aevtrrst»")
        case .shutDown:
            return script("tell application \"loginwindow\" to «event aevtrsdn»")
        case .sleep:
            return pmset("sleepnow")
        case .sleepDisplays:
            return pmset("displaysleepnow")
        case .lock:
            return lock()
        case .volumeUp:
            return script("set volume output volume ((output volume of (get volume settings)) + 7)")
        case .volumeDown:
            return script("set volume output volume ((output volume of (get volume settings)) - 7)")
        case .mute:
            return script("set volume output muted (not (output muted of (get volume settings)))")
        case .eject:
            guard let disk = run.disk else { return false }
            return eject(disk)
        case .ejectAll:
            let results = Disk.ejectable().map { eject($0.url) }
            return !results.contains(false)
        case .hide:
            return app(run)?.hide() ?? false
        case .quit:
            return app(run)?.terminate() ?? false
        case .forceQuit:
            return app(run)?.forceTerminate() ?? false
        case .quitAll:
            // Apps with unsaved work ask for themselves; Finder and Reach stay.
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular
                && app.bundleIdentifier != RunningApp.finder && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.terminate()
            }
            return true
        }
    }

    private static func app(_ run: SystemRun) -> NSRunningApplication? {
        run.app.flatMap { NSRunningApplication(processIdentifier: $0) }
    }

    private static func script(_ source: String) -> Bool {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { systemLog.error("script failed: \(error[NSAppleScript.errorNumber] as? Int ?? 0, privacy: .public)") }
        return error == nil
    }

    private static func pmset(_ argument: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = [argument]
        return (try? process.run()) != nil
    }

    /// The login framework's lock call, as the menu bar's Lock Screen uses.
    private static func lock() -> Bool {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_NOW),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else { return false }
        typealias Lock = @convention(c) () -> Int32
        _ = unsafeBitCast(symbol, to: Lock.self)()
        return true
    }

    private static func eject(_ disk: URL) -> Bool {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: disk)
            return true
        } catch {
            return false
        }
    }
}
