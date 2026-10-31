import Foundation

/// Alfred's Replace utility (S-051): rewrites the argument with a text or a
/// regular expression.
public enum WorkflowReplace {
    /// `text` with `object`'s `matchstring` replaced by `replacestring`: plain
    /// text for `matchmode` 0, a regular expression with `$1` groups for 1,
    /// with `regexcaseinsensitive` and `regexmultiline`. A failure for another mode
    /// or an expression that does not compile, with why.
    public static func apply(to text: String, _ object: WorkflowObject) -> Result<String, WorkflowProblem> {
        let match = object.string("matchstring")
        let replacement = object.string("replacestring")
        switch object.int("matchmode") {
        case 0:
            return .success(match.isEmpty ? text : text.replacingOccurrences(of: match, with: replacement))
        case 1:
            var options: NSRegularExpression.Options = []
            if object.bool("regexcaseinsensitive") { options.insert(.caseInsensitive) }
            if object.bool("regexmultiline") { options.insert(.anchorsMatchLines) }
            guard let regex = try? NSRegularExpression(pattern: match, options: options) else {
                return .failure(WorkflowProblem(kind: "utility.replace with the expression \(match), which does not compile"))
            }
            return .success(regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text),
                                                           withTemplate: replacement))
        case let mode:
            return .failure(WorkflowProblem(kind: "utility.replace match mode \(mode)"))
        }
    }
}

/// Why Reach did not run an object, for the debugger: the object and the option it does not follow.
public struct WorkflowProblem: Error, Equatable, Sendable {
    public var kind: String

    public init(kind: String) {
        self.kind = kind
    }
}
