import Foundation

/// A macOS command run by keyword (S-019): `sleep`, `lock`, `restart`, `eject`.
/// Alfred's set, in the order of its System page. Hide, Quit, Force Quit and
/// Quit All act on running apps (S-020).
public enum SystemCommand: String, CaseIterable, Codable, Sendable {
    case screenSaver, showTrash, emptyTrash, logOut, sleep, sleepDisplays, lock, restart, shutDown
    case volumeUp, volumeDown, mute
    case eject, ejectAll
    case hide, quit, forceQuit, quitAll

    public var title: String {
        switch self {
        case .screenSaver: "Screen Saver"
        case .showTrash: "Show Trash"
        case .emptyTrash: "Empty Trash"
        case .logOut: "Log Out"
        case .sleep: "Sleep"
        case .sleepDisplays: "Sleep Displays"
        case .lock: "Lock Screen"
        case .restart: "Restart"
        case .shutDown: "Shut Down"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .mute: "Toggle Mute"
        case .eject: "Eject"
        case .ejectAll: "Eject All"
        case .hide: "Hide"
        case .quit: "Quit"
        case .forceQuit: "Force Quit"
        case .quitAll: "Quit All"
        }
    }

    public var keyword: String {
        switch self {
        case .screenSaver: "ss"
        case .showTrash: "trash"
        case .emptyTrash: "emptytrash"
        case .logOut: "logout"
        case .sleep: "sleep"
        case .sleepDisplays: "sleepdisplays"
        case .lock: "lock"
        case .restart: "restart"
        case .shutDown: "shutdown"
        case .volumeUp: "volup"
        case .volumeDown: "voldown"
        case .mute: "mute"
        case .eject: "eject"
        case .ejectAll: "ejectall"
        case .hide: "hide"
        case .quit: "quit"
        case .forceQuit: "forcequit"
        case .quitAll: "quitall"
        }
    }

    public var symbol: String {
        switch self {
        case .screenSaver: "sparkles.tv"
        case .showTrash: "trash"
        case .emptyTrash: "trash.slash"
        case .logOut: "rectangle.portrait.and.arrow.right"
        case .sleep: "moon.zzz"
        case .sleepDisplays: "display"
        case .lock: "lock"
        case .restart: "arrow.clockwise"
        case .shutDown: "power"
        case .volumeUp: "speaker.wave.3"
        case .volumeDown: "speaker.wave.1"
        case .mute: "speaker.slash"
        case .eject, .ejectAll: "eject"
        case .hide: "eye.slash"
        case .quit: "xmark.circle"
        case .forceQuit: "exclamationmark.octagon"
        case .quitAll: "xmark.square"
        }
    }

    /// The row's subtitle: what the command does.
    public var help: String {
        switch self {
        case .screenSaver: "Start the screen saver"
        case .showTrash: "Open the Trash in Finder"
        case .emptyTrash: "Delete the items in the Trash for good"
        case .logOut: "Quit every app and log out"
        case .sleep: "Put your Mac to sleep"
        case .sleepDisplays: "Turn off the displays"
        case .lock: "Lock your Mac and show the login window"
        case .restart: "Quit every app and restart your Mac"
        case .shutDown: "Quit every app and shut down your Mac"
        case .volumeUp: "Turn the sound up"
        case .volumeDown: "Turn the sound down"
        case .mute: "Mute or unmute the sound"
        case .eject: "Eject a disk"
        case .ejectAll: "Eject every disk"
        case .hide: "Hide a running app"
        case .quit: "Quit a running app"
        case .forceQuit: "Force a running app to quit; unsaved changes are lost"
        case .quitAll: "Quit every app but Finder"
        }
    }

    /// The commands that can ask first, as in Alfred: the ones that end what you were doing.
    public var canConfirm: Bool {
        switch self {
        case .emptyTrash, .logOut, .sleep, .sleepDisplays, .lock, .restart, .shutDown, .ejectAll,
             .forceQuit, .quitAll: true
        default: false
        }
    }

    /// The ones that cannot be undone ask first until people change it.
    public var confirmsAtFirst: Bool {
        [.emptyTrash, .logOut, .restart, .shutDown, .forceQuit, .quitAll].contains(self)
    }

    /// The confirmation row's title; `target` names the app for Force Quit.
    public func question(_ target: String? = nil) -> String {
        switch self {
        case .forceQuit: "Force “\(target ?? "the app")” to quit?"
        case .quitAll: "Quit every app but Finder?"
        case .emptyTrash: "Empty the Trash?"
        case .logOut: "Log out now?"
        case .sleep: "Put your Mac to sleep?"
        case .sleepDisplays: "Turn off the displays?"
        case .lock: "Lock your Mac?"
        case .restart: "Restart your Mac?"
        case .shutDown: "Shut down your Mac?"
        case .ejectAll: "Eject every disk?"
        default: "\(title)?"
        }
    }

    /// The confirmation row's subtitle, with the verb Return does.
    public var confirmHelp: String {
        let verb: String = switch self {
        case .emptyTrash: "empties it"
        case .logOut: "logs out"
        case .sleep, .sleepDisplays: "sleeps"
        case .lock: "locks"
        case .restart: "restarts"
        case .shutDown: "shuts down"
        case .ejectAll: "ejects"
        case .forceQuit: "force quits"
        case .quitAll: "quits them"
        default: "runs it"
        }
        return "↩ \(verb), esc cancels"
    }

    /// Eject lists each disk; Hide, Quit and Force Quit each running app.
    /// The words after the keyword pick one. The rest are one row.
    public var takesTarget: Bool { [.eject, .hide, .quit, .forceQuit].contains(self) }
}

/// One command's settings: on or off, its keyword, and whether it asks first.
public struct SystemCommandSetting: Codable, Equatable, Sendable, Identifiable {
    public var command: SystemCommand
    public var isOn: Bool
    public var keyword: String
    public var confirms: Bool

    public var id: SystemCommand { command }

    public init(command: SystemCommand, isOn: Bool = true, keyword: String? = nil, confirms: Bool? = nil) {
        self.command = command
        self.isOn = isOn
        self.keyword = keyword ?? command.keyword
        self.confirms = command.canConfirm && (confirms ?? command.confirmsAtFirst)
    }

    /// Every command as Reach starts: all on, the four that cannot be undone ask first.
    public static let standard = SystemCommand.allCases.map { SystemCommandSetting(command: $0) }
}

public enum SystemCommands {
    public struct Match: Equatable, Sendable {
        public var setting: SystemCommandSetting
        /// On the `Matcher` scale, so commands rank among apps.
        public var score: Int
        /// The words after the keyword, which pick the disk or app. Nil without them.
        public var target: String?
    }

    /// Matches weaker than a word start (`Matcher` 400) are left out.
    public static let minimumScore = 400

    /// The commands `query` names, best first. A command matches on its
    /// keyword or its title, so `sleep` finds Sleep and Sleep Displays.
    /// `eject us` and `quit saf` (keyword, space, words) pick a disk or an app.
    public static func matches(_ query: String, in settings: [SystemCommandSetting]) -> [Match] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return [] }
        return settings.compactMap { setting -> Match? in
            let keyword = setting.keyword.trimmingCharacters(in: .whitespaces).lowercased()
            guard setting.isOn, !keyword.isEmpty else { return nil }
            if setting.command.takesTarget, query.lowercased().hasPrefix(keyword + " ") {
                let words = query.dropFirst(keyword.count + 1).trimmingCharacters(in: .whitespaces)
                return Match(setting: setting, score: 2000, target: words)
            }
            let score = [Matcher.score(query: text, title: keyword),
                         Matcher.score(query: text, title: setting.command.title)].compactMap { $0 }.max()
            // Letters somewhere inside a word are too loose for commands that end your session.
            guard let score, score >= minimumScore else { return nil }
            return Match(setting: setting, score: score)
        }
        .sorted { $0.score > $1.score }
    }

    /// The items whose name matches `words`, best first, with a bonus of up to
    /// 100 on the command's score. Empty words keep every item, in its order.
    public static func pick<Item>(_ words: String, from items: [Item], name: (Item) -> String) -> [(item: Item, bonus: Int)] {
        let text = words.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return items.map { ($0, 0) } }
        return items.enumerated()
            .compactMap { offset, item in Matcher.score(query: text, title: name(item)).map { (offset, item, $0 / 10) } }
            .sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }
            .map { ($0.1, $0.2) }
    }

    /// Two commands, or a command and a file search keyword, cannot share a
    /// keyword. Returns why `keyword` will not do, or nil when it will.
    public static func problem(keyword: String, for command: SystemCommand,
                               in settings: [SystemCommandSetting], taken: [String: String] = [:]) -> String? {
        let word = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        if word.isEmpty { return "Type a keyword." }
        if word.contains(where: \.isWhitespace) { return "A keyword is one word, without spaces." }
        if let other = settings.first(where: { $0.command != command && $0.keyword.lowercased() == word }) {
            return "“\(keyword)” is already the keyword for \(other.command.title)."
        }
        if let other = taken[word] { return "“\(keyword)” is already the keyword for \(other)." }
        return nil
    }
}
