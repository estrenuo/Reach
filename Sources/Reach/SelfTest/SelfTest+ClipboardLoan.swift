import AppKit
import ReachKit
import SwiftData

extension SelfTest {
    /// The selection hotkey's ⌘C fallback borrows the clipboard like a snippet
    /// paste (M4 check-in): what was copied comes back, a password does not, and
    /// Clipboard History keeps neither. A private pasteboard and a fake ⌘C.
    static func checkClipboardLoan(model: AppModel) async {
        let context = model.container.mainContext
        let settings = ClipboardSettings.shared
        let pasteboard = NSPasteboard.withUniqueName()
        let history = ClipboardHistory(pasteboard: pasteboard, context: context, settings: settings)
        history.frontApp = { ("TextEdit", "com.apple.TextEdit") }
        defer {
            history.items.forEach(context.delete)
            try? context.save()
            settings.reset()
            pasteboard.releaseGlobally()
        }
        func copy(_ text: String, private secret: Bool = false) {
            let types: [NSPasteboard.PasteboardType] = secret ? [.string, .init("org.nspasteboard.ConcealedType")] : [.string]
            pasteboard.declareTypes(types, owner: nil)
            pasteboard.setString(text, forType: .string)
        }
        func select(_ text: String?) async -> String? {
            await SelectionReader.copiedText(board: pasteboard, history: history, pressCopy: {
                // The app copies its selection, and the history polls meanwhile.
                if let text { copy(text) }
                history.poll()
            }, wait: .milliseconds(20))
        }

        settings.keep[.text] = true
        copy("copied before")
        history.poll()
        let clips = history.items.count
        let read = await select("the selection")
        check("⌘C reads the selection and puts the clipboard back",
              read == "the selection" && pasteboard.string(forType: .string) == "copied before", read ?? "nothing")
        check("Clipboard History keeps neither the selection nor the restore",
              !history.poll() && history.items.count == clips && !history.isPaused)
        let none = await select(nil)
        check("with nothing selected the clipboard is left alone", none == nil && pasteboard.string(forType: .string) == "copied before")
        copy("secret-password", private: true)
        _ = await select("the selection")
        check("a copied password is not put back, so its password manager can clear it",
              pasteboard.string(forType: .string) == nil)
    }
}
