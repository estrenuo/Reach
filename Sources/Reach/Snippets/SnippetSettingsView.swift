import AppKit
import ApplicationServices
import SwiftUI

/// Settings > Snippets (S-031): expanding snippet keywords while typing.
struct SnippetSettingsView: View {
    @Bindable private var settings = SnippetSettings.shared
    @State private var trusted = AXIsProcessTrusted()

    var body: some View {
        Section {
            Toggle(isOn: $settings.expandsWhileTyping) {
                Text("Expand keywords while typing")
                Text("Type a snippet keyword at the start of a word in any app, and Reach replaces it with the snippet as you type its last letter.")
            }
        } header: {
            Text("Expansion")
        } footer: {
            Text("Never in password fields or in Reach. Pick keywords you do not type by accident, like “;sig”.")
                .foregroundStyle(.secondary)
        }
        Section {
            LabeledContent {
                if !trusted {
                    Button("Open System Settings…") { if let url = SelectionReader.accessibilitySettings { NSWorkspace.shared.open(url) } }
                }
            } label: {
                Text("Access")
                Text(trusted ? "Reach can see keywords as you type. It keeps only the last few characters, in memory."
                     : "Allow Reach in System Settings > Privacy & Security > Accessibility, so it can see keywords as you type.")
            }
        }
        .onAppear { trusted = AXIsProcessTrusted() }
    }
}
