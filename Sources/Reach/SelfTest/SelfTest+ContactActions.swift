import AppKit
import ReachKit

extension SelfTest {
    /// Custom actions for the self-test and snapshots (S-058).
    static let sampleContactActions = [
        ContactAction(id: "sample-facetime", kind: .phone, title: "Call with FaceTime", url: "facetime://{query}", modifier: .option),
        ContactAction(id: "sample-whatsapp", kind: .phone, title: "Message on WhatsApp", url: "https://wa.me/{query}"),
        ContactAction(id: "sample-gmail", kind: .email, title: "Write in Gmail",
                      url: "https://mail.google.com/mail/?view=cm&to={query}", modifier: .control),
    ]

    /// S-058: in a card, ↩ still does the built-in action, the modifier runs
    /// the custom action, and → lists the detail's actions. Real keys go
    /// through the launcher; every URL is recorded, never opened. Sample contacts only.
    static func checkContactActions(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let source = lm.contacts
        let settings = ContactsSettings.shared
        var opened: [URL] = []
        var copied: [String] = []
        let (opener, copier, loader) = (lm.opener, lm.copier, source.loader)
        lm.opener = { opened.append($0); return true }
        lm.copier = { copied.append($0) }
        source.use(sampleContacts)
        settings.actions = sampleContactActions
        defer {
            settings.reset()
            (lm.opener, lm.copier, source.loader) = (opener, copier, loader)
            source.forget()
        }
        func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags = []) -> Bool {
            var flags = flags
            if (123...126).contains(code) { flags.formUnion([.numericPad, .function]) }
            let chars = ["\r", "\u{F702}", "\u{F703}", "\u{F701}", "\u{F700}"][[36, 123, 124, 125, 126].firstIndex(of: code) ?? 0]
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: launcher.panel.windowNumber,
                    context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false,
                    keyCode: code) else { return false }
            return launcher.handle(event)
        }
        /// The card for Sander, with the detail at `row` selected (2 is the phone number).
        func card(at row: Int) async {
            await showAgain(launcher)
            lm.query = "sander"
            _ = lm.showActions()
            lm.actions?.select(row)
        }

        await card(at: 2)
        check("the footer names the detail's modifier",
              lm.actions?.footer.hasSuffix("⌥↩ Call with FaceTime") == true, lm.actions?.footer ?? "no card")
        _ = key(36)
        check("↩ on a phone number still copies it", copied.last == "+31 6 1234 5678" && opened.isEmpty && !launcher.isVisible)

        await card(at: 2)
        _ = key(36, .option)
        check("⌥↩ runs the custom action, the number encoded once",
              opened.last?.absoluteString == "facetime://%2B31612345678" && !launcher.isVisible,
              opened.last?.absoluteString ?? "nothing opened")

        await card(at: 0)
        _ = key(36, .control)
        check("⌃↩ on an email address runs its own action",
              opened.last?.absoluteString == "https://mail.google.com/mail/?view=cm&to=sander@example.com")

        await card(at: 0)
        let before = opened.count
        _ = key(36, .option)
        check("a modifier without an action does the built-in action",
              opened.count == before + 1 && opened.last?.absoluteString == "mailto:sander@example.com")

        await card(at: 2)
        _ = key(124)
        check("→ lists the detail's actions, the built-in one first",
              lm.actions?.rows.map(\.title) == ["Copy the phone number", "Call with FaceTime", "Message on WhatsApp"]
                && lm.actions?.rows[1].badge == "⌥↩",
              lm.actions?.rows.map(\.title).joined(separator: ", ") ?? "no list")
        lm.actions?.filter = "whats"
        check("typing filters the actions", lm.actions?.rows.map(\.title) == ["Message on WhatsApp"])
        _ = key(36)
        check("↩ in the list runs the selected action", opened.last?.absoluteString == "https://wa.me/%2B31612345678"
              && !launcher.isVisible)

        await card(at: 2)
        _ = key(124)
        _ = key(123)
        check("← goes back to the card, the detail still selected",
              lm.actions?.detailActions == nil && lm.actions?.selection == 2 && launcher.isVisible)
        _ = key(124)
        lm.actions?.select(1)
        lm.cancelActions()
        check("Esc goes back to the card too", lm.actions?.detailActions == nil && lm.actions?.contact != nil)

        await card(at: 5)
        _ = key(124)
        check("a birthday lists only its built-in action", lm.actions?.rows.map(\.title) == ["Copy the birthday"])
        lm.cancelActions()

        settings.actions = [ContactAction(kind: .phone, title: "Broken", url: "facetime://{query}", modifier: .option)]
        await card(at: 2)
        let failing = lm.opener
        lm.opener = { _ in false }
        _ = key(36, .option)
        check("a failing action says so in the card", lm.actions?.failure == "Unable to run “Broken”." && launcher.isVisible)
        lm.opener = failing

        // Saved with the other contact settings.
        settings.actions = []
        settings.save(sampleContactActions[0])
        settings.save(ContactAction(id: "sample-facetime", kind: .phone, title: "FaceTime", url: "facetime://{query}"))
        let stored = Store.settings.data(forKey: "contacts.actions")
            .flatMap { try? JSONDecoder().decode([ContactAction].self, from: $0) }
        check("an edited action replaces the old one and is saved", stored?.map(\.title) == ["FaceTime"])
        settings.removeAction("sample-facetime")
        check("− removes it", settings.actions.isEmpty)
        launcher.hide()
    }
}
