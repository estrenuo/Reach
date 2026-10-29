import Foundation
import Testing
@testable import ReachKit

private let english = Locale(identifier: "en_US")
private let dutch = Locale(identifier: "nl_NL")

private func value(_ query: String, _ locale: Locale = english) -> Double? {
    Calculator.answer(for: query, locale: locale)?.value
}

@Test("Standard mode handles + − × ÷ ^ % and brackets, in maths order")
func calculatorStandard() {
    #expect(value("2*21") == 42)
    #expect(value("2+3*4") == 14)
    #expect(value("(2+3)*4") == 20)
    #expect(value("10/4") == 2.5)
    #expect(value("7−2") == 5)
    #expect(value("3×4÷2") == 6)
    #expect(value("2^10") == 1024)
    #expect(value("2^3^2") == 512)
    #expect(value("-2^2") == -4)
    #expect(value("2*-3") == -6)
    #expect(value(" 1 + 1 ") == 2)
}

@Test("% is a percentage after a value, and the remainder between two values")
func calculatorPercent() {
    #expect(value("50%") == 0.5)
    #expect(value("200*5%") == 10)
    #expect(value("10%3") == 1)
    #expect(value("10 % (2+1)") == 1)
}

@Test("A number alone, an unfinished sum or a word is not a calculation")
func calculatorNotACalculation() {
    #expect(value("2048") == nil)
    #expect(value("-5") == nil)
    #expect(value("2*") == nil)
    #expect(value("(2+3") == nil)
    #expect(value("2+3)") == nil)
    #expect(value("1password") == nil)
    #expect(value("safari") == nil)
    #expect(value("sqrt(16)") == nil)
    #expect(value("1/0") == nil)
    #expect(value("") == nil)
}

@Test("= adds functions and constants, and accepts a single number")
func calculatorAdvanced() {
    #expect(value("=2*21+sqrt(16)") == 46)
    #expect(value("=SQRT(9)") == 3)
    #expect(value("=abs(-3)+floor(2.7)+ceil(0.2)") == 6)
    #expect(value("=log(1000)") == 3)
    #expect(value("=log2(8)") == 3)
    #expect(value("=ln(e)") == 1)
    #expect(value("=round(rtod(pi))") == 180)
    #expect(value("=rint(2.5)") == 2)
    #expect(value("=sin(0)") == 0)
    #expect(value("=42") == 42)
    #expect(value("=") == nil)
    #expect(value("=sqrt 16") == nil)
    #expect(value("=nope(2)") == nil)
}

@Test("The locale's decimal separator counts, and a point always does")
func calculatorDecimals() {
    #expect(value("2,5*2", dutch) == 5)
    #expect(value("2.5*2", dutch) == 5)
    #expect(value("2.5*2", english) == 5)
    // In a locale with a decimal point, a comma groups thousands.
    #expect(value("1,000*2", english) == 2000)
    #expect(value("1.2.3+1", english) == nil)
}

@Test("The row groups thousands; the copied answer does not")
func calculatorFormat() {
    let answer = Calculator.answer(for: "1234567+0.5", locale: dutch)
    #expect(answer?.shown == "1.234.567,5")
    #expect(answer?.copied == "1234567,5")
    #expect(Calculator.answer(for: "1234567+0.5", locale: english)?.shown == "1,234,567.5")
    #expect(Calculator.answer(for: "0.1+0.2", locale: english)?.shown == "0.3")
    #expect(Calculator.answer(for: "2-2", locale: english)?.shown == "0")
    #expect(Calculator.answer(for: "10^20*1", locale: english)?.shown == "1E20")
}
