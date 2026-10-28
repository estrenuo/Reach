import ServiceManagement
import SwiftUI

/// The Settings window (Command-Comma). One tab per topic, at most about
/// six. Each tab is a grouped Form that sizes to its content, so the
/// window grows to fit and shows no scroll bar it does not need.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.settingsTab) {
            ForEach(SettingsTab.allCases) { tab in
                page(tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
        .noInitialFocus()
    }

    @ViewBuilder
    private func page(_ tab: SettingsTab) -> some View {
        Form {
            switch tab {
            case .general: GeneralSettings()
            case .appearance: AppearanceSettings()
            }
        }
        .formStyle(.grouped)
        .fitsContent()
        .frame(width: 520)
    }
}

/// The Settings tabs. Snapshot mode walks through every case.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        }
    }
}

struct GeneralSettings: View {
    @AppStorage("confirmDelete") private var confirmDelete = true

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
                Text("Needed later for pasting and snippet expansion.")
            }
        }
        Section("Snippets") {
            Toggle("Ask before deleting snippets", isOn: $confirmDelete)
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
