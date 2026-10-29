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

/// What Return does for a system command: which one, on which disk, and
/// whether a confirmation row comes first.
struct SystemRun: Equatable {
    var command: SystemCommand
    var disk: URL?
    var confirms = false
}

/// System commands by keyword (S-019): `sleep`, `lock`, `restart`, `eject`.
/// They rank among the apps; Eject lists each disk.
final class SystemSource: ResultSource {
    let settings: SystemSettings
    /// The disks Eject offers. The self-test swaps in fakes.
    var disks: () -> [Disk] = { Disk.ejectable() }

    init(settings: SystemSettings = .shared) {
        self.settings = settings
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        let matches = SystemCommands.matches(text, in: settings.commands)
        guard !matches.isEmpty else { return [] }
        let disks = matches.contains { [.eject, .ejectAll].contains($0.setting.command) } ? self.disks() : []
        return matches.flatMap { match -> [Scored] in
            let command = match.setting.command
            switch command {
            case .eject:
                return eject(match, disks: disks)
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
        let words = match.disk ?? ""
        let shown = disks.compactMap { disk -> (Disk, Int)? in
            if words.isEmpty { return (disk, match.score) }
            return Matcher.score(query: words, title: disk.name).map { (disk, match.score + $0 / 10) }
        }
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
        }
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
