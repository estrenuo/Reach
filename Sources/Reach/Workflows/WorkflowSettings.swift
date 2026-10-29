import AppKit
import ReachKit
import SwiftUI

/// Settings > Workflows (S-042): how many are installed, the way to the
/// Workflows window, and the folder they live in.
struct WorkflowSettings: View {
    @Environment(\.openWindow) private var openWindow
    private var library = WorkflowLibrary.shared

    var body: some View {
        Section("Workflows") {
            LabeledContent {
                Button("Open Workflows…") {
                    NSApp.activate()
                    openWindow(id: WorkflowLibrary.windowID)
                }
            } label: {
                Text("Installed")
                Text(summary)
            }
        }
        Section {
            LabeledContent {
                Button("Show in Finder") {
                    try? FileManager.default.createDirectory(at: library.folder, withIntermediateDirectories: true)
                    NSWorkspace.shared.activateFileViewerSelecting([library.folder])
                }
            } label: {
                Text("Workflows folder")
                Text(library.folder.path(percentEncoded: false).replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .truncationMode(.middle)
            }
        } footer: {
            Text("Each workflow is a folder with an info.plist in Alfred's format. With a sync folder set, workflows live there.")
                .foregroundStyle(.secondary)
        }
        .onAppear { library.reloadIfStale() }
    }

    private var summary: String {
        let count = library.workflows.count
        let off = library.workflows.filter(\.disabled).count
        guard count > 0 else { return "None yet. Install one in the Workflows window." }
        return "\(count) \(count == 1 ? "workflow" : "workflows")" + (off > 0 ? ", \(off) off" : "")
    }
}
