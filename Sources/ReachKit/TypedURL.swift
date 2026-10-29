import Foundation

/// A URL typed in the search field (S-017): `example.com`, `https://…`,
/// `localhost:3000`, and with the setting on, `mailto:a@b.c`.
public enum TypedURL {
    /// The URL `query` names, or nil when it is not one. A bare domain gets
    /// `scheme`. Only domains in `domains` count, so a file name like
    /// `report.pdf` or `README.md` stays a search.
    public static func url(from query: String, scheme: String = "https", withoutSlashes: Bool = false) -> URL? {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }
        if let range = text.range(of: "://") {
            let given = text[..<range.lowerBound]
            guard isScheme(given), range.upperBound < text.endIndex else { return nil }
            return URL(string: text)
        }
        if isBareHost(text) { return URL(string: "\(scheme)://\(text)") }
        if withoutSlashes, let colon = text.firstIndex(of: ":"), isScheme(text[..<colon]),
           text.index(after: colon) < text.endIndex {
            return URL(string: text)
        }
        return nil
    }

    /// The URL without `https://` and a trailing slash: what the history row shows.
    public static func display(_ url: String) -> String {
        var text = url
        for prefix in ["https://", "http://"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        if text.hasSuffix("/"), text.filter({ $0 == "/" }).count == 1 { text.removeLast() }
        return text
    }

    private static func isScheme(_ text: Substring) -> Bool {
        guard let first = text.first, first.isASCII, first.isLetter else { return false }
        return text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "+.-".contains($0)) }
    }

    /// `name.tld`, `sub.name.tld:8080/path`, `localhost:3000`, or an IPv4 address.
    private static func isBareHost(_ text: String) -> Bool {
        let hostAndPort = text.prefix { !"/?#".contains($0) }
        let parts = hostAndPort.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return false }
        if parts.count == 2 {
            guard !parts[1].isEmpty, parts[1].allSatisfy(\.isASCII), parts[1].allSatisfy(\.isNumber) else { return false }
        }
        let host = parts[0].lowercased()
        if host == "localhost" { return true }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy(isLabel) else { return false }
        if labels.count == 4, labels.allSatisfy({ $0.allSatisfy(\.isNumber) && (Int($0) ?? 256) < 256 }) { return true }
        return domains.contains(String(labels.last!))
    }

    private static func isLabel(_ label: Substring) -> Bool {
        !label.isEmpty && !label.hasPrefix("-") && !label.hasSuffix("-")
            && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }

    /// Common top-level domains. Left out on purpose, because they are also
    /// file extensions: md, sh, py, rs, so, zip, mov, ps, pl, pm, rb.
    public static let domains: Set<String> = [
        "com", "org", "net", "edu", "gov", "mil", "int", "info", "biz", "name", "pro",
        "io", "ai", "app", "dev", "co", "me", "tv", "fm", "gg", "ly", "to", "cc", "ws",
        "xyz", "tech", "online", "site", "store", "shop", "blog", "cloud", "news", "design",
        "studio", "page", "link", "email", "live", "art", "wiki", "social", "agency", "games",
        "nl", "be", "de", "fr", "uk", "eu", "es", "it", "ch", "at", "se", "no", "dk", "fi",
        "pt", "ie", "lu", "cz", "gr", "hu", "ro", "us", "ca", "mx", "br", "ar", "au", "nz",
        "jp", "cn", "kr", "in", "sg", "hk", "tw", "za", "ru", "ua", "tr", "il",
    ]
}

/// How long the URL history keeps a URL nobody opens (S-017).
public enum URLRetention: String, CaseIterable, Codable, Sendable {
    case week, month, threeMonths, year, never

    public var title: String {
        switch self {
        case .week: "1 Week"
        case .month: "1 Month"
        case .threeMonths: "3 Months"
        case .year: "1 Year"
        case .never: "Never"
        }
    }

    /// URLs last opened before this date go; nil keeps them all.
    public func cutoff(now: Date, calendar: Calendar = .current) -> Date? {
        let component: (Calendar.Component, Int)? = switch self {
        case .week: (.day, -7)
        case .month: (.month, -1)
        case .threeMonths: (.month, -3)
        case .year: (.year, -1)
        case .never: nil
        }
        guard let component else { return nil }
        return calendar.date(byAdding: component.0, value: component.1, to: now)
    }

    public func isExpired(lastUsed: Date, now: Date, calendar: Calendar = .current) -> Bool {
        guard let cutoff = cutoff(now: now, calendar: calendar) else { return false }
        return lastUsed < cutoff
    }
}
