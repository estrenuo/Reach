import ReachKit
import SwiftUI

/// Settings > Dictionary (S-022): the spelling language, and the keywords
/// for Define a Word and Spell a Word, as on Alfred's Dictionary page.
struct DictionarySettingsView: View {
    @Bindable private var settings = DictionarySettings.shared

    var body: some View {
        Section {
            Picker("Spelling language", selection: $settings.language) {
                ForEach(DictionarySettings.languages, id: \.id) { Text($0.name).tag($0.id) }
            }
        } footer: {
            Text("Spell suggests words in this language. Definitions come from the dictionaries ticked in Dictionary.app.")
                .foregroundStyle(.secondary)
        }
        Section {
            LookupRow(mode: .define, settings: settings)
            LookupRow(mode: .spell, settings: settings)
        } header: {
            Text("Keywords")
        } footer: {
            Text("Type a keyword and a word: “define serendipity” shows what it means, and Return opens it in Dictionary.app. “spell recieve” suggests spellings: Return copies one, ⌘↩ pastes it.")
                .foregroundStyle(.secondary)
        }
    }
}

/// One lookup: a checkbox with its name and the keyword field.
private struct LookupRow: View {
    let mode: DictionaryLookup.Mode
    @Bindable var settings: DictionarySettings
    @State private var draft = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    private var isOn: Binding<Bool> {
        Binding(get: { settings.isOn[mode] ?? true }, set: { settings.isOn[mode] = $0 })
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Toggle(mode.title, isOn: isOn)
                .toggleStyle(.checkbox)
            Spacer()
            VStack(alignment: .trailing, spacing: Space.xs) {
                TextField("Keyword", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 120)
                    .focused($focused)
                    .disabled(!isOn.wrappedValue)
                    .onSubmit(save)
                    .onExitCommand(perform: revert)
                    .accessibilityLabel("Keyword for \(mode.title)")
                if let problem {
                    Text(problem)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { draft = settings.keyword(mode) }
        .onChange(of: focused) { _, now in if !now { save() } }
    }

    private func save() {
        let word = draft.trimmingCharacters(in: .whitespaces).lowercased()
        let other: DictionaryLookup.Mode = mode == .define ? .spell : .define
        // Every keyword in use but this lookup's own, which `taken` lists too.
        var taken = WebSearchSettings.shared.taken.filter { $0.value != mode.title }
        for command in SystemSettings.shared.commands where command.isOn {
            taken[command.keyword.lowercased()] = command.command.title
        }
        problem = DictionaryLookup.problem(keyword: word, other: settings.keyword(other), taken: taken)
        guard problem == nil else { return }
        draft = word
        settings.keywords[mode] = word
    }

    private func revert() {
        draft = settings.keyword(mode)
        problem = nil
    }
}
