import Contacts
import ReachKit
import SwiftUI

/// Settings > Contacts (S-024): searching contacts and access to them, the
/// `email` keyword, and how names show, as on Alfred's Contacts pages.
struct ContactsSettingsView: View {
    @Bindable private var settings = ContactsSettings.shared
    @State private var status = ContactsLoader.status

    var body: some View {
        Section {
            Toggle(isOn: $settings.isOn) {
                Text("Search contacts")
                Text("Type a name to find a person. Return shows their card in the launcher, ⌘O opens it in Contacts.")
            }
            LabeledContent {
                if status != .authorized && status != .notDetermined {
                    Button("Open System Settings…") {
                        if let url = ContactsSource.privacySettings { NSWorkspace.shared.open(url) }
                    }
                }
            } label: {
                Text("Access")
                Text(accessText)
            }
        } header: {
            Text("Contacts")
        } footer: {
            Text("In a card, Return starts an email, opens a website, or shows an address in Maps, and copies anything else. ⌘C copies any detail.")
                .foregroundStyle(.secondary)
        }
        Section {
            EmailKeywordRow(settings: settings)
        } header: {
            Text("Email")
        } footer: {
            Text("Type the keyword and a name or an address: “email sander” lists each of their addresses, and Return starts an email in your mail app.")
                .foregroundStyle(.secondary)
        }
        Section("Names") {
            Toggle(isOn: $settings.lastFirst) {
                Text("Show last name first")
                Text("Robijns Sander instead of Sander Robijns.")
            }
            Toggle(isOn: $settings.showTitle) {
                Text("Show title")
                Text("For example, Mr or Dr.")
            }
            Toggle(isOn: $settings.showJobTitle) {
                Text("Show job title")
                Text("Under the name, before the company.")
            }
        }
        .onAppear { status = ContactsLoader.status }
    }

    private var accessText: String {
        if AppModel.isTestRun { return "Test runs use sample contacts." }
        switch status {
        case .authorized: return "Reach can see your contacts."
        case .notDetermined: return "Reach asks the first time you search."
        default: return "Allow Reach in System Settings > Privacy & Security > Contacts."
        }
    }
}

/// The `email` keyword: a checkbox and the keyword field, checked like the dictionary's.
private struct EmailKeywordRow: View {
    @Bindable var settings: ContactsSettings
    @State private var draft = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Toggle("Email a Contact", isOn: $settings.emailOn)
                .toggleStyle(.checkbox)
            Spacer()
            VStack(alignment: .trailing, spacing: Space.xs) {
                TextField("Keyword", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 120)
                    .focused($focused)
                    .disabled(!settings.emailOn)
                    .onSubmit(save)
                    .onExitCommand(perform: revert)
                    .accessibilityLabel("Keyword for Email a Contact")
                if let problem {
                    Text(problem)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { draft = settings.emailKeyword }
        .onChange(of: focused) { _, now in if !now { save() } }
    }

    private func save() {
        let word = draft.trimmingCharacters(in: .whitespaces).lowercased()
        var taken = WebSearchSettings.shared.taken.filter { $0.value != "Email a Contact" }
        for command in SystemSettings.shared.commands where command.isOn {
            taken[command.keyword.lowercased()] = command.command.title
        }
        problem = DictionaryLookup.problem(keyword: word, other: "", taken: taken)
        guard problem == nil else { return }
        draft = word
        settings.emailKeyword = word
    }

    private func revert() {
        draft = settings.emailKeyword
        problem = nil
    }
}
