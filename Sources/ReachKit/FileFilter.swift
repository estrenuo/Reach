import Foundation

/// A File Filter (S-051): a keyword that lists files Spotlight finds for the
/// text after it, of the types it names; Return sends the file's path on.
/// Alfred's `alfred.workflow.input.filefilter`.
public struct FileFilter: KeywordTrigger, Equatable {
    public static let type = "alfred.workflow.input.filefilter"

    /// A metadata attribute the text is matched in, like `kMDItemDisplayName`.
    public struct Field: Equatable, Sendable {
        public var attribute: String
        /// What is matched, `{query}` for the typed text.
        public var value: String
        /// Every word on its own, instead of the whole text.
        public var split: Bool
        /// A match at the start of a word, not anywhere.
        public var words: Bool
        public var not: Bool

        public init(attribute: String, value: String = "{query}", split: Bool = true, words: Bool = true, not: Bool = false) {
            self.attribute = attribute
            self.value = value
            self.split = split
            self.words = words
            self.not = not
        }
    }

    public var uid: String
    public var keyword: String
    public var withSpace: Bool
    public var argument: KeywordArgument
    public var title: String
    public var subtext: String
    /// UTIs; a file shows when its type is one of them. Empty is any file.
    public var types: [String]
    /// Folders to search; empty is Reach's own search scope.
    public var scopes: [String]
    public var fields: [Field]
    /// At most this many rows; 0 is Reach's own limit.
    public var limit: Int
    /// Options Reach does not follow, by name and value, for the debugger.
    public var unmapped: [String]

    public init(uid: String, keyword: String, withSpace: Bool = true, argument: KeywordArgument = .required,
                title: String = "", subtext: String = "", types: [String] = [], scopes: [String] = [],
                fields: [Field] = FileFilter.defaultFields, limit: Int = 0, unmapped: [String] = []) {
        self.uid = uid
        self.keyword = keyword
        self.withSpace = withSpace
        self.argument = argument
        self.title = title
        self.subtext = subtext
        self.types = types
        self.scopes = scopes
        self.fields = fields
        self.limit = limit
        self.unmapped = unmapped
    }

    /// Alfred's fields for a new File Filter: the name, other names and the Finder comment.
    public static let defaultFields = ["kMDItemDisplayName", "kMDItemAlternateNames", "kMDItemFinderComment"]
        .map { Field(attribute: $0) }

    /// Nil for another type of object, or one without a keyword.
    public init?(_ object: WorkflowObject, variables: [String: String] = [:]) {
        guard object.type == Self.type, let keyword = Workflow.keyword(of: object, variables: variables) else { return nil }
        let fields = (object.config["fields"]?.array ?? []).compactMap { value -> Field? in
            guard let field = value.dict, let attribute = field["field"]?.string, !attribute.isEmpty else { return nil }
            return Field(attribute: attribute, value: field["value"]?.string ?? "{query}", split: field["split"]?.bool ?? true,
                         words: field["words"]?.bool ?? true, not: field["not"]?.bool ?? false)
        }
        var unmapped: [String] = []
        for (key, normal) in [("sortmode", 0), ("daterange", 0), ("argumenttrimmode", 0)] where object.int(key) != normal {
            unmapped.append("\(key) \(object.int(key))")
        }
        if object.bool("includesystem") { unmapped.append("includesystem") }
        if object.config["anchorfields"]?.bool == false { unmapped.append("anchorfields off") }
        self.init(uid: object.uid, keyword: keyword, withSpace: object.config["withspace"]?.bool ?? true,
                  argument: KeywordArgument(rawValue: object.int("argumenttype")) ?? .required,
                  title: object.string("title"), subtext: object.string("subtext"),
                  types: (object.config["types"]?.array ?? []).compactMap(\.string),
                  scopes: (object.config["scopes"]?.array ?? []).compactMap(\.string),
                  fields: fields.isEmpty ? Self.defaultFields : fields, limit: object.int("limit"), unmapped: unmapped)
    }

    /// The Spotlight query for `text`: any field matches (every word of it,
    /// at a word start), and the file is one of the types.
    public func predicate(for text: String) -> String {
        let matches = fields.compactMap { field -> String? in
            let value = WorkflowText.fill(field.value, query: text)
            let parts = field.split ? value.split(whereSeparator: \.isWhitespace).map(String.init) : [value]
            let clauses = parts.filter { !$0.isEmpty }.map { part in
                "\(field.attribute) \(field.not ? "!=" : "==") \"\(SpotlightPredicate.escaped(part))*\"cd\(field.words ? "w" : "")"
            }
            guard !clauses.isEmpty else { return nil }
            return clauses.count == 1 ? clauses[0] : "(" + clauses.joined(separator: " && ") + ")"
        }
        var all = [matches.isEmpty ? "kMDItemFSName == \"*\"" : "(" + matches.joined(separator: " || ") + ")"]
        if !types.isEmpty {
            all.append("(" + types.map { "kMDItemContentTypeTree == \"\(SpotlightPredicate.escaped($0))\"" }.joined(separator: " || ") + ")")
        }
        return all.joined(separator: " && ")
    }
}

extension Workflow {
    /// The File Filters, each with a keyword.
    public var fileFilters: [FileFilter] {
        let values = keywordVariables
        return objects.compactMap { FileFilter($0, variables: values) }
    }
}
