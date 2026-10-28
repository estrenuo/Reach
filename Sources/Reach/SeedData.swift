import Foundation
import SwiftData

/// Sample data for snapshots: APP_SEED=1 with APP_STORE in /tmp fills an empty
/// store with realistic snippets (short and long names, starred and not).
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
        let samples: [(String, String, Bool)] = [
            ("Email signature", "Met vriendelijke groet,\nSander Robijns", true),
            ("Home address", "Voorbeeldstraat 12\n1234 AB Utrecht", false),
            ("Meeting follow-up with the action items, owners and the date of the next check-in", "Bedankt voor het overleg van vandaag. Hieronder de afspraken met eigenaar en datum.", false),
            ("Shrug", "¯\\_(ツ)_/¯", true),
            ("Invoice reference", "Graag het factuurnummer vermelden bij betaling.", false),
            ("Git commit template", "feat: \n\nWhy:\n", false),
            ("Out of office", "Ik ben tot en met vrijdag afwezig en lees mijn mail na terugkomst.", true),
            ("Phone number", "06 12 34 56 78", false),
        ]
        for (index, sample) in samples.enumerated() {
            let snippet = Snippet(name: sample.0)
            snippet.text = sample.1
            snippet.isStarred = sample.2
            snippet.createdAt = Date.now.addingTimeInterval(Double(-index) * 3_600)
            context.insert(snippet)
        }
        try? context.save()
    }
}
