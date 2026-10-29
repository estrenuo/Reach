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
