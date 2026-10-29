import ReachKit
import ServiceManagement
import SwiftUI

/// The Settings window (Command-Comma): a sidebar with the pages, and the
/// features grouped under their own heading with a one-line summary each
/// (S-037). Each page is a grouped Form; the window has a fixed size, and a
/// page scrolls only when it is taller than the window.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            SettingsSidebar()
                // The Settings scene ignores the column width alone; the frame holds it.
                .frame(minWidth: 240)
                .navigationSplitViewColumnWidth(240)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            page(model.settingsTab)
                .navigationTitle(model.settingsTab.title)
        }
        .frame(minWidth: 860, idealWidth: 900, minHeight: 600, idealHeight: 640)
        .noInitialFocus()
        .focusedSceneValue(\.settingsInFront, true)
    }

    @ViewBuilder
    private func page(_ tab: SettingsTab) -> some View {
        Form {
            switch tab {
            case .general: GeneralSettings()
            case .search: SearchSettingsView()
            case .web: WebSearchSettingsView()
            case .system: SystemSettingsView()
            case .terminal: TerminalSettingsView()
            case .dictionary: DictionarySettingsView()
            case .contacts: ContactsSettingsView()
            case .clipboard: ClipboardSettingsView()
            case .snippets: SnippetSettingsView()
            case .actions: ActionsSettings()
            case .previews: PreviewsSettings()
            case .appearance: AppearanceSettings()
            }
        }
        .formStyle(.grouped)
        // One page per tab: a page's scroll position never carries over to the next.
        .id(tab)
    }
}

/// The pages, then the features with an icon, a title and a summary. With
/// text in Search Settings, the settings that match instead (S-036).
private struct SettingsSidebar: View {
    @Environment(AppModel.self) private var model
    @FocusState private var searching: Bool

    var body: some View {
        @Bindable var model = model
        Group {
            if model.settingsQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                pages
            } else {
                SettingsResults(results: SettingsTab.search(model.settingsQuery))
            }
        }
        .searchable(text: $model.settingsQuery, placement: .sidebar, prompt: "Search Settings")
        .searchFocused($searching)
        .onSubmit(of: .search) {
            if let first = SettingsTab.search(model.settingsQuery).first { model.settingsTab = first.tab }
        }
        .onChange(of: model.settingsSearchRequests) { searching = true }
    }

    private var pages: some View {
        List(selection: Binding<SettingsTab?>(get: { model.settingsTab }, set: { if let tab = $0 { model.settingsTab = tab } })) {
            Section {
                ForEach(SettingsTab.pages) { tab in
                    Label(tab.title, systemImage: tab.symbol).tag(tab)
                }
            }
            Section("Features") {
                ForEach(SettingsTab.features) { tab in
                    Label {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(tab.title)
                            Text(tab.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } icon: {
                        Image(systemName: tab.symbol)
                    }
                    .tag(tab)
                    .help(tab.summary)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

/// Edit > Search Settings (⌘F), while Settings is in front.
struct SettingsCommands: Commands {
    @FocusedValue(\.settingsInFront) private var settingsInFront

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Search Settings") { AppModel.shared.settingsSearchRequests += 1 }
                .keyboardShortcut("f")
                .disabled(settingsInFront != true)
        }
    }
}

extension FocusedValues {
    @Entry var settingsInFront: Bool?
}

/// The settings that match Search Settings: the label, and the page and
/// section it is on. Clicking one shows its page.
private struct SettingsResults: View {
    @Environment(AppModel.self) private var model
    let results: [(entry: SettingsEntry, tab: SettingsTab)]

    var body: some View {
        if results.isEmpty {
            ContentUnavailableView.search(text: model.settingsQuery)
        } else {
            List(selection: Binding<String?>(get: { nil }, set: { id in
                if let tab = results.first(where: { $0.entry.id == id })?.tab { model.settingsTab = tab }
            })) {
                ForEach(results, id: \.entry.id) { result in
                    Label {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(result.entry.title)
                            Text([result.tab.title, result.entry.section].filter { !$0.isEmpty && $0 != result.entry.title }
                                .joined(separator: " › "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } icon: {
                        Image(systemName: result.tab.symbol)
                    }
                    .tag(result.entry.id)
                }
            }
            .listStyle(.sidebar)
        }
    }
}

/// The Settings pages. Snapshot mode walks through every case.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, search, web, system, terminal, dictionary, contacts, clipboard, snippets, actions, previews, appearance

    var id: String { rawValue }

    /// Search Settings: every label in Settings, and the pages by name.
    static func search(_ query: String) -> [(entry: SettingsEntry, tab: SettingsTab)] {
        let titles = Dictionary(uniqueKeysWithValues: allCases.map { ($0.rawValue, $0.title) })
        let pages = allCases.map { SettingsEntry($0.title, page: $0.rawValue, words: $0.summary) }
        return SettingsIndex.search(query, in: pages + SettingsIndex.entries, pageTitles: titles)
            .compactMap { entry in SettingsTab(rawValue: entry.page).map { (entry, $0) } }
    }

    /// Pages at the top of the sidebar.
    static let pages: [SettingsTab] = [.general, .appearance]
    /// Pages under Features, in the order the launcher meets them.
    static let features: [SettingsTab] = allCases.filter { !pages.contains($0) }

    var title: String {
        switch self {
        case .general: "General"
        case .search: "Search"
        case .web: "Web Search"
        case .system: "System"
        case .terminal: "Terminal"
        case .dictionary: "Dictionary"
        case .contacts: "Contacts"
        case .clipboard: "Clipboard"
        case .snippets: "Snippets"
        case .actions: "Actions"
        case .previews: "Previews"
        case .appearance: "Appearance"
        }
    }

    /// The line under a feature's title in the sidebar.
    var summary: String {
        switch self {
        case .general: "Hotkey and permissions"
        case .search: "Apps, files and fallbacks"
        case .web: "Web searches and typed URLs"
        case .system: "Sleep, lock, quit apps"
        case .terminal: "Run a command with >"
        case .dictionary: "Define and spell words"
        case .contacts: "Find and email people"
        case .clipboard: "History and merging"
        case .snippets: "Collections and expansion"
        case .actions: "The action panel"
        case .previews: "Quick Look in the launcher"
        case .appearance: "Themes and launcher options"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .search: "magnifyingglass"
        case .web: "globe"
        case .system: "power"
        case .terminal: "apple.terminal"
        case .dictionary: "character.book.closed"
        case .contacts: "person.crop.circle"
        case .clipboard: "doc.on.clipboard"
        case .snippets: "text.quote"
        case .actions: "arrow.right.square"
        case .previews: "eye"
        case .appearance: "paintpalette"
        }
    }
}

struct GeneralSettings: View {
    var body: some View {
        Section("Launcher") {
            HotkeyRecorder()
            LoginItemToggle()
        }
        Section("Permissions") {
            LabeledContent {
                Button("Grant Permissions…") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            } label: {
                Text("Accessibility")
                Text("Needed for pasting, the selection hotkey, ⌘C twice and expanding snippets.")
            }
        }
    }
}

/// Settings > Actions: which actions the action panel shows (S-010).
struct ActionsSettings: View {
    @Bindable private var settings = ActionSettings.shared

    var body: some View {
        Section {
            ForEach(FileAction.allCases, id: \.self) { action in
                Toggle(isOn: Binding(get: { settings.isOn(action) }, set: { settings.set(action, on: $0) })) {
                    Label {
                        Text(action.title)
                    } icon: {
                        // One width for every symbol, so the names line up.
                        Image(systemName: action.symbol)
                            .frame(width: Space.xl)
                    }
                }
                .toggleStyle(.checkbox)
            }
        } header: {
            Text("Action Panel")
        } footer: {
            Text("Actions you turn off no longer show in the action panel. Open With… shows only for files and apps, Quick Look only for files that Previews does not skip.")
                .foregroundStyle(.secondary)
        }
        Section("Selection") {
            LabeledContent {
                Text(HotkeyCenter.shared.selectionRegistered || AppModel.isTestRun
                     ? KeyCombo.selection.display(key: "\\") : "In use by another app")
                    .foregroundStyle(.secondary)
            } label: {
                Text("Act on the selection")
                Text("Select files in Finder or text in any app, then press this to see its actions.")
            }
        }
    }
}

/// Open at login, through a login item the user can also see in System Settings.
struct LoginItemToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        Toggle(isOn: Binding(get: { enabled }, set: change)) {
            Text("Open at login")
            if let error { Text(error).foregroundStyle(.red) }
        }
    }

    private func change(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = "Could not change the login item: \(error.localizedDescription)"
        }
        enabled = SMAppService.mainApp.status == .enabled
    }
}
