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
