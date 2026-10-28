import Foundation

/// Tells a tap on ⇧ apart from ⇧ held to type a capital (S-012).
/// The launcher feeds it every key and modifier change; times are seconds,
/// as in NSEvent.timestamp.
public struct ShiftTap: Sendable {
    /// When ⇧ went down, while nothing else was held. Nil after any other key.
    private var pressedAt: TimeInterval?
    /// When the last other key was typed.
    private var typedAt: TimeInterval?

    public init() {}

    /// ⇧ went down on its own.
    public mutating func pressed(at time: TimeInterval) {
        pressedAt = time
    }

    /// Another key was typed: a ⇧ held right now is for a capital, not a tap.
    public mutating func typed(at time: TimeInterval) {
        pressedAt = nil
        typedAt = time
    }

    /// Another modifier joined in, like ⇧⌘: not a tap.
    public mutating func interrupted() {
        pressedAt = nil
    }

    /// ⇧ came up. True when this press counts as a tap that opens or closes Quick Look.
    public mutating func released(at time: TimeInterval) -> Bool {
        defer { pressedAt = nil }
        guard let pressedAt else { return false }
        // Held longer: someone meant a capital and changed their mind.
        guard time - pressedAt <= Self.maxHold else { return false }
        // Pressed right after a letter: a fast typist reaching for ⇧, not a tap.
        if let typedAt, pressedAt - typedAt < Self.typingPause { return false }
        return true
    }

    /// The longest ⇧ can be held and still count as a tap.
    static let maxHold: TimeInterval = 0.4
    /// How long after the last typed key a tap starts to count.
    static let typingPause: TimeInterval = 0.25
}
