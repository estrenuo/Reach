import AppKit
import ReachKit

/// The calculator in the bar (S-015): one row with the answer for a query
/// like `2*21` or `=sqrt(16)`, shown above apps and files. Return copies it.
final class CalculatorSource: ResultSource {
    static let id = "calculator"
    static let hint = "Type a calculation"
    static let help = "↩ copies the answer, ⌘↩ pastes it"
    /// Calculator's own icon, as in Alfred.
    static let icon = LaunchResult.Icon.file("/System/Applications/Calculator.app")

    /// The decimal separator and grouping come from here. The self-test sets a fixed one.
    var locale: Locale = .autoupdatingCurrent

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        if text == "=" {
            return [Scored(result: LaunchResult(id: "hint:calculator", title: Self.hint, subtitle: "",
                                                icon: Self.icon, url: nil), score: 0)]
        }
        guard let answer = Calculator.answer(for: text, locale: locale) else { return [] }
        return [Scored(result: LaunchResult(id: Self.id, title: answer.shown, subtitle: Self.help, icon: Self.icon,
                                            url: nil, kindLabel: "Calculation", answer: answer.copied, isPinned: true), score: 0)]
    }
}

/// Copies text, and pastes it into the front app with a ⌘V keystroke.
/// Posting keys needs the Accessibility permission the selection hotkey uses;
/// without it the answer is still on the clipboard.
enum Paster {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Waits for the launcher to hide, so the keystroke reaches the app behind it.
    static func pressPaste() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            let source = CGEventSource(stateID: .combinedSessionState)
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: down)  // V
                event?.flags = .maskCommand
                event?.post(tap: .cghidEventTap)
            }
        }
    }
}
