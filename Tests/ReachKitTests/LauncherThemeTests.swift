import Foundation
import Testing
@testable import ReachKit

@Test func themesHaveOneIDEach() {
    #expect(Set(LauncherTheme.all.map(\.id)).count == LauncherTheme.all.count)
    #expect(LauncherTheme.all.count == 6)
}

@Test func aMissingThemeFallsBackToReach() {
    #expect(LauncherTheme.named("solid-dark").surface == .solid)
    #expect(LauncherTheme.named("gone") == .standard)
    #expect(LauncherTheme.named(nil).id == "reach")
}

@Test func summariesSayTheLookAndTheMode() {
    #expect(LauncherTheme.named("reach").summary == "Glass, follows the Mac")
    #expect(LauncherTheme.named("solid-light").summary == "Solid, light")
}

@Test func aDuplicateIsOwnAndNamedAfterItsSource() {
    let dark = LauncherTheme.named("reach-dark")
    let copy = dark.duplicate(id: "x", taken: ["Reach Dark"])
    #expect(copy.name == "Reach Dark Copy" && !copy.isBuiltIn && copy.mode == .dark && copy.id == "x")
    #expect(dark.duplicate(id: "y", taken: ["Reach Dark Copy", "Reach Dark Copy 2"]).name == "Reach Dark Copy 3")
    #expect(LauncherTheme.named("x", in: [copy]) == copy)
}

@Test func savedThemesComeBackInRange() throws {
    let json = #"{"id":"a","name":"Mine","surface":"solid","querySize":99,"cornerRadius":-4}"#
    let theme = try JSONDecoder().decode(LauncherTheme.self, from: Data(json.utf8))
    #expect(theme.querySize == 40 && theme.cornerRadius == 0 && theme.rowSize == 15)
    #expect(theme.mode == .system && theme.surface == .solid && !theme.isBuiltIn)
    var mine = theme
    mine.selectionColor = ThemeColor(red: 1, green: 0.8, blue: 0)
    let again = try JSONDecoder().decode(LauncherTheme.self, from: JSONEncoder().encode(mine))
    #expect(again == mine)
}

@Test func selectionTextIsReadable() {
    #expect(ThemeColor(red: 1, green: 0.85, blue: 0.2).wantsDarkText)
    #expect(!ThemeColor(red: 0.35, green: 0.1, blue: 0.5).wantsDarkText)
}
