import Foundation

/// The buffer (S-013): files, folders and apps collected with ⌥↑, in the
/// order they were added, to run one action on all of them with ⌥→.
/// Times are seconds, as in the system uptime, so tests can pass their own.
public struct FileBuffer: Equatable, Sendable {
    public private(set) var items: [URL] = []
    /// When the buffer was last changed or used.
    private var usedAt: TimeInterval = 0

    public init() {}

    public var isEmpty: Bool { items.isEmpty }

    /// ⌥↑: adds the item, or takes it out when it is already in.
    public mutating func toggle(_ url: URL, at time: TimeInterval) {
        if let index = items.firstIndex(of: url) { items.remove(at: index) } else { items.append(url) }
        usedAt = time
    }

    /// ⌥↓: adds the item; one already in stays where it is.
    public mutating func add(_ url: URL, at time: TimeInterval) {
        if !items.contains(url) { items.append(url) }
        usedAt = time
    }

    /// ⌥←: takes out the item added last. False when the buffer is empty.
    @discardableResult
    public mutating func removeLast(at time: TimeInterval) -> Bool {
        guard !items.isEmpty else { return false }
        items.removeLast()
        usedAt = time
        return true
    }

    /// ⌥⌫, and after an action on the buffer.
    public mutating func clear() {
        items = []
    }

    /// ⌥→ counts as use, so the buffer does not empty while its panel is open.
    public mutating func touch(at time: TimeInterval) {
        usedAt = time
    }

    /// True when the buffer has items and nobody used it for `FileBuffer.idle` seconds.
    public func isStale(at time: TimeInterval) -> Bool {
        !items.isEmpty && time - usedAt > Self.idle
    }

    /// Five minutes, as in Alfred.
    public static let idle: TimeInterval = 5 * 60
}
