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
        CustomActionsSection(settings: settings)
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

/// Custom Actions (S-058): Detail | Action | Modifier, with + and − under it.
/// Double-click or Edit… opens the sheet.
private struct CustomActionsSection: View {
    @Bindable var settings: ContactsSettings
    @State private var selected: String?

    var body: some View {
        Section {
            if settings.actions.isEmpty {
                Text("No custom actions")
                    .foregroundStyle(.secondary)
            } else {
                ActionColumns(detail: Text("Detail"), action: Text("Action"), modifier: Text("Modifier"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            ForEach(settings.actions) { action in
                ActionColumns(detail: Text(action.kind.name),
                              action: Text(action.title).help(action.url),
                              modifier: Text(action.modifier?.symbol ?? "None").foregroundStyle(action.modifier == nil ? .secondary : .primary))
                    .contentShape(Rectangle())
                    .listRowBackground(selected == action.id ? Color.accentColor.opacity(0.2) : nil)
                    .onTapGesture(count: 2) { settings.editingAction = action }
                    .onTapGesture { selected = action.id }
                    .contextMenu {
                        Button("Edit…") { settings.editingAction = action }
                        Button("Remove") { remove(action.id) }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(action.kind.name), \(action.title), \(action.modifier?.symbol ?? "no modifier")")
                    .accessibilityAddTraits(selected == action.id ? .isSelected : [])
                    .accessibilityAction(named: "Edit") { settings.editingAction = action }
            }
            HStack(spacing: 0) {
                Button {
                    settings.editingAction = ContactAction(kind: .phone, title: "", url: "")
                } label: {
                    Image(systemName: "plus").frame(width: Space.xl, height: Space.xl)
                }
                .help("Add a custom action")
                .accessibilityLabel("Add a custom action")
                Button {
                    if let selected { remove(selected) }
                } label: {
                    Image(systemName: "minus").frame(width: Space.xl, height: Space.xl)
                }
                .disabled(!settings.actions.contains { $0.id == selected })
                .help("Remove the selected custom action")
                .accessibilityLabel("Remove the selected custom action")
                Spacer()
            }
            .buttonStyle(.borderless)
        } header: {
            Text("Custom Actions")
        } footer: {
            Text("Your own actions on a card’s details, like Call with FaceTime. In the card, Return still does the usual action; the modifier runs yours, and → lists them all. Double-click an action to change it.")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(settings.actions.isEmpty ? "Custom Actions, empty" : "Custom Actions")
        .sheet(item: $settings.editingAction) { action in
            CustomActionSheet(action: action, isNew: !settings.actions.contains { $0.id == action.id },
                              others: settings.actions) { saved in
                settings.save(saved)
                selected = saved.id
            }
        }
    }

    private func remove(_ id: String) {
        settings.removeAction(id)
        if selected == id { selected = nil }
    }
}

/// The three columns of the Custom Actions table, header and rows alike.
private struct ActionColumns<Detail: View, Action: View, Modifier: View>: View {
    let detail: Detail
    let action: Action
    let modifier: Modifier

    var body: some View {
        HStack(spacing: Space.sm) {
            detail
                .frame(width: 88, alignment: .leading)
            action
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            modifier
                .frame(width: 64, alignment: .leading)
        }
    }
}

/// Add Custom Action, or Edit Custom Action for one that exists. The problem
/// shows under the fields after Add.
private struct CustomActionSheet: View {
    let action: ContactAction
    let isNew: Bool
    let others: [ContactAction]
    let save: (ContactAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind = ContactField.Kind.phone
    @State private var title = ""
    @State private var url = ""
    @State private var modifier: ReturnModifier?
    @State private var tried = false

    private var draft: ContactAction {
        ContactAction(id: action.id, kind: kind, title: title.trimmingCharacters(in: .whitespaces),
                      url: url.trimmingCharacters(in: .whitespaces), modifier: modifier)
    }

    private var problem: String? { ContactAction.problem(draft, others: others) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text(isNew ? "Add Custom Action" : "Edit Custom Action")
                .font(.headline)
            Form {
                Picker("Detail", selection: $kind) {
                    ForEach(ContactAction.kinds, id: \.self) { Text($0.name).tag($0) }
                }
                TextField("Title", text: $title, prompt: Text("Call with FaceTime"))
                TextField("URL", text: $url, prompt: Text("facetime://{query}"))
                Picker("Modifier", selection: $modifier) {
                    Text("None").tag(ReturnModifier?.none)
                    ForEach(ContactAction.modifiers) { Text($0.symbol).tag(ReturnModifier?.some($0)) }
                }
            }
            .formStyle(.columns)
            Text("Put {query} in the URL where the detail goes; Reach encodes it for you. Phone numbers lose their spaces and dashes.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if tried, let problem {
                Text(problem)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    tried = true
                    guard problem == nil else { return }
                    save(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.xl)
        .frame(width: 440)
        .noInitialFocus()
        .onAppear {
            kind = action.kind
            title = action.title
            url = action.url
            modifier = action.modifier
        }
    }
}
