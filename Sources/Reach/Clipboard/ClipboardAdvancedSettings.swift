import AppKit
import ReachKit
import SwiftUI

/// Settings > Clipboard > Advanced (S-027): pasting, the longest text kept,
/// and the apps whose copies are never kept.
struct ClipboardAdvancedSettings: View {
    @Bindable var settings: ClipboardSettings

    var body: some View {
        Section {
            Toggle(isOn: $settings.pastesOnReturn) {
                Text("Paste on Return")
                Text("Return in the clipboard viewer also pastes the clip into the app in front. Off: Return only copies it.")
            }
            Picker(selection: $settings.maxSize) {
                ForEach(ClipboardPolicy.MaxSize.ordered, id: \.self) { Text($0.title).tag($0) }
            } label: {
                Text("Max Clip Size")
                Text("Copied text over this size is not kept, so one huge copy does not fill the history.")
            }
        }
        EditableList(title: "Ignore Apps", empty: "No apps",
                     footer: "Copies made in these apps are never kept. Drop an app here or click + to choose one.",
                     addHelp: "Add an app whose copies are never kept", removeHelp: "Keep copies from the selected app again",
                     items: $settings.ignoredAppList, label: Self.label, add: Self.chooseApp, dropped: Self.bundleID(of:),
                     resetHelp: "Ignore only the password managers and Keychain Access again", reset: settings.resetIgnoredApps)
    }

    /// The app's name and its bundle id. An app that is not installed shows
    /// its known name, or its bundle id, and "Not installed".
    static func label(_ bundleID: String) -> (String, String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return (ClipboardPolicy.standardAppNames[bundleID] ?? bundleID, "Not installed")
        }
        return (FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""), bundleID)
    }

    static func bundleID(of url: URL) -> String? {
        guard url.pathExtension == "app" else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    private static func chooseApp() -> String? {
        let open = NSOpenPanel()
        open.directoryURL = URL(fileURLWithPath: "/Applications")
        open.allowedContentTypes = [.application]
        open.message = "Choose an app whose copies Reach never keeps."
        open.prompt = "Ignore App"
        return open.runModal() == .OK ? open.url.flatMap(bundleID(of:)) : nil
    }
}
