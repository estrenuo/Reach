import Foundation
import ReachKit
import SwiftData

/// A URL typed in the search field (S-017): one row above the other results,
/// so Return opens it.
final class TypedURLSource: ResultSource {
    let settings: WebSearchSettings

    init(settings: WebSearchSettings = .shared) {
        self.settings = settings
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query, let url = settings.typedURL(text) else { return [] }
        return [Scored(result: LaunchResult(id: "url:typed", title: url.absoluteString, subtitle: "Open this URL",
                                            icon: .symbol("globe"), url: url, kindLabel: "URL",
                                            isPinned: true, remembers: true), score: 0)]
    }
}

/// The URL history (S-017): URLs opened from the launcher, found again by
/// any part of them, ranked with the apps. Kept in the app's database; a URL
/// nobody opens for the chosen period goes.
@Observable
final class URLHistory: ResultSource {
    struct Entry: Equatable, Identifiable {
        var url: String
        var lastUsed: Date
        var id: String { url }
    }

    /// Newest first.
    private(set) var entries: [Entry] = []
    @ObservationIgnored private var container: ModelContainer?
    @ObservationIgnored let settings: WebSearchSettings
    @ObservationIgnored var now: @MainActor () -> Date = { .now }

    init(settings: WebSearchSettings = .shared) {
        self.settings = settings
    }

    func attach(_ container: ModelContainer) {
        self.container = container
        prune()
    }

    func record(_ url: URL) {
        guard settings.keepsHistory, let context = container?.mainContext else { return }
        let text = url.absoluteString
        let visit = (try? context.fetch(FetchDescriptor<URLVisit>(predicate: #Predicate { $0.url == text })))?.first
            ?? { let new = URLVisit(url: text); context.insert(new); return new }()
        visit.lastUsed = now()
        try? context.save()
        prune()
    }

    func remove(_ url: String) {
        delete(#Predicate<URLVisit> { $0.url == url })
    }

    /// Settings > Web Search > Clear, after the person confirms.
    func clear() {
        delete(#Predicate<URLVisit> { _ in true })
    }

    /// Removes URLs not opened within the retention period, then reloads.
    func prune() {
        if let cutoff = settings.retention.cutoff(now: now()) {
            delete(#Predicate<URLVisit> { $0.lastUsed < cutoff }, reload: false)
        }
        reload()
    }

    private func delete(_ predicate: Predicate<URLVisit>, reload again: Bool = true) {
        guard let context = container?.mainContext else { return }
        for visit in (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? [] {
            context.delete(visit)
        }
        try? context.save()
        if again { reload() }
    }

    private func reload() {
        let visits = (try? container?.mainContext.fetch(
            FetchDescriptor<URLVisit>(sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]))) ?? []
        entries = visits.map { Entry(url: $0.url, lastUsed: $0.lastUsed) }
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard settings.keepsHistory, case .normal(let text) = query else { return [] }
        // The typed URL already has its own row.
        let typed = settings.typedURL(text)?.absoluteString
        return entries.compactMap { entry in
            guard entry.url != typed, let url = URL(string: entry.url) else { return nil }
            let title = TypedURL.display(entry.url)
            guard let score = Matcher.score(query: text, title: title) else { return nil }
            return Scored(result: LaunchResult(id: "history:\(entry.url)", title: title, subtitle: entry.url,
                                               icon: .symbol("clock.arrow.circlepath"), url: url,
                                               kindLabel: "URL from your history", remembers: true), score: score)
        }
    }
}
