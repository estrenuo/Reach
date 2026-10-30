import SwiftUI

/// Window > Snippets (⌥⌘S): the Reach window with the snippets, from anywhere in Reach.
struct SnippetCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(before: .windowList) {
            Button("Snippets") {
                NSApp.activate()
                openWindow(id: "main")
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
        }
    }
}
