import AppKit
import ApplicationServices
import ReachKit
import SwiftUI

/// Settings > Clipboard > Merging (S-028): ⌘ held, C twice appends to the
/// last clip. Off while Keep Plain Text is off, since it merges text clips.
struct ClipboardMergingSettings: View {
    @Bindable var settings: ClipboardSettings
    @State private var trusted = AXIsProcessTrusted()

    var body: some View {
        Section {
            Toggle(isOn: $settings.appendsOnDoubleCopy) {
                Text("Append with ⌘C twice")
                Text("Hold ⌘ and press C twice to add the selection to the text you copied before it.")
            }
            Group {
                Toggle(isOn: $settings.placesMergedText) {
                    Text("Put the merged text on the clipboard")
                    Text("Then ⌘V pastes it, without the clipboard viewer.")
                }
                Picker("Separator", selection: $settings.separator) {
                    ForEach(ClipboardMerge.Separator.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle(isOn: $settings.playsMergeSound) {
                    Text("Play a sound when appending")
                    Text("Plays the “\(ClipboardMerge.soundName)” sound when the text was added.")
                }
            }
            .disabled(!settings.appendsOnDoubleCopy)
        } header: {
            Text("Merging")
        } footer: {
            Text(settings.canAppend ? "Copies from ignored apps are never appended."
                 : "Turn on Keep Plain Text on the History page to append to the last clip.")
                .foregroundStyle(.secondary)
        }
        .disabled(!settings.canAppend)
        Section {
            LabeledContent {
                if !trusted {
                    Button("Open System Settings…") { if let url = SelectionReader.accessibilitySettings { NSWorkspace.shared.open(url) } }
                }
            } label: {
                Text("Access")
                Text(trusted ? "Reach can see when you press ⌘C."
                     : "Allow Reach in System Settings > Privacy & Security > Accessibility, so it can see when you press ⌘C.")
            }
        }
        .onAppear { trusted = AXIsProcessTrusted() }
    }
}
