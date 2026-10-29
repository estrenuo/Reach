import Testing
@testable import ReachKit

@Test func theSettingsKeywordMatchesItsWordsFromThreeLetters() {
    for text in ["settings", "sett", "Set", "pref", "preferences", "reach", "reach sett", " settings "] {
        #expect(SettingsKeyword.matches(text), "\(text)")
    }
    for text in ["se", "", "system settings", "setting x", "sets"] {
        #expect(!SettingsKeyword.matches(text), "\(text)")
    }
}
