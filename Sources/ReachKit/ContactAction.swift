import Foundation

/// A custom action on one kind of detail in a contact's card (S-058), like
/// "Call with FaceTime" on phone numbers: `facetime://{query}`. It runs with
/// its modifier (⌥↩, ⌃↩) or from the detail's actions (→); ↩ keeps the built-in action.
public struct ContactAction: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: ContactField.Kind
    public var title: String
    /// The URL, with `{query}` where the detail goes.
    public var url: String
    /// ⌥↩ or ⌃↩; nil runs it only from the detail's actions.
    public var modifier: ReturnModifier?

    public init(id: String = UUID().uuidString, kind: ContactField.Kind, title: String, url: String,
                modifier: ReturnModifier? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.url = url
        self.modifier = modifier
    }

    /// The kinds of detail an action can be for: not birthdays.
    public static let kinds: [ContactField.Kind] = [.phone, .email, .address, .url]
    /// The modifiers a card takes: ⌘ keys already copy, open and pick rows there.
    public static let modifiers: [ReturnModifier] = [.option, .control]
    public static let placeholder = "{query}"

    /// The URL for this detail: the template with `{query}` replaced by the
    /// value, encoded once. Nil when the result is no URL with a scheme.
    public func url(for field: ContactField) -> URL? {
        guard field.kind == kind, url.contains(Self.placeholder),
              let value = Self.encode(Self.value(of: field)), !value.isEmpty,
              let made = URL(string: url.replacingOccurrences(of: Self.placeholder, with: value)),
              made.scheme?.isEmpty == false else { return nil }
        return made
    }

    /// What goes in the URL: a phone number without spaces or dashes, an
    /// address on one line, anything else trimmed.
    public static func value(of field: ContactField) -> String {
        let trimmed = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch field.kind {
        case .phone:
            return String(trimmed.unicodeScalars.filter { CharacterSet.phoneKept.contains($0) }.map(Character.init))
        case .address:
            return trimmed.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ", ")
        case .email, .url, .birthday:
            return trimmed
        }
    }

    /// Percent-encodes everything that would end or change a URL part:
    /// `&`, `+`, `=`, `?`, `#`, `/`, spaces, and `%` itself, so a value is encoded once.
    public static func encode(_ value: String) -> String? {
        value.addingPercentEncoding(withAllowedCharacters: .actionValueAllowed)
    }

    /// Why these fields make no action, or nil when they do. `others` are the
    /// saved actions; the one being edited (same id) is left out.
    public static func problem(_ action: ContactAction, others: [ContactAction]) -> String? {
        let title = action.title.trimmingCharacters(in: .whitespaces)
        let url = action.url.trimmingCharacters(in: .whitespaces)
        if title.isEmpty { return "Give the action a title." }
        if !url.contains(placeholder) { return "Put {query} in the URL where the detail goes." }
        let sample = url.replacingOccurrences(of: placeholder, with: "x")
        guard let made = URL(string: sample), let scheme = made.scheme, !scheme.isEmpty else {
            return "The URL needs a scheme, like facetime:"
        }
        if let modifier = action.modifier,
           let other = others.first(where: { $0.id != action.id && $0.kind == action.kind && $0.modifier == modifier }) {
            return "\(modifier.symbol) already runs “\(other.title)” on \(action.kind.plural)."
        }
        return nil
    }

    /// The action for this kind of detail with this modifier, if one is saved.
    public static func action(in all: [ContactAction], for kind: ContactField.Kind,
                              modifier: ReturnModifier) -> ContactAction? {
        all.first { $0.kind == kind && $0.modifier == modifier }
    }
}

extension ContactField.Kind: Codable {
    /// The Detail column and picker: "Phone", "Website".
    public var name: String {
        switch self {
        case .email: "Email"
        case .phone: "Phone"
        case .url: "Website"
        case .address: "Address"
        case .birthday: "Birthday"
        }
    }

    /// "phone numbers", for sentences.
    public var plural: String {
        switch self {
        case .email: "email addresses"
        case .phone: "phone numbers"
        case .url: "websites"
        case .address: "addresses"
        case .birthday: "birthdays"
        }
    }
}

extension ReturnModifier: Codable {}

extension CharacterSet {
    /// Digits and what dials: `+`, `*`, `#`.
    static let phoneKept = CharacterSet(charactersIn: "0123456789+*#")
    static let actionValueAllowed = CharacterSet.urlQueryAllowed.subtracting(["&", "+", "=", "?", "#", "/", "%"])
}
