import AppKit
import ReachKit

extension SelfTest {
    /// S-028: ⌘C twice appends what was just copied to the text clip before
    /// it. A private pasteboard and a sound recorder; no key monitor is
    /// installed, since the setting stays off while a watcher exists.
    static func checkMerging(model: AppModel) async {
        check("test runs never watch for ⌘C", model.doubleCopy == nil)
        let settings = ClipboardSettings.shared
        let pasteboard = NSPasteboard.withUniqueName()
        let context = model.container.mainContext
        let history = ClipboardHistory(pasteboard: pasteboard, context: context, settings: settings)
        var app: (name: String, bundleID: String)? = ("TextEdit", "com.apple.TextEdit")
        var now = Date.now
        var sounds: [String] = []
        history.frontApp = { app }
        history.now = { now }
        history.playSound = { sounds.append($0) }
        defer {
            history.items.forEach(context.delete)
            try? context.save()
            settings.reset()
            pasteboard.releaseGlobally()
        }
        func copy(_ text: String) {
            now += 60
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(text, forType: .string)
        }

        let watcher = DoubleCopyWatcher(history: history)
        watcher.follow()
        check("with Append off, nothing watches for ⌘C", !watcher.isWatching)
        check("Merging is off while Keep Plain Text is off", !settings.canAppend && !settings.appendsOnDoubleCopy)
        settings.keep[.text] = true
        copy("Hello")
        history.poll()
        copy("world")
        check("with Append off, ⌘C twice appends nothing", !history.appendLatest() && history.items.count == 1)
        settings.appendsOnDoubleCopy = true
        check("the second ⌘C appends, even before the poller saw the copy", history.appendLatest())
        check("the text is added to the clip before it, with a space, and its own clip goes",
              history.items.map(\.text) == ["Hello world"], history.items.map(\.text).joined(separator: " | "))
        check("the merged text is on the clipboard, and not kept again",
              pasteboard.string(forType: .string) == "Hello world" && !history.poll())
        check("the Purr sound plays", sounds == ["Purr"])

        settings.separator = .newline
        settings.playsMergeSound = false
        settings.placesMergedText = false
        copy("again")
        history.poll()
        history.appendLatest()
        check("the separator setting is used", history.items.first?.text == "Hello world\nagain", history.items.first?.text ?? "none")
        check("with Play a Sound off, no sound plays", sounds.count == 1)
        check("with Put on the Clipboard off, the clipboard keeps the last copy", pasteboard.string(forType: .string) == "again")

        app = ("1Password", "com.1password.1password")
        copy("secret")
        check("a copy from an ignored app is never appended",
              !history.appendLatest() && !history.items.contains { $0.text.contains("secret") })
        app = ("TextEdit", "com.apple.TextEdit")
        history.items.forEach(context.delete)
        copy("alone")
        history.poll()
        check("with no clip before it, nothing is appended", !history.appendLatest() && history.items.map(\.text) == ["alone"])
        settings.keep[.text] = false
        check("with Keep Plain Text off, Merging is off", !settings.canAppend && !history.appendLatest())
        settings.appendsOnDoubleCopy = false
    }
}
