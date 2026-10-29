import Foundation
import SwiftData

/// Sample data for snapshots: APP_SEED=1 with APP_STORE in /tmp fills an empty
/// store with realistic snippets in collections (short and long names, with and without keywords).
/// Replace these with your app's own types. Seed only what a person can
/// create in the app, or the snapshots show features no one can use.
@MainActor
enum SeedData {
    static func insertIfRequested(into model: AppModel) {
        guard ProcessInfo.processInfo.environment["APP_SEED"] == "1" else { return }
        guard Store.isOverridden else {
            print("APP_SEED ignored: APP_STORE must be a file in /tmp")
            return
        }
        let context = model.container.mainContext
        guard ((try? context.fetchCount(FetchDescriptor<Snippet>())) ?? 0) == 0 else { return }
        // Templates stays empty, for the empty state.
        let collections = ["Work", "Personal", "Templates"].enumerated().map { index, name in
            let collection = SnippetCollection(name: name)
            collection.createdAt = Date.now.addingTimeInterval(Double(-index) * 86_400)
            context.insert(collection)
            return collection
        }
        let samples: [(String, String, String, Int)] = [
            ("Email signature", "sig", "Met vriendelijke groet,\nSander Robijns", 0),
            ("Home address", "addr", "Voorbeeldstraat 12\n1234 AB Utrecht", 1),
            ("Meeting follow-up with the action items, owners and the date of the next check-in", "follow",
             "Bedankt voor het overleg van vandaag. Hieronder de afspraken met eigenaar en datum.", 0),
            ("Shrug", "shrug", "¯\\_(ツ)_/¯", 1),
            ("Invoice reference", "inv", "Graag het factuurnummer vermelden bij betaling.", 0),
            ("Git commit template", "", "feat: \n\nWhy:\n", 0),
            ("Out of office", "ooo", "Ik ben tot en met vrijdag afwezig en lees mijn mail na terugkomst.", 0),
            ("Phone number", "tel", "06 12 34 56 78", 1),
        ]
        for (index, sample) in samples.enumerated() {
            let snippet = Snippet(name: sample.0)
            snippet.keyword = sample.1
            snippet.text = sample.2
            snippet.createdAt = Date.now.addingTimeInterval(Double(-index) * 3_600)
            context.insert(snippet)
            snippet.collection = collections[sample.3]
        }
        try? context.save()
    }
}
