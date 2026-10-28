import AppKit
import SwiftUI

/// Text in huge letters on a dark card over the screen with the mouse.
/// Esc, a click, or another app closes it. S-023 adds ⌘L in the launcher.
@Observable
final class LargeType {
    static let shared = LargeType()
    private(set) var text = ""
    private var panel: NSPanel?
    private var keyMonitor: Any?

    var isVisible: Bool { panel?.isVisible == true }

    func show(_ text: String) {
        self.text = text
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let size = NSSize(width: area.width * 0.9, height: area.height * 0.6)
        let panel = self.panel ?? makePanel()
        panel.setFrame(NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2,
                              width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        keyMonitor = keyMonitor ?? NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            if event.type == .leftMouseDown || event.keyCode == 53 { self.hide(); return nil }
            return event
        }
    }

    func hide() {
        panel?.orderOut(nil)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func makePanel() -> NSPanel {
        let panel = LargeTypePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.onResign = { [weak self] in self?.hide() }
        let host = NSHostingView(rootView: LargeTypeView(model: self))
        host.sizingOptions = []
        panel.contentView = host
        self.panel = panel
        return panel
    }
}

private final class LargeTypePanel: NSPanel {
    var onResign: () -> Void = {}
    override var canBecomeKey: Bool { true }
    override func resignKey() {
        super.resignKey()
        onResign()
    }
}

private struct LargeTypeView: View {
    let model: LargeType

    var body: some View {
        Text(model.text)
            .font(.system(size: 200, weight: .medium))
            .minimumScaleFactor(0.05)
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .padding(Space.section)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
            // Always a dark card with light text, as Large Type is in every Mac launcher.
            .environment(\.colorScheme, .dark)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Large Type, \(model.text)")
    }
}
