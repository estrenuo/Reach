import Foundation

/// Where a workflow run is: what the next objects get. One value, so a case
/// that changes the argument or sets variables says only that.
struct WorkflowFlow {
    var argument: String
    var variables: [String: String]
    var environment: [String: String]
    /// Overrides the next objects' configuration (JSON Config, S-052). It
    /// reaches only the objects right after the one that set it.
    var config: [String: PlistValue] = [:]
    /// How many objects the run has followed, so a loop of triggers ends.
    var depth = 0

    /// The same run with another argument.
    func with(argument: String) -> Self {
        var flow = self
        flow.argument = argument
        return flow
    }

    /// The same run with `values` set as variables and in the environment.
    func setting(_ values: [String: String]) -> Self {
        var flow = self
        flow.variables.merge(values) { _, new in new }
        flow.environment.merge(values) { _, new in new }
        return flow
    }

    /// `text` with `{query}` and `{var:…}` filled in from this run.
    func fill(_ text: String) -> String {
        WorkflowText.fill(text, query: argument, variables: variables)
    }
}
