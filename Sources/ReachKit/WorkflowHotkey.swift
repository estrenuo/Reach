import Foundation

/// A workflow's Hotkey trigger (S-049): a global key combination that runs the
/// objects connected to it. Alfred keeps the combination out of an exported
/// workflow, so Reach mostly gets it from the person, in Hotkeys…; `combo` is
/// only set when the info.plist has Alfred's `hotkey` and `hotmod`.
public struct WorkflowHotkey: Equatable, Sendable, Identifiable {
    public static let type = "alfred.workflow.trigger.hotkey"

    /// What the hotkey passes on as `{query}`. Alfred's numbers: 0 none,
    /// 1 the macOS selection, 2 the clipboard, 3 a fixed text; the others,
    /// like 4 (the Find pasteboard), Reach does not pass.
    public enum Argument: Equatable, Sendable {
        case none
        case selection
        case clipboard
        case text(String)
        case other(Int)
    }

    public var uid: String
    public var argument: Argument
    /// Alfred's "Show Alfred" action: the launcher opens with the argument typed.
    public var showsLauncher: Bool
    /// Bundle IDs of the apps in "related apps", with Alfred's mode: 0 always,
    /// 1 only when one of them is in front, 2 only when none of them is.
    public var apps: [String]
    public var appsMode: Int
    public var combo: KeyCombo?
    /// Alfred's own name for the combination, like "⌥⌘S".
    public var keyName: String
    public var id: String { uid }

    public init(uid: String, argument: Argument = .none, showsLauncher: Bool = false, apps: [String] = [],
                appsMode: Int = 0, combo: KeyCombo? = nil, keyName: String = "") {
        self.uid = uid
        self.argument = argument
        self.showsLauncher = showsLauncher
        self.apps = apps
        self.appsMode = appsMode
        self.combo = combo
        self.keyName = keyName
    }

    public init?(_ object: WorkflowObject) {
        guard object.type == Self.type else { return nil }
        let argument: Argument = switch object.int("argument") {
        case 0: .none
        case 1: .selection
        case 2: .clipboard
        case 3: .text(object.string("argumenttext"))
        case let other: .other(other)
        }
        let key = object.config["hotkey"]?.int ?? 0
        let flags = object.config["hotmod"]?.int ?? 0
        let combo = flags == 0 ? nil : KeyCombo(keyCode: UInt32(key), modifiers: Self.carbon(flags))
        self.init(uid: object.uid, argument: argument, showsLauncher: object.int("action") == 1,
                  apps: (object.config["relatedApps"]?.array ?? []).compactMap(\.string),
                  appsMode: object.int("relatedAppsMode"), combo: combo?.isValid == true ? combo : nil,
                  keyName: object.string("hotstring"))
    }

    /// Whether the hotkey works with `frontApp` in front, by its related apps.
    public func isActive(frontApp: String?) -> Bool {
        let related = frontApp.map(apps.contains) ?? false
        return switch appsMode {
        case 1: related
        case 2: !related
        default: true
        }
    }

    /// The text the hotkey passes on, and the kind of argument Reach does not
    /// pass, which then runs without one.
    public func text(selection: String?, clipboard: String?) -> (text: String, unsupported: String?) {
        switch argument {
        case .none: ("", nil)
        case .selection: (selection ?? "", nil)
        case .clipboard: (clipboard ?? "", nil)
        case .text(let text): (text, nil)
        case .other(let number): ("", number == 4 ? "the Find pasteboard" : "argument type \(number)")
        }
    }

    /// Carbon modifier bits from Alfred's `hotmod`, which holds AppKit's.
    static func carbon(_ flags: Int) -> UInt32 {
        var bits: UInt32 = 0
        if flags & (1 << 20) != 0 { bits |= KeyCombo.command }
        if flags & (1 << 19) != 0 { bits |= KeyCombo.option }
        if flags & (1 << 18) != 0 { bits |= KeyCombo.control }
        if flags & (1 << 17) != 0 { bits |= KeyCombo.shift }
        return bits
    }
}

extension Workflow {
    /// The Hotkey triggers, in the order of the info.plist.
    public var hotkeys: [WorkflowHotkey] { objects.compactMap(WorkflowHotkey.init) }

    /// What a hotkey does, for Hotkeys…: the note on its card, else the title
    /// or keyword of what it is connected to.
    public func label(forHotkey uid: String) -> String {
        if let note = notes[uid], !note.isEmpty { return note }
        for line in connections[uid] ?? [] {
            guard let object = object(line.to) else { continue }
            for key in ["title", "keyword", "text"] where !object.string(key).isEmpty && !object.string(key).contains("{var:") {
                return object.string(key)
            }
        }
        return "Hotkey"
    }
}

/// Which workflow hotkeys Reach registers (S-049): never one that is Reach's
/// own or that another workflow's hotkey took first.
public enum WorkflowHotkeyPlan {
    public struct Entry: Equatable, Sendable {
        public var workflow: String
        public var uid: String
        public var combo: KeyCombo

        public init(workflow: String, uid: String, combo: KeyCombo) {
            self.workflow = workflow
            self.uid = uid
            self.combo = combo
        }
    }

    /// `wanted` in order; `reserved` are Reach's own hotkeys by what they do.
    public static func plan(_ wanted: [Entry], reserved: [(name: String, combo: KeyCombo)])
        -> (use: [Entry], skipped: [(entry: Entry, reason: String)]) {
        var use: [Entry] = []
        var skipped: [(entry: Entry, reason: String)] = []
        for entry in wanted {
            if let own = reserved.first(where: { $0.combo == entry.combo }) {
                skipped.append((entry, "it is Reach's \(own.name)"))
            } else if let first = use.first(where: { $0.combo == entry.combo }) {
                skipped.append((entry, first.workflow == entry.workflow ? "another hotkey in this workflow has it"
                                                                          : "the workflow “\(first.workflow)” has it"))
            } else {
                use.append(entry)
            }
        }
        return (use, skipped)
    }
}
