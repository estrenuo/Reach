import Foundation

/// Fills a web search's URL template, like `https://example.com/?q={query}`.
public enum WebSearchURL {
    public static func make(template: String, query: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#/")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: template.replacingOccurrences(of: "{query}", with: encoded))
    }
}
