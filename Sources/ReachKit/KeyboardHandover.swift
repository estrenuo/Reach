import Foundation

/// Whether the launcher takes the keyboard back after losing it, while
/// Quick Look opens or closes (S-012). Quick Look makes itself key when it
/// opens, and AppKit hands the key window on again when it closes. With
/// another app in front the key window reads nil by then, so a short grace
/// after each move is the only way to tell Quick Look from a click elsewhere.
/// Times are seconds, as in the system uptime.
public struct KeyboardHandover: Sendable {
    private var movedAt = -TimeInterval.infinity

    public init() {}

    /// Quick Look opened or closed.
    public mutating func moved(at time: TimeInterval) {
        movedAt = time
    }

    /// The launcher lost the keyboard. True when it should take it back:
    /// Quick Look is key and still showing a file, or it moved within the grace.
    public func launcherKeepsKey(quickLookIsKey: Bool, showing: Bool, at time: TimeInterval) -> Bool {
        quickLookIsKey ? showing : time - movedAt < Self.grace
    }

    /// How long after Quick Look moved a lost keyboard still counts as its doing.
    static let grace: TimeInterval = 1
}
