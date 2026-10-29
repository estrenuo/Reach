import Foundation

/// Appending to the last clip (S-028): hold ⌘ and press C twice, and what
/// was just copied is added to the clip before it. Plain values only.
public enum ClipboardMerge {
    public enum Separator: String, CaseIterable, Codable, Sendable {
        case space, newline, blankLine, none

        public var title: String {
            switch self {
            case .space: "Separate with a Space"
            case .newline: "Separate with a New Line"
            case .blankLine: "Separate with a Blank Line"
            case .none: "No Separator"
            }
        }

        public var text: String {
            switch self {
            case .space: " "
            case .newline: "\n"
            case .blankLine: "\n\n"
            case .none: ""
            }
        }
    }

    /// The system sound played after an append, as in Alfred.
    public static let soundName = "Purr"

    public static func merged(_ previous: String, _ appended: String, separator: Separator) -> String {
        previous + separator.text + appended
    }

    /// The sound to play after an append, or nil when Play a Sound is off.
    public static func sound(enabled: Bool) -> String? { enabled ? soundName : nil }

    /// Sees ⌘C twice while ⌘ stays down, within `window` seconds.
    public struct DoubleTap: Sendable {
        public static let window: TimeInterval = 0.5
        private var last: TimeInterval?

        public init() {}

        /// ⌘C was pressed at `time`. True on the second press; a third starts over.
        public mutating func pressed(at time: TimeInterval) -> Bool {
            if let last, time - last <= Self.window {
                self.last = nil
                return true
            }
            last = time
            return false
        }

        /// ⌘ went up: the next ⌘C is a first press again.
        public mutating func released() { last = nil }
    }
}
