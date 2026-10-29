import Foundation

/// The Reach Settings row (S-035): typing the start of "settings",
/// "preferences" or "reach" offers it, so Settings stays reachable
/// without the menu bar icon.
public enum SettingsKeyword {
    public static let words = ["settings", "preferences", "reach settings", "reach"]

    /// True for at least three letters that start one of `words`, or all of "reach settings".
    public static func matches(_ text: String) -> Bool {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard query.count >= 3 else { return false }
        return words.contains { $0.hasPrefix(query) }
    }
}
