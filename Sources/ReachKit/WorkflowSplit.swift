import Foundation

/// Alfred's Split Arguments utility (S-051): cuts the argument on a delimiter.
public enum WorkflowSplit {
    /// The parts of `text`, cut on `object`'s `delimiter`, trimmed when
    /// `trimarguments` is on and without empty ones when `discardemptyarguments` is.
    public static func parts(of text: String, _ object: WorkflowObject) -> [String] {
        let delimiter = object.string("delimiter")
        var parts = delimiter.isEmpty ? [text] : text.components(separatedBy: delimiter)
        if object.bool("trimarguments") { parts = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
        if object.bool("discardemptyarguments") { parts = parts.filter { !$0.isEmpty } }
        return parts
    }

    /// For `outputas` 0: the parts as variables, `split1`, `split2`, … by
    /// `variableprefix`.
    public static func variables(_ parts: [String], _ object: WorkflowObject) -> [String: String] {
        let prefix = object.string("variableprefix").isEmpty ? "split" : object.string("variableprefix")
        return Dictionary(uniqueKeysWithValues: parts.enumerated().map { ("\(prefix)\($0.offset + 1)", $0.element) })
    }
}
