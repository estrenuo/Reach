import Foundation

/// The calculator in the bar (S-015). A plain query like `2*21` is a standard
/// calculation: numbers, + − × ÷ ^ %, and brackets. A query that starts with
/// `=` is advanced and adds functions (`sqrt`, `sin`) and the constants `pi`
/// and `e`. Anything that does not parse is not a calculation, so apps and
/// fallbacks show as usual while people type.
public enum Calculator {
    public struct Answer: Equatable, Sendable {
        public var value: Double
        /// With grouping, as the result row shows it: "1.234.567,5".
        public var shown: String
        /// Without grouping, as ↩ copies it: "1234567,5".
        public var copied: String
    }

    /// The functions `=` adds, as in Alfred. Trigonometry works in radians.
    public static let functions: [String: @Sendable (Double) -> Double] = [
        "sin": sin, "cos": cos, "tan": tan, "asin": asin, "acos": acos, "atan": atan,
        "sinh": sinh, "cosh": cosh, "tanh": tanh, "asinh": asinh, "acosh": acosh, "atanh": atanh,
        "log": log10, "log2": log2, "ln": log, "exp": exp, "abs": abs, "sqrt": sqrt,
        "ceil": ceil, "floor": floor, "round": { $0.rounded() }, "trunc": trunc,
        "rint": { $0.rounded(.toNearestOrEven) },
        "dtor": { $0 * .pi / 180 }, "rtod": { $0 * 180 / .pi },
    ]
    static let constants: [String: Double] = ["pi": .pi, "e": M_E]

    /// True for a query the calculator reads in advanced mode, even before it parses.
    public static func isAdvanced(_ query: String) -> Bool { query.hasPrefix("=") }

    /// The answer to `query`, or nil when it is not a calculation. A standard
    /// query needs at least one operator, so "2048" stays a search.
    public static func answer(for query: String, locale: Locale = .current) -> Answer? {
        let advanced = isAdvanced(query)
        let text = advanced ? String(query.dropFirst()) : query
        guard let tokens = Tokenizer(decimal: decimalSeparator(locale), advanced: advanced).tokens(text),
              !tokens.isEmpty else { return nil }
        var parser = Parser(tokens: tokens)
        guard let value = parser.parse(), value.isFinite, advanced || parser.operations > 0 else { return nil }
        return Answer(value: value, shown: format(value, locale: locale, grouping: true),
                      copied: format(value, locale: locale, grouping: false))
    }

    static func decimalSeparator(_ locale: Locale) -> Character {
        locale.decimalSeparator?.first ?? "."
    }

    /// Up to 10 decimals, so 0.1+0.2 shows 0.3. Huge and tiny numbers in E notation.
    static func format(_ value: Double, locale: Locale, grouping: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        let size = abs(value)
        if size >= 1e15 || (size > 0 && size < 1e-9) {
            formatter.numberStyle = .scientific
            formatter.maximumFractionDigits = 10
        } else {
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 10
            formatter.usesGroupingSeparator = grouping
        }
        // -0 reads oddly after a subtraction like 2-2.
        return formatter.string(from: NSNumber(value: value == 0 ? 0 : value)) ?? String(value)
    }
}

enum Token: Equatable {
    case number(Double)
    case name(String)
    case op(Character)
    case open, close
}

/// Splits a query into tokens. The locale's decimal separator counts, and a
/// point always does too. In a locale with a decimal point, a comma groups
/// thousands and is skipped: "1,000*2" is 2000.
struct Tokenizer {
    let decimal: Character
    let advanced: Bool

    func tokens(_ text: String) -> [Token]? {
        var tokens: [Token] = []
        var chars = Array(text)[...]
        while let char = chars.first {
            if char.isWhitespace {
                chars.removeFirst()
            } else if char.isNumber || char == "." || char == decimal {
                var digits = ""
                while let next = chars.first, next.isNumber || next == "." || next == "," {
                    if next == "." || next == decimal {
                        guard !digits.contains(".") else { return nil }
                        digits.append(".")
                    } else {
                        guard next.isASCII else { return nil }
                        if next.isNumber { digits.append(next) }
                    }
                    chars.removeFirst()
                }
                guard digits != ".", let value = Double(digits) else { return nil }
                tokens.append(.number(value))
            } else if char.isLetter, advanced {
                var name = ""
                while let next = chars.first, next.isLetter || next.isNumber {
                    name.append(next)
                    chars.removeFirst()
                }
                tokens.append(.name(name.lowercased()))
            } else if let op = Self.operators[char] {
                tokens.append(.op(op))
                chars.removeFirst()
            } else if char == "(" {
                tokens.append(.open)
                chars.removeFirst()
            } else if char == ")" {
                tokens.append(.close)
                chars.removeFirst()
            } else {
                return nil
            }
        }
        return tokens
    }

    /// Typed signs and the ones they stand for.
    static let operators: [Character: Character] = [
        "+": "+", "-": "-", "−": "-", "*": "*", "×": "*", "/": "/", "÷": "/", "^": "^", "%": "%",
    ]
}

/// Recursive descent, lowest precedence first:
///   sum      = product (("+" | "-") product)*
///   product  = unary (("*" | "/" | "%") unary)*
///   unary    = "-" unary | "+" unary | power
///   power    = postfix ("^" unary)?           right to left, so 2^3^2 = 512
///   postfix  = atom "%"*                       50% is 0.5
///   atom     = number | constant | function "(" sum ")" | "(" sum ")"
/// So -2^2 is -4, as in maths. `%` after a value is a percentage unless a
/// value follows it; then it is the remainder: 10%3 is 1.
struct Parser {
    let tokens: [Token]
    var index = 0
    /// Operators applied; a standard calculation needs one.
    private(set) var operations = 0

    init(tokens: [Token]) { self.tokens = tokens }

    mutating func parse() -> Double? {
        guard let value = sum(), index == tokens.count else { return nil }
        return value
    }

    private var current: Token? { index < tokens.count ? tokens[index] : nil }
    private var next: Token? { index + 1 < tokens.count ? tokens[index + 1] : nil }

    private mutating func sum() -> Double? {
        guard var value = product() else { return nil }
        while case .op(let op)? = current, op == "+" || op == "-" {
            index += 1
            guard let right = product() else { return nil }
            value = op == "+" ? value + right : value - right
            operations += 1
        }
        return value
    }

    private mutating func product() -> Double? {
        guard var value = unary() else { return nil }
        while case .op(let op)? = current, op == "*" || op == "/" || (op == "%" && startsValue(next)) {
            index += 1
            guard let right = unary() else { return nil }
            switch op {
            case "*": value *= right
            case "/": value /= right
            default: value = value.truncatingRemainder(dividingBy: right)
            }
            operations += 1
        }
        return value
    }

    private mutating func unary() -> Double? {
        if case .op(let op)? = current, op == "-" || op == "+" {
            index += 1
            guard let value = unary() else { return nil }
            return op == "-" ? -value : value
        }
        return power()
    }

    private mutating func power() -> Double? {
        guard let base = postfix() else { return nil }
        guard case .op("^")? = current else { return base }
        index += 1
        guard let exponent = unary() else { return nil }
        operations += 1
        return pow(base, exponent)
    }

    private mutating func postfix() -> Double? {
        guard var value = atom() else { return nil }
        while case .op("%")? = current, !startsValue(next) {
            index += 1
            value /= 100
            operations += 1
        }
        return value
    }

    private mutating func atom() -> Double? {
        switch current {
        case .number(let value)?:
            index += 1
            return value
        case .open?:
            index += 1
            guard let value = sum(), current == .close else { return nil }
            index += 1
            return value
        case .name(let name)?:
            index += 1
            if let constant = Calculator.constants[name] { return constant }
            guard let function = Calculator.functions[name], current == .open else { return nil }
            index += 1
            guard let argument = sum(), current == .close else { return nil }
            index += 1
            return function(argument)
        default:
            return nil
        }
    }

    /// True when `token` begins a value, so a `%` before it is the remainder.
    private func startsValue(_ token: Token?) -> Bool {
        switch token {
        case .number?, .name?, .open?: true
        default: false
        }
    }
}
