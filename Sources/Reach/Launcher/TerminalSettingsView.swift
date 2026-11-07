import ReachKit
import SwiftUI

/// Settings > Terminal (S-021): the prefix that starts a shell command and
/// the app it runs in, as on Alfred's Terminal page.
struct TerminalSettingsView: View {
    @Bindable private var settings = TerminalSettings.shared

    var body: some View {
        Section {
            Picker("Prefix", selection: $settings.prefix) {
                ForEach(ShellCommand.prefixes, id: \.self) { Text($0).tag($0) }
            }
            Picker("Application", selection: $settings.app) {
                ForEach(settings.offered, id: \.self) { Text($0.title).tag($0) }
            }
        } header: {
            Text("Shell Commands")
        } footer: {
            Text("Type the prefix and a command: “\(settings.prefix) ls -la”. Return opens a new \(settings.app.title) window and runs it.\(missing)")
                .foregroundStyle(.secondary)
        }
    }

    /// Names the apps the menu leaves out, so people know where they went.
    private var missing: String {
        let names = TerminalApp.allCases.filter { !settings.offered.contains($0) }.map(\.title)
        guard !names.isEmpty else { return "" }
        return " \(names.joined(separator: " and ")) \(names.count == 1 ? "shows" : "show") up here once installed."
    }
}
