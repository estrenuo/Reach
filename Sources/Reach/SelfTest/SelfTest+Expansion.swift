import AppKit
import Carbon
import ReachKit
import SwiftData

extension SelfTest {
    /// S-031: a snippet keyword typed at the start of a word is deleted and the
    /// snippet pasted in its place. Made-up key events, a recorder for Delete and
    /// ⌘V, and a private pasteboard: no real key monitor, no other app is touched.
    static func checkExpansion(model: AppModel) async {
        check("test runs never watch the real keyboard", model.snippetExpander == nil)
        let lm = model.launcherModel
        let context = model.container.mainContext
        let settings = SnippetSettings.shared
        check("expanding while typing is off at first", !settings.expandsWhileTyping)
        let pasteboard = NSPasteboard.withUniqueName()
        var pastes = 0
        var deleted: [Int] = []
        let (paster, board, delay) = (lm.paster, lm.pasteboard, lm.restoreDelay)
        lm.paster = { pastes += 1 }
        lm.pasteboard = pasteboard
        lm.restoreDelay = .milliseconds(50)
        let collection = SnippetCollection(name: "Expansion test")
        context.insert(collection)
        for (keyword, text) in [(";zsig", "Groeten, Sander"), ("zad", "Stationsplein 1"), (";zad", "Stationsplein 1, Utrecht")] {
            let snippet = Snippet(name: "Expand \(keyword)")
            snippet.keyword = keyword
            snippet.text = text
            snippet.collection = collection
            context.insert(snippet)
        }
        try? context.save()
        let expander = SnippetExpander(launcher: lm, settings: settings)
        let front = Shared("com.apple.TextEdit")
        let secure = Shared(false)
        expander.frontApp = { front.value }
        expander.isSecure = { secure.value }
        expander.deleter = { deleted.append($0) }
        defer {
            (lm.paster, lm.pasteboard, lm.restoreDelay) = (paster, board, delay)
            context.delete(collection)
            try? context.save()
            settings.reset()
            pasteboard.releaseGlobally()
        }
        func type(_ text: String) {
            for character in text {
                let keyCode = character == "\n" ? kVK_Return : kVK_ANSI_A
                if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                                                context: nil, characters: String(character), charactersIgnoringModifiers: String(character),
                                                isARepeat: false, keyCode: UInt16(keyCode)) {
                    expander.handle(event)
                }
            }
        }
        func key(_ code: Int, flags: NSEvent.ModifierFlags = []) {
            if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                                            context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                                            keyCode: UInt16(code)) {
                expander.handle(event)
            }
        }

        type("Tot morgen.\n;zsig")
        check("a keyword at the start of a word is deleted and its snippet pasted",
              deleted == [5] && pastes == 1 && pasteboard.string(forType: .string) == "Groeten, Sander",
              "deleted \(deleted), pasted \(pastes)")
        check("in TextEdit and Safari alike", { front.value = "com.apple.Safari"; type(" zad"); return pastes == 2 && deleted.last == 3 }())
        type(" ;zad")
        check("the longest keyword that was typed wins: “;zad” over “zad”", pastes == 3 && deleted.last == 4
              && pasteboard.string(forType: .string) == "Stationsplein 1, Utrecht", "pasted \(pastes)")
        type(" zzad")
        check("not in the middle of a word", pastes == 3)
        type(" Zad")
        check("case counts", pastes == 3)
        type(" zaq")
        key(kVK_Delete)
        type("d")
        check("Delete is followed: “zaq ⌫ d” is the keyword", pastes == 4)
        type(" za")
        key(kVK_LeftArrow)
        type("d")
        check("an arrow key starts over", pastes == 4)
        type(" za")
        key(kVK_ANSI_A, flags: .command)
        type("d")
        check("so does a shortcut like ⌘A", pastes == 4)
        secure.value = true
        type(" zad")
        check("never in a password field", pastes == 4 && expander.buffer.text.isEmpty)
        secure.value = false
        front.value = Bundle.main.bundleIdentifier ?? ""
        type(" zad")
        check("never in Reach itself", pastes == 4)
        front.value = "com.apple.TextEdit"
        check("the typed text stays short", { type(String(repeating: "x", count: 200)); return expander.buffer.text.count == TypedBuffer.limit }())
        try? await Task.sleep(for: .milliseconds(200))
    }
}
