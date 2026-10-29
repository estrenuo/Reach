import AppKit
import Quartz
import SwiftData
import ReachKit

extension SelfTest {
    /// S-013: ⌥↑ collects items in the buffer, ⌥→ runs one action on all of them.
    static func checkBuffer(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let fm = FileManager.default
        let root = NSTemporaryDirectory() + "reach-buffer/"
        try? fm.removeItem(atPath: root)
        try? fm.createDirectory(atPath: root, withIntermediateDirectories: true)
        let names = ["a.txt", "b.txt", "c.txt"]
        for name in names { fm.createFile(atPath: root + name, contents: Data(name.utf8)) }
        func titles(_ urls: [URL]) -> [String] { urls.map(\.lastPathComponent) }
        var ran: [(ActionPanel.Item, [URL])] = []
        lm.perform = { item, urls in ran.append((item, urls)); return true }
        let clock = Shared(ProcessInfo.processInfo.systemUptime)
        lm.now = { clock.value }
        // ⌥ with an arrow, as the real keyboard sends it.
        func option(_ code: UInt16, _ chars: String) -> Bool {
            var flags: NSEvent.ModifierFlags = .option
            if (123...126).contains(code) { flags.formUnion([.numericPad, .function]) }
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: launcher.panel.windowNumber,
                    context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false,
                    keyCode: code) else { return false }
            return launcher.handle(event)
        }
        let up = "\u{F700}", down = "\u{F701}", left = "\u{F702}", right = "\u{F703}"

        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(400))
        check("with an empty buffer ⌥← and ⌥⌫ stay with the text field", !option(123, left) && !option(51, "\u{7f}"))
        _ = option(126, up)
        check("⌥↑ puts the selected item in the buffer", titles(lm.buffer.items) == ["a.txt"], "\(titles(lm.buffer.items))")
        _ = option(126, up)
        check("⌥↑ again takes it out", lm.buffer.isEmpty)
        _ = option(125, down)
        _ = option(125, down)
        check("⌥↓ adds and moves to the next result", titles(lm.buffer.items) == ["a.txt", "b.txt"]
              && lm.selectedResult?.title == "c.txt", "\(titles(lm.buffer.items)), selected \(lm.selectedResult?.title ?? "none")")
        _ = option(126, up)
        check("⌥← takes out the last item", option(123, left) && titles(lm.buffer.items) == ["a.txt", "b.txt"])
        launcher.hide()
        launcher.show()
        check("hiding the launcher keeps the buffer", lm.buffer.items.count == 2)
        lm.query = "zzqxv nothing"
        try? await Task.sleep(for: .milliseconds(300))
        check("⌥↑ on a web search adds nothing", option(126, up) && lm.buffer.items.count == 2)
        check("⌥→ opens the action panel for every item", option(124, right) && lm.actions?.isMany == true
              && lm.actions?.target.title == "2 Items", lm.actions?.target.title ?? "no panel")
        let items = lm.actions?.items ?? []
        check("several items skip Browse, Terminal and Quick Look",
              !items.contains(.action(.browse)) && !items.contains(.action(.terminal)) && !items.contains(.action(.quickLook)))
        lm.cancelActions()
        check("Esc goes back to the results with the buffer kept", lm.actions == nil && lm.buffer.items.count == 2)
        _ = option(124, right)
        if let copy = lm.actions?.items.firstIndex(of: .action(.copyPath)) { lm.runAction(at: copy) }
        check("the action runs on every item", ran.last.map { titles($0.1) } == ["a.txt", "b.txt"], "\(ran.last.map { titles($0.1) } ?? [])")
        check("and then the buffer is empty", lm.buffer.isEmpty)

        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(400))
        _ = option(125, down)
        check("⌥⌫ empties the buffer", option(51, "\u{7f}") && lm.buffer.isEmpty)
        _ = option(126, up)
        launcher.hide()
        clock.value += FileBuffer.idle + 1
        launcher.show()
        check("5 minutes unused empties the buffer", lm.buffer.isEmpty)
        launcher.hide()

        lm.perform = { _, _ in true }
        lm.now = { ProcessInfo.processInfo.systemUptime }
        try? fm.removeItem(atPath: root)
    }
}
