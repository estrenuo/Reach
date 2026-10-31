import AppKit
import SwiftUI

/// A workflow's Text View (S-055): the text in a plain window named after the
/// workflow, selectable so ⌘C copies it. Esc or ⌘W closes it.
@Observable
final class TextViewWindow {
    static let shared = TextViewWindow()
    private(set) var text = ""
    private var window: NSWindow?

    var isVisible: Bool { window?.isVisible == true }
    /// The window, for snapshots.
    var shown: NSWindow? { window }

    func show(title: String, text: String) {
        self.text = text
        let window = self.window ?? makeWindow()
        window.title = title
        if !window.isVisible { window.center() }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func hide() { window?.orderOut(nil) }

    private func makeWindow() -> NSWindow {
        let window = TextViewNSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                                      styleMask: [.titled, .closable, .resizable, .miniaturizable],
                                      backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: TextViewContent(model: self))
        self.window = window
        return window
    }
}

private final class TextViewNSWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

private struct TextViewContent: View {
    let model: TextViewWindow

    var body: some View {
        ScrollView {
            Text(model.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gridProbe("text", area: "textview")
                .padding(Space.margin)
                .gridArea("textview")
        }
        .frame(minWidth: 320, minHeight: 200)
        .noInitialFocus()
    }
}
