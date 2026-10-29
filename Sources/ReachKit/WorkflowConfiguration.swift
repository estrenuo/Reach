import Foundation

/// One field of a workflow's configuration (S-043): Alfred's
/// `userconfigurationconfig` in info.plist. Its value reaches the scripts as
/// the environment variable `variable`.
public struct WorkflowSetting: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case textfield, textarea, checkbox, popupbutton, filepicker
    }

    public var kind: Kind
    public var variable: String
    public var label: String
    public var description: String
    public var defaultValue: String
    public var required: Bool
    public var placeholder: String
    /// The checkbox's own text, next to the box.
    public var text: String
    /// The choices of a pop-up button: what it shows and the value it passes.
    public var options: [(label: String, value: String)]

    public var id: String { variable }

    public init(kind: Kind, variable: String, label: String = "", description: String = "", defaultValue: String = "",
                required: Bool = false, placeholder: String = "", text: String = "", options: [(label: String, value: String)] = []) {
        self.kind = kind
        self.variable = variable
        self.label = label
        self.description = description
        self.defaultValue = defaultValue
        self.required = required
        self.placeholder = placeholder
        self.text = text
        self.options = options
    }

    init?(_ value: PlistValue) {
        guard let dict = value.dict, let kind = dict["type"]?.string.flatMap(Kind.init(rawValue:)),
              let variable = dict["variable"]?.string, !variable.isEmpty else { return nil }
        let config = dict["config"]?.dict ?? [:]
        let fallback = config["default"].map { kind == .checkbox ? (($0.bool ?? false) ? "1" : "0") : ($0.string ?? "") }
        self.init(kind: kind, variable: variable, label: dict["label"]?.string ?? variable,
                  description: dict["description"]?.string ?? "", defaultValue: fallback ?? (kind == .checkbox ? "0" : ""),
                  required: config["required"]?.bool ?? false, placeholder: config["placeholder"]?.string ?? "",
                  text: config["text"]?.string ?? "",
                  options: (config["pairs"]?.array ?? []).compactMap { pair in
                      guard let parts = pair.array, parts.count == 2, let label = parts[0].string, let value = parts[1].string
                      else { return nil }
                      return (label, value)
                  })
    }

    public static func == (lhs: WorkflowSetting, rhs: WorkflowSetting) -> Bool {
        lhs.kind == rhs.kind && lhs.variable == rhs.variable && lhs.label == rhs.label && lhs.description == rhs.description
            && lhs.defaultValue == rhs.defaultValue && lhs.required == rhs.required && lhs.placeholder == rhs.placeholder
            && lhs.text == rhs.text && lhs.options.map(\.label) == rhs.options.map(\.label)
            && lhs.options.map(\.value) == rhs.options.map(\.value)
    }
}

/// A workflow's configuration: its fields and what the user filled in, kept
/// in the folder's prefs.plist as Alfred does, so info.plist stays the
/// author's and a shared workflow carries no one's values.
public enum WorkflowConfiguration {
    public static let prefsFile = "prefs.plist"

    /// The values saved in `folder`.
    public static func values(in folder: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: folder.appending(path: prefsFile)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [:] }
        return plist.compactMapValues { PlistValue($0)?.string }
    }

    /// Saves `values`; a value equal to the field's default is not kept.
    public static func save(_ values: [String: String], settings: [WorkflowSetting], in folder: URL) throws {
        var kept: [String: String] = [:]
        for setting in settings {
            if let value = values[setting.variable], value != setting.defaultValue { kept[setting.variable] = value }
        }
        let url = folder.appending(path: prefsFile)
        if kept.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try PropertyListSerialization.data(fromPropertyList: kept, format: .xml, options: 0).write(to: url, options: .atomic)
    }

    /// Every field's value: the saved one, else its default.
    public static func resolved(_ settings: [WorkflowSetting], saved: [String: String]) -> [String: String] {
        Dictionary(settings.map { ($0.variable, saved[$0.variable] ?? $0.defaultValue) }) { first, _ in first }
    }

    /// The required fields that are still empty.
    public static func missing(_ settings: [WorkflowSetting], values: [String: String]) -> [WorkflowSetting] {
        settings.filter { $0.required && (values[$0.variable] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
