import AppKit
import ReachKit

extension SelfTest {
    /// S-022: `define` shows words with their first sense and opens
    /// Dictionary.app; `spell` suggests spellings that Return copies. The
    /// dictionary and the spell checker are fakes, so every Mac sees the same.
    static func checkDictionary(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let source = lm.dictionary
        let settings = DictionarySettings.shared
        var opened: [URL] = []
        var copied: [String] = []
        var pasted = 0
        var languages: [String?] = []
        let (opener, copier, paster) = (lm.opener, lm.copier, lm.paster)
        let (define, completions, guesses) = (source.define, source.completions, source.guesses)
        lm.opener = { opened.append($0); return true }
        lm.copier = { copied.append($0) }
        lm.paster = { pasted += 1 }
        source.define = { ["serendipity": "serendipity | ˌserənˈdɪpɪti | noun luck in finding good things ▸ pure serendipity",
                           "serendipitous": "serendipitous | adjective found by luck"][$0] }
        source.completions = { word, language in languages.append(language); return word.hasPrefix("serendip") ? ["serendipitous", "serendipx"] : [] }
        source.guesses = { word, _ in word == "recieve" ? ["receive", "relieve"] : [word] }
        defer {
            settings.reset()
            (lm.opener, lm.copier, lm.paster) = (opener, copier, paster)
            (source.define, source.completions, source.guesses) = (define, completions, guesses)
        }

        launcher.show()
        lm.query = "define serendipity"
        check("define shows the word with its first sense as the subtitle",
              lm.results.first?.title == "serendipity" && lm.results.first?.subtitle == "noun luck in finding good things",
              lm.results.map(\.title).joined(separator: ", "))
        check("define offers related words that have a definition, and leaves out the rest",
              lm.results.map(\.title).prefix(2) == ["serendipity", "serendipitous"] && !lm.results.contains { $0.title == "serendipx" })
        lm.openSelected()
        check("↩ opens Dictionary.app at the word", opened.last?.absoluteString == "dict://serendipity" && !launcher.isVisible)

        await showAgain(launcher)
        lm.query = "define xqz"
        check("a word without a definition says so", lm.results.first?.title == "No definition for “xqz”"
              && lm.results.first?.isOpenable == false)
        lm.query = "define "
        check("the keyword alone asks for a word", lm.results.first?.title == "Type a word to define")
        lm.query = "defi"
        let offer = lm.results.firstIndex { $0.id == "dictionary:define" }
        check("part of the keyword offers “Define a Word…”", offer != nil)
        if let offer { lm.open(at: offer) }
        check("↩ completes it to “define ”", lm.query == "define ")

        lm.query = "spell recieve"
        check("spell suggests spellings", lm.results.prefix(2).map(\.title) == ["receive", "relieve"],
              lm.results.map(\.title).joined(separator: ", "))
        lm.openSelected()
        check("↩ copies the spelling", copied.last == "receive" && pasted == 0 && !launcher.isVisible)
        await showAgain(launcher)
        lm.query = "spell recieve"
        _ = lm.pasteSelected()
        check("⌘↩ copies and pastes the spelling", copied.last == "receive" && pasted == 1)

        await showAgain(launcher)
        settings.language = "en_GB"
        lm.query = "spell serendip"
        check("spell asks in the chosen language", languages.last == "en_GB"
              && Store.settings.string(forKey: "dictionary.language") == "en_GB")

        settings.keywords[.define] = "def"
        lm.query = "def serendipity"
        check("a changed keyword looks the word up", lm.results.first?.title == "serendipity")
        settings.isOn[.define] = false
        lm.query = "def serendipitous"
        check("a lookup that is off is not offered", !lm.results.contains { $0.id.hasPrefix("define:") })
        launcher.hide()
    }
}
