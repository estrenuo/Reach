import CoreGraphics
import Testing
@testable import ReachKit

private let left = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let right = CGRect(x: 1440, y: 0, width: 2560, height: 1440)

@Test func visibleResultsStayBetweenThreeAndNine() {
    #expect(LauncherOptions.clampedVisible(1) == 3)
    #expect(LauncherOptions.clampedVisible(6) == 6)
    #expect(LauncherOptions.clampedVisible(20) == 9)
}

@Test func theBarShowsOnTheChosenScreen() {
    let screens = [left, right]
    let mouse = CGPoint(x: 2000, y: 500)
    let window = CGRect(x: 100, y: 100, width: 800, height: 600)
    #expect(LauncherOptions.screen(.mouse, screens: screens, mouse: mouse, activeWindow: window) == 1)
    #expect(LauncherOptions.screen(.main, screens: screens, mouse: mouse, activeWindow: window) == 0)
    #expect(LauncherOptions.screen(.activeWindow, screens: screens, mouse: mouse, activeWindow: window) == 0)
}

@Test func aWindowAcrossTwoScreensBelongsToTheBiggerPart() {
    let across = CGRect(x: 1240, y: 100, width: 800, height: 600)
    #expect(LauncherOptions.screen(.activeWindow, screens: [left, right], mouse: .zero, activeWindow: across) == 1)
}

@Test func withoutAWindowTheMouseScreenWins() {
    let mouse = CGPoint(x: 2000, y: 500)
    #expect(LauncherOptions.screen(.activeWindow, screens: [left, right], mouse: mouse, activeWindow: nil) == 1)
    #expect(LauncherOptions.screen(.mouse, screens: [left, right], mouse: CGPoint(x: -50, y: 0), activeWindow: nil) == 0)
    #expect(LauncherOptions.screen(.mouse, screens: [], mouse: mouse, activeWindow: nil) == nil)
}
