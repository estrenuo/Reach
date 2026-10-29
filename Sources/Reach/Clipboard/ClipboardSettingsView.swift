import AppKit
import ReachKit
import SwiftUI

/// Settings > Clipboard (S-025): one card per kind, each with Keep and how
/// long, and whether macOS lets Reach read what is copied.
struct ClipboardSettingsView: View {
    @Bindable private var settings = ClipboardSettings.shared
    @State private var access = ClipboardHistory.access

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: Space.md) {
                ForEach(ClipboardPolicy.Kind.allCases, id: \.self) { kind in
                    KindCard(kind: kind, settings: settings)
                }
            }
        } header: {
            Text("History")
        } footer: {
            Text("Reach keeps what you copy for the time you choose, then forgets it. Copies from password managers and Keychain Access, and copies that apps mark as private, are never kept.")
                .foregroundStyle(.secondary)
        }
        Section("Viewer") {
            LabeledContent {
                Text(HotkeyCenter.shared.clipboardRegistered || AppModel.isTestRun
                     ? KeyCombo.clipboard.display(key: "C") : "In use by another app")
                    .foregroundStyle(.secondary)
            } label: {
                Text("Show the clipboard viewer")
                Text("Or type “clipboard” in the launcher.")
            }
            Toggle(isOn: $settings.pastesOnReturn) {
                Text("Paste on Return")
                Text("Return also pastes the clip into the app in front. Off: Return only copies it.")
            }
        }
        Section {
            LabeledContent {
                if access != .alwaysAllow {
                    Button("Open System Settings…") {
                        if let url = ClipboardHistory.privacySettings { NSWorkspace.shared.open(url) }
                    }
                }
            } label: {
                Text("Access")
                Text(accessText)
            }
        } footer: {
            Text("macOS asks before an app reads what you copied in another app.")
                .foregroundStyle(.secondary)
        }
        .onAppear { access = ClipboardHistory.access }
    }

    private var accessText: String {
        switch access {
        case .alwaysAllow: "Reach can read what you copy."
        case .alwaysDeny: "Reach may not read what you copy. Allow it in System Settings > Privacy & Security > Paste from Other Apps."
        default: "macOS may ask each time. Choose Always Allow for Reach in System Settings > Privacy & Security > Paste from Other Apps."
        }
    }
}

/// One kind: Keep <kind>, and the retention menu below it.
private struct KindCard: View {
    let kind: ClipboardPolicy.Kind
    @Bindable var settings: ClipboardSettings

    private var isOn: Binding<Bool> {
        Binding(get: { settings.keep[kind] ?? false }, set: { settings.keep[kind] = $0 })
    }

    private var retention: Binding<ClipboardPolicy.Retention> {
        Binding(get: { settings.retention(kind) }, set: { settings.retention[kind] = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Toggle("Keep \(kind.title)", isOn: isOn)
                .toggleStyle(.checkbox)
            Picker("Keep for", selection: retention) {
                ForEach(ClipboardPolicy.Retention.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .disabled(!isOn.wrappedValue)
            .accessibilityLabel("Keep \(kind.title) for")
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }
}
