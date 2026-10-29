import ReachKit
import SwiftUI

/// Settings > System (S-019): every system command with a checkbox, its
/// keyword, and Confirm for the ones that can ask first.
struct SystemSettingsView: View {
    @Bindable private var settings = SystemSettings.shared

    var body: some View {
        group("Commands", [.screenSaver, .showTrash, .emptyTrash, .logOut, .sleep, .sleepDisplays, .lock, .restart, .shutDown],
              footer: "Type a keyword to run the command. With Confirm on, Reach asks first: Return runs it, Esc cancels.")
        group("Sound", [.volumeUp, .volumeDown, .mute],
              footer: "Change the volume of your Mac from the launcher.")
        group("Disks", [.eject, .ejectAll],
              footer: "Eject lists each disk; type its name after the keyword to pick one. Wait for macOS to say a disk is ejected before you unplug it.")
    }

    private func group(_ title: String, _ commands: [SystemCommand], footer: String) -> some View {
        Section {
            ForEach(commands, id: \.self) { command in
                CommandRow(command: command, settings: settings)
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
                .foregroundStyle(.secondary)
        }
    }
}

/// One command: a checkbox with its name, the keyword field, and Confirm.
/// Commands that cannot ask keep the column empty, so the fields line up.
private struct CommandRow: View {
    let command: SystemCommand
    @Bindable var settings: SystemSettings
    @State private var draft = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Toggle(command.title, isOn: $settings[command].isOn)
                .toggleStyle(.checkbox)
                .help(command.help)
            Spacer()
            VStack(alignment: .trailing, spacing: Space.xs) {
                TextField("Keyword", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 120)
                    .focused($focused)
                    .disabled(!settings[command].isOn)
                    .onSubmit(save)
                    .onExitCommand(perform: revert)
                    .accessibilityLabel("Keyword for \(command.title)")
                if let problem {
                    Text(problem)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Group {
                if command.canConfirm {
                    Toggle("Confirm", isOn: $settings[command].confirms)
                        .toggleStyle(.checkbox)
                        .disabled(!settings[command].isOn)
                        .help("Ask before Reach runs \(command.title)")
                        .accessibilityLabel("Confirm \(command.title)")
                } else {
                    Color.clear.frame(height: 1)
                }
            }
            .frame(width: 84, alignment: .leading)
        }
        .onAppear { draft = settings[command].keyword }
        .onChange(of: focused) { _, now in if !now { save() } }
    }

    private func save() {
        let word = draft.trimmingCharacters(in: .whitespaces).lowercased()
        problem = SystemCommands.problem(keyword: word, for: command, in: settings.commands,
                                         taken: WebSearchSettings.shared.taken)
        guard problem == nil else { return }
        draft = word
        settings[command].keyword = word
    }

    private func revert() {
        draft = settings[command].keyword
        problem = nil
    }
}
