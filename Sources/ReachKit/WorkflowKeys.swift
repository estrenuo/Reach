import Foundation

/// Alfred's Dispatch Key Combo output (S-053): a key with modifiers, pressed
/// `count` times in the app in front.
public struct WorkflowKeys: Equatable, Sendable {
    /// The virtual key code (US layout positions).
    public var keyCode: Int
    /// AppKit modifier bits, as Alfred's `keymod` holds them: ⌘ 1 << 20, ⌥ 1 << 19, ⌃ 1 << 18, ⇧ 1 << 17.
    public var modifiers: Int
    public var count: Int

    public init(keyCode: Int, modifiers: Int = 0, count: Int = 1) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.count = count
    }

    /// The keys for `object`: `keycode`, or the key for `keychar` when it is -1.
    /// A failure names what Reach does not press, like `overridewithargument`.
    public static func read(_ object: WorkflowObject) -> Result<WorkflowKeys, WorkflowReplace.Problem> {
        if object.bool("overridewithargument") {
            return .failure(.init(kind: "output.dispatchkeycombo with the argument as the keys"))
        }
        let char = object.string("keychar").lowercased()
        let code = object.int("keycode", default: -1)
        guard let key = code >= 0 ? code : keyCodes[char] else {
            return .failure(.init(kind: "output.dispatchkeycombo for the key “\(char)”"))
        }
        return .success(WorkflowKeys(keyCode: key, modifiers: object.int("keymod"), count: max(1, object.int("count", default: 1))))
    }

    /// Characters to virtual key codes on a US keyboard, as Alfred's `keychar` names them.
    static let keyCodes: [String: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
        "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27,
        "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41,
        "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, " ": 49, "`": 50,
    ]
}
