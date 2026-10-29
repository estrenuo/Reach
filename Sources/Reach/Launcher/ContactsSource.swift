import AppKit
@preconcurrency import Contacts
import OSLog
import ReachKit

/// Settings > Contacts (S-024): searching contacts, the `email` keyword, and
/// how names show. Saved in `Store.settings`.
@Observable
final class ContactsSettings {
    static let shared = ContactsSettings()
    static let standardKeyword = "email"

    var isOn: Bool { didSet { save(isOn, "on") } }
    var emailOn: Bool { didSet { save(emailOn, "email.on") } }
    var emailKeyword: String { didSet { save(emailKeyword, "email.keyword") } }
    var lastFirst: Bool { didSet { save(lastFirst, "lastFirst") } }
    var showTitle: Bool { didSet { save(showTitle, "showTitle") } }
    var showJobTitle: Bool { didSet { save(showJobTitle, "showJobTitle") } }

    private init() {
        let defaults = Store.settings
        func flag(_ key: String, _ standard: Bool) -> Bool { defaults.object(forKey: "contacts." + key) as? Bool ?? standard }
        isOn = flag("on", true)
        emailOn = flag("email.on", true)
        emailKeyword = defaults.string(forKey: "contacts.email.keyword") ?? Self.standardKeyword
        lastFirst = flag("lastFirst", false)
        showTitle = flag("showTitle", false)
        showJobTitle = flag("showJobTitle", false)
    }

    private func save(_ value: Any, _ key: String) { Store.settings.set(value, forKey: "contacts." + key) }

    func name(_ contact: Contact) -> String { contact.name(lastFirst: lastFirst, showTitle: showTitle) }

    /// Back to the standard settings; the self-test leaves no trace this way.
    func reset() {
        isOn = true
        emailOn = true
        emailKeyword = Self.standardKeyword
        lastFirst = false
        showTitle = false
        showJobTitle = false
    }
}

/// Contacts by name, and `email <name>`: one row per address (S-024).
/// Return on a contact opens its card in the launcher.
final class ContactsSource: ResultSource {
    static let app = "/System/Applications/Contacts.app"
    static let icon = LaunchResult.Icon.file(app)
    static let maxContacts = 5
    static let allowAccess = "Allow Reach to see your contacts"
    static let privacySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts")
    let settings: ContactsSettings
    /// Reads every contact, or nil without access. It may ask for access the
    /// first time. Snapshots and the self-test swap in samples.
    var loader: @MainActor (@escaping @MainActor ([Contact]?) -> Void) -> Void = ContactsLoader.load
    /// The contacts, read once and again after Contacts changes; nil before the first read.
    private(set) var contacts: [Contact]?
    private(set) var denied = false
    private var loading = false
    /// True while the loader runs inside `read`: an answer then is used at once.
    private var inline = false
    private var waiting: (@MainActor ([Scored]) -> Void, QueryKind)?
    private var observer: Any?

    init(settings: ContactsSettings = .shared) {
        self.settings = settings
        observer = NotificationCenter.default.addObserver(forName: .CNContactStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.forget() }
        }
    }

    /// Drops the read contacts; the next query reads them again.
    func forget() {
        contacts = nil
        denied = false
    }

    /// Takes these contacts instead of reading them (snapshots, the self-test).
    func use(_ contacts: [Contact]?) {
        self.contacts = contacts ?? []
        denied = contacts == nil
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        let keyword = settings.emailKeyword
        let email = settings.emailOn ? emailWords(text, keyword: keyword) : nil
        let offered = email == nil && settings.emailOn ? offer(text, keyword: keyword) : []
        guard email != nil || (settings.isOn && text.count >= 2) else { return offered }
        // A typed address needs no contacts.
        if let email, ContactField.isEmailAddress(email), let url = ContactField.mailURL(to: email) {
            return [Scored(result: LaunchResult(id: "email:\(email)", title: "Email \(email)", subtitle: "Start an email",
                                                icon: .symbol("envelope"), url: url, kindLabel: "Email", isPinned: true), score: 0)]
        }
        if contacts == nil {
            waiting = (later, query)
            read()
        }
        guard let contacts else { return nil }
        waiting = nil
        if let email { return emailRows(email, in: contacts) }
        return offered + matches(text, in: contacts).prefix(Self.maxContacts).map { contact, score in
            Scored(result: row(for: contact), score: score)
        }
    }

    func cancel() { waiting = nil }

    private func read() {
        guard !loading else { return }
        loading = true
        inline = true
        defer { inline = false }
        loader { [weak self] read in
            guard let self else { return }
            loading = false
            use(read)
            // An answer at once is used by `results` itself; `later` must wait until it returned.
            guard !inline, let (later, query) = waiting else { return }
            waiting = nil
            later(results(for: query) { _ in } ?? [])
        }
    }

    /// The words after `email`; empty for the keyword alone; nil for other queries.
    /// The query comes trimmed, so `email ` arrives as the keyword alone.
    private func emailWords(_ text: String, keyword: String) -> String? {
        text.lowercased() == keyword.lowercased() ? "" : DictionaryLookup.word(in: text, keyword: keyword)
    }

    /// Part of the keyword (`ema`): a row that completes to `email `.
    private func offer(_ text: String, keyword: String) -> [Scored] {
        guard text.count >= 2, text.count < keyword.count, keyword.lowercased().hasPrefix(text.lowercased()),
              let score = Matcher.score(query: text, title: keyword), score >= SystemCommands.minimumScore else { return [] }
        return [Scored(result: LaunchResult(id: "contacts:email", title: "Email a Contact…", subtitle: "Press ↩ to type a name",
                                            icon: .symbol("envelope"), url: nil, kindLabel: "Email",
                                            completes: keyword + " "), score: score)]
    }

    private func matches(_ text: String, in contacts: [Contact]) -> [(Contact, Int)] {
        contacts.compactMap { contact -> (Contact, Int)? in
            let score = [Matcher.score(query: text, title: settings.name(contact)),
                         Matcher.score(query: text, title: contact.searchText)].compactMap { $0 }.max()
            return score.map { (contact, $0) }
        }.sorted { $0.1 > $1.1 }
    }

    private func emailRows(_ words: String, in contacts: [Contact]) -> [Scored] {
        guard !denied else { return [hint(Self.allowAccess, subtitle: "System Settings > Privacy & Security > Contacts",
                                          url: Self.privacySettings)] }
        guard !words.isEmpty else { return [hint("Type a name to email")] }
        let rows = matches(words, in: contacts).flatMap { contact, _ in
            contact.emails.compactMap { field -> LaunchResult? in
                guard let url = ContactField.mailURL(to: field.value) else { return nil }
                let label = field.label.isEmpty ? "" : " (\(field.label))"
                return LaunchResult(id: "email:\(contact.id):\(field.value)", title: "Email \(settings.name(contact))",
                                    subtitle: field.value + label, icon: Self.icon, url: url, kindLabel: "Email",
                                    isPinned: true)
            }
        }
        guard !rows.isEmpty else { return [hint("No contact named “\(words)” has an email address")] }
        return rows.prefix(LauncherModel.maxResults).map { Scored(result: $0, score: 0) }
    }

    func row(for contact: Contact) -> LaunchResult {
        LaunchResult(id: "contact:\(contact.id)", title: settings.name(contact),
                     subtitle: contact.subtitle(showJobTitle: settings.showJobTitle), icon: Self.icon,
                     url: Self.contactsURL(contact), kindLabel: "Contact", contact: contact)
    }

    private func hint(_ title: String, subtitle: String = "", url: URL? = nil) -> Scored {
        Scored(result: LaunchResult(id: "hint:contacts", title: title, subtitle: subtitle, icon: Self.icon, url: url), score: 0)
    }

    /// Opens the contact in Contacts.app.
    static func contactsURL(_ contact: Contact) -> URL? {
        contact.id.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed).flatMap { URL(string: "addressbook://\($0)") }
    }
}

/// Reads the address book. Names, numbers and addresses never go to the log.
nonisolated enum ContactsLoader {
    static let log = Logger(subsystem: "com.sanderrobijns.reach", category: "contacts")

    static var status: CNAuthorizationStatus { CNContactStore.authorizationStatus(for: .contacts) }
    static var hasAccess: Bool { status == .authorized }

    /// Asks for access the first time, then reads off the main thread.
    static func load(_ done: @escaping @MainActor ([Contact]?) -> Void) {
        let store = CNContactStore()
        switch status {
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                log.notice("contacts access \(granted ? "granted" : "refused", privacy: .public)")
                guard granted else { Task { @MainActor in done(nil) }; return }
                read(store, done)
            }
        case .authorized:
            read(store, done)
        default:
            Task { @MainActor in done(nil) }
        }
    }

    private static func read(_ store: CNContactStore, _ done: @escaping @MainActor ([Contact]?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let keys: [CNKeyDescriptor] = [CNContactIdentifierKey, CNContactNamePrefixKey, CNContactGivenNameKey,
                                           CNContactMiddleNameKey, CNContactFamilyNameKey, CNContactNameSuffixKey,
                                           CNContactNicknameKey, CNContactOrganizationNameKey, CNContactJobTitleKey,
                                           CNContactEmailAddressesKey, CNContactPhoneNumbersKey, CNContactUrlAddressesKey,
                                           CNContactPostalAddressesKey, CNContactBirthdayKey].map { $0 as CNKeyDescriptor }
            var contacts: [Contact] = []
            do {
                try store.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, _ in
                    contacts.append(plain(contact))
                }
            } catch {
                log.error("contacts read failed: \((error as NSError).code, privacy: .public)")
            }
            log.notice("read \(contacts.count, privacy: .public) contacts")
            let read = contacts
            Task { @MainActor in done(read) }
        }
    }

    private static func plain(_ contact: CNContact) -> Contact {
        func label(_ raw: String?) -> String { raw.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? "" }
        let formatter = CNPostalAddressFormatter()
        var fields = contact.emailAddresses.map { ContactField(.email, label: label($0.label), value: $0.value as String) }
        fields += contact.phoneNumbers.map { ContactField(.phone, label: label($0.label), value: $0.value.stringValue) }
        fields += contact.urlAddresses.map { ContactField(.url, label: label($0.label), value: $0.value as String) }
        fields += contact.postalAddresses.map { ContactField(.address, label: label($0.label), value: formatter.string(from: $0.value)) }
        if let birthday = contact.birthday, let date = Calendar.current.date(from: birthday) {
            // A birthday without a year shows only the day and month.
            let style: Date.FormatStyle = birthday.year == nil ? .dateTime.day().month(.wide) : .dateTime.day().month(.wide).year()
            fields.append(ContactField(.birthday, label: "birthday", value: date.formatted(style)))
        }
        return Contact(id: contact.identifier, namePrefix: contact.namePrefix, givenName: contact.givenName,
                       middleName: contact.middleName, familyName: contact.familyName, nameSuffix: contact.nameSuffix,
                       nickname: contact.nickname, organization: contact.organizationName, jobTitle: contact.jobTitle,
                       fields: fields)
    }
}
