import Foundation

/// Alfred's JSON Config utility (S-052): its JSON, with `{query}` and
/// `{var:…}` filled in, sets the argument, variables, and the configuration
/// of the objects right after it:
/// `{"alfredworkflow": {"arg": …, "variables": {…}, "config": {…}}}`.
public enum WorkflowJSON {
    public struct Output: Equatable, Sendable {
        /// The new argument; nil keeps the one that came in.
        public var argument: String?
        public var variables: [String: String]
        /// Overrides for the next objects' configuration.
        public var config: [String: PlistValue]
    }

    /// Nil when the JSON does not parse or has no `alfredworkflow` object.
    public static func read(_ object: WorkflowObject, query: String, variables: [String: String]) -> Output? {
        // Values are escaped, so a quote in the text keeps the JSON whole.
        let text = WorkflowText.fill(object.string("json"), query: escaped(query), variables: variables.mapValues(escaped))
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let workflow = root["alfredworkflow"] as? [String: Any] else { return nil }
        let argument: String? = switch workflow["arg"] {
        case let parts as [Any]: parts.compactMap { PlistValue($0)?.string }.joined(separator: "\t")
        case let value?: PlistValue(value)?.string
        case nil: nil
        }
        let set = (workflow["variables"] as? [String: Any] ?? [:]).compactMapValues { PlistValue($0)?.string }
        let config = (workflow["config"] as? [String: Any] ?? [:]).compactMapValues(PlistValue.init)
        return Output(argument: argument, variables: set, config: config)
    }

    /// `text` as it goes inside a JSON string.
    static func escaped(_ text: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [text], options: [.fragmentsAllowed]),
              let array = String(data: data, encoding: .utf8) else { return text }
        // ["…"] without the brackets and quotes.
        return String(array.dropFirst(2).dropLast(2))
    }
}
