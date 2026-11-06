import ReachKit
import SwiftUI

/// Settings > Music (S-059): the music keywords, each with a checkbox and
/// its keyword, whether they show among the other results, and Automation.
struct MusicSettingsView: View {
    @Bindable private var settings = MusicSettings.shared
    @State private var access = MusicAccess.unknown

    var body: some View {
        Section {
            ForEach(MusicCommand.allCases, id: \.self) { command in
                MusicKeywordRow(command: command, settings: settings)
            }
        } header: {
            Text("Keywords")
        } footer: {
            Text("Type a keyword in the launcher and press Return: “next” skips the song, “volume 30” sets Music's volume. Music does it while you stay in your app.")
                .foregroundStyle(.secondary)
        }
        Section {
            Toggle(isOn: $settings.showsInDefaultResults) {
                Text("Show in default results")
                Text("Part of a keyword or a name, like “nex”, finds a music command among the other results.")
            }
        }
        Section {
            LabeledContent {
                if access == .denied {
                    Button("Open System Settings…") {
                        if let url = MusicPlayer.automationSettings { NSWorkspace.shared.open(url) }
                    }
                }
            } label: {
                Text("Automation")
                Text(accessText)
            }
        } header: {
            Text("Access")
        }
        .onAppear { access = AppModel.isTestRun ? .unknown : MusicPlayer.checkAccess() }
    }

    private var accessText: String {
        if AppModel.isTestRun { return "Test runs never send commands to Music." }
        switch access {
        case .allowed: return "Reach can control Music."
        case .denied: return "Turned off. Allow Reach to control Music in Privacy & Security > Automation."
        case .unknown: return "macOS asks the first time you send a command to Music."
        }
    }
}

/// One music command: a checkbox with its name and the keyword field.
private struct MusicKeywordRow: View {
    let command: MusicCommand
    @Bindable var settings: MusicSettings
    @State private var draft = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    private var isOn: Binding<Bool> {
        Binding(get: { settings[command].isOn }, set: { settings[command].isOn = $0 })
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Toggle(command.title, isOn: isOn)
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
                    .accessibilityLabel("Keyword for \(command.title)")
                if let problem {
                    Text(problem)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { draft = settings[command].keyword }
        .onChange(of: focused) { _, now in if !now { save() } }
    }

    private func save() {
        let word = draft.trimmingCharacters(in: .whitespaces).lowercased()
        problem = MusicKeywords.problem(keyword: word, for: command, in: settings.keywords, taken: WebSearchSettings.shared.taken)
        guard problem == nil else { return }
        draft = word
        settings[command].keyword = word
    }

    private func revert() {
        draft = settings[command].keyword
        problem = nil
    }
}
