import AppKit
import ReachKit

extension SelfTest {
    /// Sample contacts for the self-test and snapshots: never the person's own.
    static let sampleContacts = [
        Contact(id: "sample-sander", namePrefix: "Mr", givenName: "Sander", familyName: "Robijns",
                organization: "Esforzado", jobTitle: "Architect",
                fields: [ContactField(.email, label: "work", value: "sander@example.com"),
                         ContactField(.email, label: "home", value: "sander.home@example.org"),
                         ContactField(.phone, label: "mobile", value: "+31 6 1234 5678"),
                         ContactField(.url, label: "homepage", value: "example.com"),
                         ContactField(.address, label: "work", value: "Damrak 1\n1012 LG Amsterdam"),
                         ContactField(.birthday, label: "birthday", value: "12 March")]),
        Contact(id: "sample-ada", givenName: "Ada", familyName: "Lovelace", organization: "Analytical Engines",
                fields: [ContactField(.email, label: "work", value: "ada@example.com")]),
        Contact(id: "sample-acme", organization: "Acme Studio",
                fields: [ContactField(.phone, label: "work", value: "+31 20 123 4567")]),
    ]

    /// S-024: a name finds the contact, Return shows its card in the launcher,
    /// and Return on a detail emails, opens, maps or copies it. `email <name>`
    /// lists each address. The contacts are samples, so no Mac's own are read.
    static func checkContacts(model: AppModel) async {
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
        defer {
            settings.reset()
            (lm.opener, lm.copier, source.loader) = (opener, copier, loader)
            source.forget()
        }

        launcher.show()
        lm.query = "sand"
        let first = lm.results.first
        check("a name finds the contact, with the company under it",
              first?.title == "Sander Robijns" && first?.subtitle == "Esforzado" && first?.contact != nil,
              lm.results.map(\.title).joined(separator: ", "))
        lm.query = "esforz"
        check("the company finds the contact too", lm.results.first?.id == "contact:sample-sander")
        settings.lastFirst = true
        settings.showTitle = true
        settings.showJobTitle = true
        lm.query = "sander"
        check("the name follows Settings: last name first, with the title and job title",
              lm.results.first?.title == "Mr Robijns Sander" && lm.results.first?.subtitle == "Architect, Esforzado",
              "\(lm.results.first?.title ?? "-") / \(lm.results.first?.subtitle ?? "-")")
        settings.reset()

        lm.query = "sander rob"
        lm.openSelected()
        let card = lm.actions
        check("↩ on a contact shows its card in the launcher", card?.contact?.id == "sample-sander" && launcher.isVisible)
        check("the card lists every detail, then Open in Contacts",
              card?.rows.map(\.title) == ["sander@example.com", "sander.home@example.org", "+31 6 1234 5678", "example.com",
                                          "Damrak 1, 1012 LG Amsterdam", "12 March", ActionPanel.openInContacts]
                && card?.rows.first?.badge == "work",
              card?.rows.map(\.title).joined(separator: " | ") ?? "no card")
        lm.runAction(at: 0)
        check("↩ on an email address starts an email", opened.last?.absoluteString == "mailto:sander@example.com" && !launcher.isVisible)

        func reopenCard() {
            launcher.show()
            lm.query = "sander"
            _ = lm.showActions()
        }
        reopenCard()
        lm.runAction(at: 2)
        check("↩ on a phone number copies it", copied.last == "+31 6 1234 5678" && !launcher.isVisible)
        reopenCard()
        lm.runAction(at: 3)
        check("↩ on a website opens it", opened.last?.absoluteString == "https://example.com")
        reopenCard()
        lm.runAction(at: 4)
        check("↩ on an address shows it in Maps", opened.last?.absoluteString.hasPrefix(ContactField.mapsBase) == true)
        reopenCard()
        lm.actions?.select(1)
        check("⌘C copies the selected detail", lm.copySelectedField() && copied.last == "sander.home@example.org")
        reopenCard()
        lm.actions?.filter = "mob"
        check("typing filters the details", lm.actions?.rows.map(\.title) == ["+31 6 1234 5678"],
              lm.actions?.rows.map(\.title).joined(separator: ", ") ?? "")
        lm.cancelActions()
        lm.cancelActions()
        check("Esc goes back to the results, query kept", lm.actions == nil && lm.query == "sander" && launcher.isVisible)
        check("⌘O opens the contact in Contacts", lm.openInContacts() && opened.last?.absoluteString == "addressbook://sample-sander")

        launcher.show()
        lm.query = "email sander"
        check("email and a name lists each address, first",
              lm.results.prefix(2).map(\.subtitle) == ["sander@example.com (work)", "sander.home@example.org (home)"]
                && lm.results.first?.title == "Email Sander Robijns",
              lm.results.map(\.subtitle).joined(separator: ", "))
        lm.select(1)
        lm.openSelected()
        check("↩ starts the email to that address", opened.last?.absoluteString == "mailto:sander.home@example.org")
        launcher.show()
        lm.query = "email a.b+c@example.com"
        check("email and an address starts an email to it", lm.results.first?.url?.absoluteString == "mailto:a.b%2Bc@example.com")
        lm.query = "email "
        check("the keyword alone asks for a name", lm.results.first?.title == "Type a name to email")
        lm.query = "email acme"
        check("a contact without an address says so",
              lm.results.first?.title == "No contact named “acme” has an email address")
        lm.query = "ema"
        let offer = lm.results.firstIndex { $0.id == "contacts:email" }
        check("part of the keyword offers “Email a Contact…”", offer != nil)
        if let offer { lm.open(at: offer) }
        check("↩ completes it to “email ”", lm.query == "email ")

        settings.emailKeyword = "mail"
        lm.query = "mail ada"
        check("a changed keyword works", lm.results.first?.subtitle == "ada@example.com (work)")
        settings.reset()
        settings.isOn = false
        lm.query = "lovelace"
        check("with Search contacts off, a name finds no contact", !lm.results.contains { $0.contact != nil })
        settings.reset()

        source.use(nil)
        lm.query = "email sander"
        check("without access, email says how to allow it", lm.results.first?.title == ContactsSource.allowAccess
              && lm.results.first?.url == ContactsSource.privacySettings)
        lm.query = "sanders"
        check("without access, a name finds no contact", !lm.results.contains { $0.contact != nil })

        // The first query reads the contacts; the results follow once they are in.
        source.forget()
        var reads = 0
        source.loader = { done in reads += 1; DispatchQueue.main.async { done(sampleContacts) } }
        lm.query = "lovel"
        for _ in 0..<50 where !lm.results.contains(where: { $0.contact != nil }) { try? await Task.sleep(for: .milliseconds(20)) }
        check("the first search reads the contacts, then shows them", lm.results.first?.title == "Ada Lovelace" && reads == 1,
              lm.results.map(\.title).joined(separator: ", "))
        lm.query = "lovela"
        check("later searches use what was read", reads == 1 && lm.results.first?.title == "Ada Lovelace")
        launcher.hide()
    }
}
