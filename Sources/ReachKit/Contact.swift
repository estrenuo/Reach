import Foundation

/// One person or company from Contacts (S-024), as plain values, so the
/// launcher, the self-test and the unit tests share it without the Contacts framework.
public struct Contact: Equatable, Sendable, Identifiable {
    public var id: String
    public var namePrefix = ""
    public var givenName = ""
    public var middleName = ""
    public var familyName = ""
    public var nameSuffix = ""
    public var nickname = ""
    public var organization = ""
    public var jobTitle = ""
    public var fields: [ContactField] = []

    public init(id: String, namePrefix: String = "", givenName: String = "", middleName: String = "",
                familyName: String = "", nameSuffix: String = "", nickname: String = "",
                organization: String = "", jobTitle: String = "", fields: [ContactField] = []) {
        self.id = id
        self.namePrefix = namePrefix
        self.givenName = givenName
        self.middleName = middleName
        self.familyName = familyName
        self.nameSuffix = nameSuffix
        self.nickname = nickname
        self.organization = organization
        self.jobTitle = jobTitle
        self.fields = fields
    }

    /// How the name shows, per Settings > Contacts: last name first or not,
    /// with the title (Mr, Dr) or not. A company without a person's name shows its name.
    public func name(lastFirst: Bool = false, showTitle: Bool = false) -> String {
        let first = [givenName, middleName].filter { !$0.isEmpty }.joined(separator: " ")
        let core = (lastFirst ? [familyName, first] : [first, familyName]).filter { !$0.isEmpty }
        guard !core.isEmpty else { return organization.isEmpty ? nickname : organization }
        let parts = (showTitle ? [namePrefix] : []) + core + [nameSuffix]
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// The line under the name: "Job title, Organization", the organization
    /// alone, or the first email address or phone number.
    public func subtitle(showJobTitle: Bool = false) -> String {
        let job = showJobTitle ? jobTitle : ""
        // A company's own card has its name as the title already.
        let company = name() == organization ? "" : organization
        let work = [job, company].filter { !$0.isEmpty }.joined(separator: ", ")
        if !work.isEmpty { return work }
        return (fields.first { $0.kind == .email } ?? fields.first { $0.kind == .phone })?.value ?? ""
    }

    /// The words a search matches: every part of the name, the nickname, the organization.
    public var searchText: String {
        [givenName, middleName, familyName, nickname, organization].filter { !$0.isEmpty }.joined(separator: " ")
    }

    public var emails: [ContactField] { fields.filter { $0.kind == .email } }

    /// Two letters for the card when there is no photo: "SR", or "A" for Acme.
    public var initials: String {
        let words = [givenName, familyName].filter { !$0.isEmpty }
        let source = words.isEmpty ? name().split(separator: " ").prefix(2).map(String.init) : words
        return source.compactMap(\.first).map { String($0).uppercased() }.joined()
    }
}

/// One line of a contact card: an email address, a phone number, and so on.
public struct ContactField: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case email, phone, url, address, birthday
    }

    /// What Return does on the field in the card.
    public enum Action: Equatable, Sendable {
        case email(URL), open(URL), map(URL), copy
    }

    public var kind: Kind
    /// "work", "mobile", "home": shown under the value.
    public var label: String
    public var value: String
    public var id: String { "\(kind.rawValue):\(label):\(value)" }

    public init(_ kind: Kind, label: String = "", value: String) {
        self.kind = kind
        self.label = label
        self.value = value
    }

    public static let mapsBase = "https://maps.apple.com/?q="

    public var action: Action {
        switch kind {
        case .email:
            return Self.mailURL(to: value).map(Action.email) ?? .copy
        case .url:
            // Only web pages: a contact from a shared card could hold file:// or an app's scheme.
            let text = value.contains("://") ? value : "https://" + value
            guard let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()) else { return .copy }
            return .open(url)
        case .address:
            let line = value.split(whereSeparator: \.isNewline).joined(separator: ", ")
            return line.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
                .flatMap { URL(string: Self.mapsBase + $0) }.map(Action.map) ?? .copy
        case .phone, .birthday:
            return .copy
        }
    }

    /// The footer in the card: what Return does on this field.
    public var summary: String {
        switch action {
        case .email: "Start an email to \(value)"
        case .open: "Open the website in your browser"
        case .map: "Show the address in Maps"
        case .copy: "Copy the \(kind == .phone ? "phone number" : kind.rawValue)"
        }
    }

    /// `mailto:` for an address, encoded so `+` and spaces survive.
    public static func mailURL(to address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard isEmailAddress(trimmed),
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["+", "?", "&"]))
        else { return nil }
        return URL(string: "mailto:\(encoded)")
    }

    /// Something@something.something, without spaces: enough to tell an address from a name.
    public static func isEmailAddress(_ text: String) -> Bool {
        text.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }
}

extension CharacterSet {
    /// A query value: no `&`, `=`, `+` or `#`, which would end or change it.
    static let urlQueryValueAllowed = CharacterSet.urlQueryAllowed.subtracting(["&", "=", "+", "#"])
}
