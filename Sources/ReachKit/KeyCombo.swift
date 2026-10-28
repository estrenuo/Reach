import Foundation

/// A global hotkey: a virtual key code plus Carbon modifier flags.
public struct KeyCombo: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    // Carbon modifier bits (Events.h), so this library needs no Carbon import.
    public static let command: UInt32 = 1 << 8
    public static let shift: UInt32 = 1 << 9
    public static let option: UInt32 = 1 << 11
    public static let control: UInt32 = 1 << 12
    public static let spaceKey: UInt32 = 49

    /// ⌃⌥Space while Alfred still owns ⌥Space.
    public static let `default` = KeyCombo(keyCode: spaceKey, modifiers: control | option)

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// A hotkey needs at least one of ⌃, ⌥ or ⌘; Shift alone would eat typing.
    public var isValid: Bool { modifiers & (Self.command | Self.option | Self.control) != 0 }

    /// "⌃⌥Space", in the order the menus use.
    public func display(key: String) -> String {
        var text = ""
        if modifiers & Self.control != 0 { text += "⌃" }
        if modifiers & Self.option != 0 { text += "⌥" }
        if modifiers & Self.shift != 0 { text += "⇧" }
        if modifiers & Self.command != 0 { text += "⌘" }
        return text + key
    }

    /// Spoken form for VoiceOver: "Control Option Space".
    public func spoken(key: String) -> String {
        var parts: [String] = []
        if modifiers & Self.control != 0 { parts.append("Control") }
        if modifiers & Self.option != 0 { parts.append("Option") }
        if modifiers & Self.shift != 0 { parts.append("Shift") }
        if modifiers & Self.command != 0 { parts.append("Command") }
        return (parts + [key]).joined(separator: " ")
    }
}
