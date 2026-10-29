import AppKit
import ReachKit

extension SelfTest {
    /// S-015: the answer row, ↩ copies, ⌘↩ pastes, and searches still work.
    static func checkCalculator(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        lm.calculator.locale = Locale(identifier: "nl_NL")
        defer { lm.calculator.locale = .autoupdatingCurrent }
        var copied: [String] = []
        var pasted = 0
        lm.copier = { copied.append($0) }
        lm.paster = { pasted += 1 }
        defer {
            lm.copier = { Paster.copy($0) }
            lm.paster = { Paster.pressPaste() }
        }

        launcher.show()
        lm.query = "2*21"
        check("2*21 shows the answer first, with Calculator's icon",
              lm.results.first?.title == "42" && lm.results.first?.icon == CalculatorSource.icon && lm.selection == 0,
              lm.results.map(\.title).joined(separator: ", "))
        lm.openSelected()
        check("↩ on the answer copies it and hides the launcher", copied == ["42"] && !launcher.isVisible)

        launcher.show()
        lm.query = "=2*21+sqrt(16)"
        check("= adds functions", lm.results.first?.title == "46")
        lm.query = "1234567+0,5"
        check("the row groups thousands; the copy does not",
              lm.results.first?.title == "1.234.567,5" && lm.results.first?.answer == "1234567,5")
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                     windowNumber: launcher.panel.windowNumber, context: nil,
                                     characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)
        if let event { _ = launcher.handle(event) }
        check("⌘↩ on the answer copies and pastes it", copied.last == "1234567,5" && pasted == 1 && !launcher.isVisible)

        launcher.show()
        lm.query = "="
        check("= alone asks for a calculation", lm.results.first?.title == CalculatorSource.hint)
        lm.query = "2048"
        check("a number alone is a search, not a calculation", !lm.results.contains { $0.answer != nil })
        lm.query = "2*"
        check("an unfinished sum shows no answer", !lm.results.contains { $0.answer != nil })
        launcher.hide()
    }
}
