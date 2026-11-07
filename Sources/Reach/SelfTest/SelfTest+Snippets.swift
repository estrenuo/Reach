import Foundation
import ReachKit
import SwiftData

extension SelfTest {
    /// S-029: collections hold snippets with a name, keyword and text; they
    /// persist, are found by name or keyword, and a deleted collection comes back with ⌘Z.
    static func checkSnippets(model: AppModel) async {
        let context = model.container.mainContext
        let undo = UndoManager()
        let (page, selection, undoManager) = (model.page, model.selection, context.undoManager)
        context.undoManager = undo
        defer {
            context.undoManager = undoManager
            (model.page, model.selection) = (page, selection)
        }
        func collections() -> [SnippetCollection] { (try? context.fetch(FetchDescriptor<SnippetCollection>())) ?? [] }

        let work = model.addCollection(name: "  Work   mail ")
        check("a new collection gets a clean name and is shown", work.name == "Work mail" && model.page == .collection(work.id))
        check("an empty name becomes New Collection", SnippetName.clean(" ", fallback: "New Collection") == "New Collection")
        let snippet = model.addSnippet(name: "Email signature")
        snippet.keyword = SnippetName.keyword(" s ig ")
        snippet.text = "Met vriendelijke groet,\nSander"
        try? context.save()
        check("a new snippet goes into the collection on screen and is selected",
              snippet.collection?.id == work.id && model.selection == snippet.id && work.snippets?.count == 1)
        check("a keyword is one word", snippet.keyword == "sig")

        // A context of its own reads only what was saved to the store.
        let fresh = ModelContext(model.container)
        let saved = (try? fresh.fetch(FetchDescriptor<Snippet>(predicate: #Predicate { $0.name == "Email signature" }))) ?? []
        check("the snippet and its collection persist",
              saved.count == 1 && saved.first?.keyword == "sig" && saved.first?.collection?.name == "Work mail")
        let all = (try? context.fetch(FetchDescriptor<Snippet>())) ?? []
        check("a snippet is found by its keyword", all.filter { SnippetSearch.score("sig", name: $0.name, keyword: $0.keyword) == 1100 }.map(\.name) == ["Email signature"])
        check("and by its name", all.contains { $0.name == "Email signature" && SnippetSearch.score("email", name: $0.name, keyword: $0.keyword) != nil })

        model.page = .all
        let loose = model.addSnippet(name: "On All Snippets")
        check("on All Snippets a new snippet goes into the oldest collection", loose.collection != nil)

        let orphan = Snippet(name: "From before collections")
        context.insert(orphan)
        try? context.save()
        model.adoptLooseSnippets()
        check("snippets from before S-029 get a collection", orphan.collection != nil)

        let count = collections().count
        // ⌘Z puts the snippets back as new models; find them again by their ids.
        let leftovers = [loose.uuid, orphan.uuid]
        let kept = work.snippets?.count ?? 0
        model.page = .collection(work.id)
        // The undo manager groups by event, like in the app: a run-loop turn
        // closes the group, and the window draws between the steps.
        await Self.nextEvent()
        undo.removeAllActions()
        model.delete(work)
        check("deleting a collection deletes its snippets",
              collections().count == count - 1 && ((try? context.fetchCount(FetchDescriptor<Snippet>(predicate: #Predicate { $0.name == "Email signature" }))) ?? 0) == 0
                && model.page == .all)
        await Self.nextEvent()
        undo.undo()
        let back = (try? context.fetch(FetchDescriptor<SnippetCollection>(predicate: #Predicate { $0.name == "Work mail" }))) ?? []
        check("⌘Z brings the collection back with its snippets",
              back.count == 1 && back.first?.snippets?.contains { $0.name == "Email signature" } == true)
        check("and shows it", back.first.map { model.page == .collection($0.id) } ?? false)
        await Self.nextEvent()
        undo.redo()
        func workMail() -> [SnippetCollection] {
            (try? context.fetch(FetchDescriptor<SnippetCollection>(predicate: #Predicate { $0.name == "Work mail" }))) ?? []
        }
        check("⌘⇧Z deletes it again", workMail().isEmpty && model.page == .all)
        await Self.nextEvent()
        undo.undo()
        check("and ⌘Z brings it back once more", kept > 0 && workMail().first?.snippets?.count == kept)

        workMail().forEach(context.delete)
        for uuid in leftovers {
            let found = (try? context.fetch(FetchDescriptor<Snippet>(predicate: #Predicate { $0.uuid == uuid }))) ?? []
            found.forEach(context.delete)
        }
        try? context.save()
    }

    /// Lets the main run loop turn once, so the undo manager closes its event group.
    static func nextEvent() async { try? await Task.sleep(for: .milliseconds(50)) }
}
