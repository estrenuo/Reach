import ReachKit
import SwiftUI

/// Settings > Music, as Alfred's Music pages: General has the mini player
/// (S-060) and access; Keywords has the music keywords (S-059).
struct MusicSettingsView: View {
    @Bindable private var settings = MusicSettings.shared

    var body: some View {
        Section {
            Picker("Page", selection: $settings.page) {
                ForEach(MusicSettings.Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        switch settings.page {
        case .general: MusicGeneralSettings(settings: settings)
        case .keywords: MusicKeywordSettings(settings: settings)
        }
    }
}

/// Music > General: the mini player's hotkey, keyword and options, which
/// songs it lists, and what macOS lets Reach do.
private struct MusicGeneralSettings: View {
    @Bindable var settings: MusicSettings
    @State private var access = MusicAccess.unknown

    private func include(_ path: WritableKeyPath<MusicLibrary.Include, Bool>) -> Binding<Bool> {
        Binding(get: { settings.include[keyPath: path] }, set: { settings.include[keyPath: path] = $0 })
    }

    var body: some View {
        Section {
            MiniPlayerHotkeyRow()
            MiniPlayerKeywordRow(settings: settings)
            LabeledContent("Random Album needs at least") {
                Stepper("\(settings.randomMinimum) songs", value: $settings.randomMinimum, in: MusicSettings.randomRange)
            }
            Toggle(isOn: $settings.hidesAfterChoosing) {
                Text("Hide after choosing")
                Text("The launcher hides when Return plays an album, artist, playlist or song.")
            }
        } header: {
            Text("Mini Player")
        } footer: {
            Text("Press the hotkey or type the keyword to browse your albums, artists and playlists in the launcher. → goes in, ← goes back, Return plays.")
                .foregroundStyle(.secondary)
        }
        Section("Include") {
            Toggle("Podcasts", isOn: include(\.podcasts))
            Toggle("Videos", isOn: include(\.videos))
            Toggle("Songs without album or artist", isOn: include(\.untagged))
        }
        Section {
            LabeledContent {
                if libraryDenied {
                    Button("Open System Settings…") {
                        if let url = MusicLibraryReader.privacySettings { NSWorkspace.shared.open(url) }
                    }
                }
            } label: {
                Text("Music library")
                Text(libraryText)
            }
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

    private var reader: MusicLibraryReader { AppModel.shared.launcherModel.music.library }
    private var libraryDenied: Bool { reader.state == .denied }

    private var libraryText: String {
        if AppModel.isTestRun { return "Test runs use a sample library." }
        switch reader.state {
        case .notRead, .reading: return "macOS asks the first time you open the mini player."
        case .denied: return "Turned off. Allow Reach in Privacy & Security > Media & Apple Music."
        case .ready(let library): return "Reach can read your library: \(MiniPlayerRows.count(library.songs.count, "song"))."
        }
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

/// Music > Keywords: one row per music command, and Show in default results.
private struct MusicKeywordSettings: View {
    @Bindable var settings: MusicSettings

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
    }
}

/// A keyword field that saves on Return or when it loses focus, with the
/// problem under it when the keyword will not do. Esc puts the old one back.
private struct KeywordField: View {
    let label: String
    let saved: String
    let enabled: Bool
    let problemFor: (String) -> String?
    let save: (String) -> Void
    @State private var draft = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: Space.xs) {
            TextField("Keyword", text: $draft)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .multilineTextAlignment(.leading)
                .frame(width: 120)
                .focused($focused)
                .disabled(!enabled)
                .onSubmit(commit)
                .onExitCommand {
                    draft = saved
                    problem = nil
                }
                .accessibilityLabel(label)
            if let problem {
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { draft = saved }
        .onChange(of: focused) { _, now in if !now { commit() } }
    }

    private func commit() {
        let word = draft.trimmingCharacters(in: .whitespaces).lowercased()
        problem = problemFor(word)
        guard problem == nil else { return }
        draft = word
        save(word)
    }
}

/// One music command: a checkbox with its name and the keyword field.
private struct MusicKeywordRow: View {
    let command: MusicCommand
    @Bindable var settings: MusicSettings

    private var isOn: Binding<Bool> {
        Binding(get: { settings[command].isOn }, set: { settings[command].isOn = $0 })
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Toggle(command.title, isOn: isOn)
                .toggleStyle(.checkbox)
            Spacer()
            KeywordField(label: "Keyword for \(command.title)", saved: settings[command].keyword, enabled: isOn.wrappedValue,
                         problemFor: { word in
                             var taken = WebSearchSettings.shared.taken
                             taken[settings.miniPlayerKeyword.lowercased()] = "the mini player"
                             return MusicKeywords.problem(keyword: word, for: command, in: settings.keywords, taken: taken)
                         },
                         save: { settings[command].keyword = $0 })
        }
    }
}

/// The mini player's keyword, `music` at first.
private struct MiniPlayerKeywordRow: View {
    @Bindable var settings: MusicSettings

    var body: some View {
        LabeledContent("Keyword") {
            KeywordField(label: "Keyword for the mini player", saved: settings.miniPlayerKeyword, enabled: true,
                         problemFor: { word in
                             var taken = WebSearchSettings.shared.taken
                             for keyword in settings.keywords where keyword.isOn { taken[keyword.keyword.lowercased()] = keyword.command.title }
                             return MusicKeywords.problem(keyword: word, for: .volume, in: [], taken: taken)
                         },
                         save: { settings.miniPlayerKeyword = $0 })
        }
    }
}

/// The mini player hotkey: click, press the keys; Esc keeps the old one, Clear removes it.
private struct MiniPlayerHotkeyRow: View {
    private var hotkeys = HotkeyCenter.shared
    @State private var recording = false
    @State private var error: String?
    @State private var monitor: Any?

    var body: some View {
        LabeledContent("Mini player hotkey") {
            VStack(alignment: .trailing, spacing: Space.xs) {
                HStack(spacing: Space.sm) {
                    Button(recording ? "Press a key combination" : hotkeys.miniPlayerDisplay ?? "Record Hotkey") {
                        recording ? stop() : start()
                    }
                    .frame(minWidth: 160)
                    .accessibilityLabel("Mini player hotkey, \(hotkeys.miniPlayerSpoken ?? "none")")
                    .help("Click, then press the new key combination. Esc keeps the current one.")
                    if hotkeys.miniPlayerCombo != nil, !recording {
                        Button("Clear") {
                            error = nil
                            hotkeys.changeMiniPlayer(to: nil, keyName: "")
                        }
                        .help("Remove the mini player hotkey")
                    }
                }
                if let error {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        error = nil
        recording = true
        hotkeys.suspendMiniPlayer()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 53, flags.isEmpty {
                stop()
                return nil
            }
            let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: HotkeyCenter.modifiers(from: flags))
            guard combo.isValid else { return nil }
            if let owner = hotkeys.reserved.first(where: { $0.combo == combo && $0.name != "mini player hotkey" }) {
                error = "That is the \(owner.name)."
            } else {
                let name = HotkeyCenter.name(for: combo.keyCode, characters: event.charactersIgnoringModifiers)
                if !hotkeys.changeMiniPlayer(to: combo, keyName: name) { error = HotkeyRecorder.conflict }
            }
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { hotkeys.resumeMiniPlayer() }
        recording = false
    }
}
