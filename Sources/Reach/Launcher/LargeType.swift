import AppKit
import SwiftUI

/// Text in huge letters on a dark card over the screen with the mouse.
/// Esc, a click, or another app closes it. ⌘L shows it from the launcher (S-023).
/// The card fits the text: short text gets big letters on a small card, long
/// text shrinks first and wraps only below `wrapSize`.
@Observable
final class LargeType {
    static let shared = LargeType()
    /// The biggest letters, for a word or two.
    static let maxSize: CGFloat = 200
    /// Below this, long text wraps instead of shrinking further.
    static let wrapSize: CGFloat = 64
    private(set) var text = ""
    private(set) var fontSize = maxSize
    private(set) var padding: CGFloat = Space.section
    private var panel: NSPanel?
    private var keyMonitor: Any?

    var isVisible: Bool { panel?.isVisible == true }
    /// The card's window, for snapshots and the self-test.
    var window: NSWindow? { panel }

    func show(_ text: String) {
        self.text = text
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let card = layout(text, in: NSSize(width: area.width * 0.9, height: area.height * 0.8))
        let panel = self.panel ?? makePanel()
        panel.setFrame(NSRect(x: (area.midX - card.width / 2).rounded(), y: (area.midY - card.height / 2).rounded(),
                              width: card.width, height: card.height), display: true)
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

    /// Picks the letter size and returns the card size for `text`, at most `limit`.
    private func layout(_ text: String, in limit: NSSize) -> NSSize {
        func measure(_ size: CGFloat, width: CGFloat) -> NSSize {
            let font = NSFont.systemFont(ofSize: size, weight: .medium)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            return NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph])
                .boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude),
                              options: [.usesLineFragmentOrigin, .usesFontLeading]).size
        }
        func pad(_ size: CGFloat) -> CGFloat { max(Space.section, (size * 0.3).rounded()) }
        // One line at the biggest size; shrink until it fits the width, down to wrapSize.
        var size = Self.maxSize
        let wide = measure(size, width: .greatestFiniteMagnitude).width
        let room = limit.width - 2 * pad(size)
        if wide > room { size = max(Self.wrapSize, (size * room / wide).rounded(.down)) }
        // Wrapped at that size; shrink further only when the lines run out of height.
        var text = measure(size, width: limit.width - 2 * pad(size))
        while text.height > limit.height - 2 * pad(size), size > 12 {
            size = (size * 0.85).rounded(.down)
            text = measure(size, width: limit.width - 2 * pad(size))
        }
        fontSize = size
        padding = pad(size)
        return NSSize(width: min(limit.width, (text.width + 2 * padding).rounded(.up)),
                      height: min(limit.height, (text.height + 2 * padding).rounded(.up)))
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
            .font(.system(size: model.fontSize, weight: .medium))
            // A safety net only: `layout` already picked a size that fits.
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .padding(model.padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: Radius.panel * 2, style: .continuous))
            // Always a dark card with light text, as Large Type is in every Mac launcher.
            .environment(\.colorScheme, .dark)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Large Type, \(model.text)")
    }
}
