import Foundation

/// A value from a workflow's info.plist, kept as plain data so a workflow
/// is `Sendable` and can be compared in tests.
public enum PlistValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case data(Data)
    case array([PlistValue])
    case dict([String: PlistValue])

    public init?(_ value: Any) {
        switch value {
        case let string as String: self = .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { self = .bool(number.boolValue) }
            else if CFNumberIsFloatType(number) { self = .double(number.doubleValue) }
            else { self = .int(number.intValue) }
        case let date as Date: self = .date(date)
        case let data as Data: self = .data(data)
        case let array as [Any]: self = .array(array.compactMap(PlistValue.init))
        case let dict as [String: Any]: self = .dict(dict.compactMapValues(PlistValue.init))
        default: return nil
        }
    }

    public var string: String? {
        switch self {
        case .string(let value): value
        case .int(let value): String(value)
        case .double(let value): String(value)
        case .bool(let value): value ? "true" : "false"
        default: nil
        }
    }

    public var int: Int? {
        switch self {
        case .int(let value): value
        case .double(let value): Int(value)
        case .bool(let value): value ? 1 : 0
        case .string(let value): Int(value)
        default: nil
        }
    }

    public var bool: Bool? {
        switch self {
        case .bool(let value): value
        case .int(let value): value != 0
        case .string(let value): ["true", "yes", "1"].contains(value.lowercased())
        default: nil
        }
    }

    public var double: Double? {
        switch self {
        case .int(let value): Double(value)
        case .double(let value): value
        case .string(let value): Double(value)
        default: nil
        }
    }

    public var array: [PlistValue]? { if case .array(let value) = self { value } else { nil } }
    public var dict: [String: PlistValue]? { if case .dict(let value) = self { value } else { nil } }
}

/// One object on a workflow's canvas: a keyword, a script filter, an action.
/// `type` is Alfred's, such as `alfred.workflow.input.scriptfilter`.
public struct WorkflowObject: Equatable, Sendable, Identifiable {
    public var uid: String
    public var type: String
    public var config: [String: PlistValue]

    public var id: String { uid }

    public init(uid: String, type: String, config: [String: PlistValue] = [:]) {
        self.uid = uid
        self.type = type
        self.config = config
    }

    public func string(_ key: String) -> String { config[key]?.string ?? "" }
    public func int(_ key: String, default value: Int = 0) -> Int { config[key]?.int ?? value }
    public func bool(_ key: String) -> Bool { config[key]?.bool ?? false }
}

/// A line from one object to the next. `modifiers` is the key held with
/// Return for this line (`NSEvent.ModifierFlags` raw values), 0 for none.
public struct WorkflowConnection: Equatable, Sendable {
    public var to: String
    public var modifiers: Int
    public var modifierSubtext: String

    public init(to: String, modifiers: Int = 0, modifierSubtext: String = "") {
        self.to = to
        self.modifiers = modifiers
        self.modifierSubtext = modifierSubtext
    }

    public static let command = 1 << 20
    public static let option = 1 << 19
    public static let control = 1 << 18
    public static let shift = 1 << 17
}

/// A workflow folder (S-041): an `info.plist` in Alfred's format next to its
/// scripts and icon. Reach reads the parts it runs: script filters and the
/// objects connected to them.
public struct Workflow: Equatable, Sendable, Identifiable {
    public static let infoFile = "info.plist"

    /// The folder's name, which stays the same when the workflow is edited.
    public var id: String
    public var folder: URL
    public var bundleID: String
    public var name: String
    public var author: String
    public var version: String
    public var description: String
    public var readme: String
    public var category: String
    public var webAddress: String
    public var disabled: Bool
    public var objects: [WorkflowObject]
    /// From an object's uid to the lines that leave it.
    public var connections: [String: [WorkflowConnection]]
    /// The workflow's environment variables, and the ones that stay out of an export.
    public var variables: [String: String]
    public var dontExport: [String]
    /// The fields of Configure Workflow… (S-043) and the values saved in prefs.plist.
    public var settings: [WorkflowSetting] = []
    public var configuration: [String: String] = [:]
    /// Where each object's card sits on the canvas (S-044), from uidata.
    public var positions: [String: WorkflowPoint] = [:]

    public init(id: String, folder: URL, bundleID: String = "", name: String, author: String = "", version: String = "",
                description: String = "", readme: String = "", category: String = "", webAddress: String = "",
                disabled: Bool = false, objects: [WorkflowObject] = [], connections: [String: [WorkflowConnection]] = [:],
                variables: [String: String] = [:], dontExport: [String] = []) {
        self.id = id
        self.folder = folder
        self.bundleID = bundleID
        self.name = name
        self.author = author
        self.version = version
        self.description = description
        self.readme = readme
        self.category = category
        self.webAddress = webAddress
        self.disabled = disabled
        self.objects = objects
        self.connections = connections
        self.variables = variables
        self.dontExport = dontExport
    }

    /// Reads the workflow in `folder`; nil when it has no readable info.plist.
    public init?(folder: URL) {
        guard let data = try? Data(contentsOf: folder.appending(path: Self.infoFile)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        self.init(plist: plist, folder: folder)
        configuration = WorkflowConfiguration.values(in: folder)
    }

    public init(plist: [String: Any], folder: URL) {
        let values = plist.compactMapValues(PlistValue.init)
        func text(_ key: String) -> String { values[key]?.string ?? "" }
        let name = text("name")
        self.init(id: folder.lastPathComponent, folder: folder, bundleID: text("bundleid"),
                  name: name.isEmpty ? folder.lastPathComponent : name,
                  author: text("createdby"), version: text("version"), description: text("description"),
                  readme: text("readme"), category: text("category"), webAddress: text("webaddress"),
                  disabled: values["disabled"]?.bool ?? false)
        objects = (values["objects"]?.array ?? []).compactMap { value in
            guard let dict = value.dict, let uid = dict["uid"]?.string, let type = dict["type"]?.string else { return nil }
            return WorkflowObject(uid: uid, type: type, config: dict["config"]?.dict ?? [:])
        }
        connections = (values["connections"]?.dict ?? [:]).mapValues { lines in
            (lines.array ?? []).compactMap { line in
                guard let dict = line.dict, let to = dict["destinationuid"]?.string else { return nil }
                return WorkflowConnection(to: to, modifiers: dict["modifiers"]?.int ?? 0,
                                          modifierSubtext: dict["modifiersubtext"]?.string ?? "")
            }
        }
        variables = (values["variables"]?.dict ?? [:]).compactMapValues(\.string)
        dontExport = (values["variablesdontexport"]?.array ?? []).compactMap(\.string)
        settings = (values["userconfigurationconfig"]?.array ?? []).compactMap(WorkflowSetting.init)
        positions = (values["uidata"]?.dict ?? [:]).compactMapValues { value in
            guard let x = value.dict?["xpos"]?.double, let y = value.dict?["ypos"]?.double else { return nil }
            return WorkflowPoint(x: x, y: y)
        }
    }

    public func object(_ uid: String) -> WorkflowObject? { objects.first { $0.uid == uid } }

    /// The script filters, each with a keyword.
    public var scriptFilters: [ScriptFilter] {
        let values = keywordVariables
        return objects.compactMap { ScriptFilter($0, variables: values) }
    }

    /// The icon in the folder, if there is one.
    public var icon: URL? {
        let url = folder.appending(path: "icon.png")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// What a script of this workflow gets in its environment, on top of the
    /// process's own: Alfred's names, so existing workflows run unchanged,
    /// the workflow's variables, and its configuration, which wins over a
    /// variable of the same name. `data` and `cache` are the parent folders
    /// of each workflow's own data and cache folders.
    public func environment(data: URL, cache: URL, extra: [String: String] = [:]) -> [String: String] {
        let key = bundleID.isEmpty ? id : bundleID
        let configured = WorkflowConfiguration.resolved(settings, saved: configuration)
        return variables.merging(configured) { _, new in new }.merging(extra) { _, new in new }.merging([
            "alfred_workflow_bundleid": bundleID,
            "alfred_workflow_name": name,
            "alfred_workflow_version": version,
            "alfred_workflow_uid": id,
            "alfred_workflow_data": data.appending(path: key).path,
            "alfred_workflow_cache": cache.appending(path: key).path,
            "alfred_preferences": folder.deletingLastPathComponent().path,
            "alfred_version": "5.5",
            "alfred_debug": "0",
        ]) { _, new in new }
    }
}
