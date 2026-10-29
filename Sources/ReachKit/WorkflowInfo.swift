import Foundation

/// One environment variable of a workflow (S-046). Scripts get it by name;
/// "Don't Export" keeps its value out of a shared copy, such as an API key.
public struct WorkflowVariable: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var value: String
    public var dontExport: Bool

    public init(name: String, value: String, dontExport: Bool = false) {
        self.name = name
        self.value = value
        self.dontExport = dontExport
    }
}

/// The parts of a workflow Workflow Info… edits: its About text, version,
/// README and variables. Saved to info.plist under Alfred's keys.
public struct WorkflowInfo: Equatable, Sendable {
    public var name: String
    public var author: String
    public var version: String
    public var bundleID: String
    public var webAddress: String
    public var description: String
    public var readme: String
    public var variables: [WorkflowVariable]

    public init(_ workflow: Workflow) {
        name = workflow.name
        author = workflow.author
        version = workflow.version
        bundleID = workflow.bundleID
        webAddress = workflow.webAddress
        description = workflow.description
        readme = workflow.readme
        let hidden = Set(workflow.dontExport)
        variables = workflow.variables.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map {
            WorkflowVariable(name: $0, value: workflow.variables[$0] ?? "", dontExport: hidden.contains($0))
        }
    }

    /// Variable names may not have spaces or start with a digit, as in a shell.
    public static func isValidName(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first, !CharacterSet.decimalDigits.contains(first) else { return false }
        return name.unicodeScalars.allSatisfy { $0 == "_" || CharacterSet.alphanumerics.contains($0) && $0.isASCII }
    }

    /// The names that appear more than once or are not valid; Save waits until there are none.
    public var problems: [String] {
        var seen: Set<String> = []
        var problems: [String] = []
        for variable in variables {
            let name = variable.name.trimmingCharacters(in: .whitespaces)
            if name.isEmpty { continue }
            if !Self.isValidName(name) {
                problems.append("“\(name)” is not a valid variable name: use letters, digits and _.")
            } else if !seen.insert(name).inserted {
                problems.append("“\(name)” is used twice.")
            }
        }
        return problems
    }

    /// Writes the fields into an info.plist; rows without a name are left out.
    public func apply(to plist: inout [String: Any]) {
        plist["name"] = name
        plist["createdby"] = author
        plist["version"] = version
        plist["bundleid"] = bundleID
        plist["webaddress"] = webAddress
        plist["description"] = description
        plist["readme"] = readme
        let named = variables.map { ($0.name.trimmingCharacters(in: .whitespaces), $0) }.filter { !$0.0.isEmpty }
        plist["variables"] = Dictionary(named.map { ($0.0, $0.1.value) }) { _, last in last }
        plist["variablesdontexport"] = named.filter(\.1.dontExport).map(\.0)
    }
}

/// Export Workflow… (S-046): the info.plist that goes into a shared copy.
public enum WorkflowExport {
    /// The variables marked Don't Export keep their name but lose their
    /// value, as in Alfred, so whoever installs it knows what to fill in.
    public static func plist(_ plist: [String: Any]) -> [String: Any] {
        var plist = plist
        let hidden = plist["variablesdontexport"] as? [String] ?? []
        if var variables = plist["variables"] as? [String: Any] {
            for name in hidden where variables[name] != nil { variables[name] = "" }
            plist["variables"] = variables
        }
        return plist
    }

    /// Files that stay on this Mac: the values of Configure Workflow….
    public static let leftOut: Set<String> = [WorkflowConfiguration.prefsFile]

    /// Copies `folder` into `staging` ready to zip: Don't Export values blanked, prefs.plist left out.
    public static func stage(_ folder: URL, in staging: URL) throws -> URL {
        let target = staging.appending(path: folder.lastPathComponent, directoryHint: .isDirectory)
        try FileManager.default.copyItem(at: folder, to: target)
        for name in leftOut { try? FileManager.default.removeItem(at: target.appending(path: name)) }
        try WorkflowFolder.update(target) { $0 = plist($0) }
        return target
    }
}
